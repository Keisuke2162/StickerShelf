#if canImport(UIKit)
import SwiftUI
import UIKit
import Domain

/// 積読の落ちもの表示。参考実装（Keisuke2162/BlockNotes の GravityView）に倣い、
/// UIKit Dynamics (UIDynamicAnimator / UIGravityBehavior / UICollisionBehavior) で実装する。
/// SpriteKit の @State 問題（シーン再生成でノードが消える・座標系の混乱）を回避するため、
/// Coordinator がアニメーターと UIView を保持する。
struct PileDynamicsView: UIViewRepresentable {
    struct Item: Equatable, Sendable {
        let id: BookID
        let title: String
        let isVertical: Bool
        let imageData: Data?

        var size: CGSize {
            isVertical ? CGSize(width: 52, height: 74) : CGSize(width: 74, height: 52)
        }
    }

    let items: [Item]
    let onTap: @MainActor (BookID) -> Void
    let onLongPress: @MainActor (BookID) -> Void

    func makeUIView(context: Context) -> ContainerView {
        let view = ContainerView()
        view.backgroundColor = .clear
        context.coordinator.container = view
        context.coordinator.rebuild(with: items)
        return view
    }

    func updateUIView(_ uiView: ContainerView, context: Context) {
        context.coordinator.container = uiView
        if context.coordinator.currentItemIDs != items.map(\.id) {
            context.coordinator.rebuild(with: items)
        } else {
            // 向きや画像など軽い差分だけ反映
            context.coordinator.refreshContent(items: items)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onLongPress: onLongPress)
    }

    // MARK: - Container that resets physics boundary on layout

    final class ContainerView: UIView {
        var onLayout: (CGSize) -> Void = { _ in }
        private var lastSize: CGSize = .zero

        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.size != lastSize, bounds.size.width > 0, bounds.size.height > 0 {
                lastSize = bounds.size
                onLayout(bounds.size)
            }
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        private let onTap: @MainActor (BookID) -> Void
        private let onLongPress: @MainActor (BookID) -> Void

        weak var container: ContainerView? {
            didSet {
                container?.onLayout = { [weak self] size in
                    self?.handleLayout(size: size)
                }
            }
        }

        private var animator: UIDynamicAnimator?
        private var itemViews: [BookID: ItemView] = [:]
        private var currentCollision: UICollisionBehavior?
        private var currentGravity: UIGravityBehavior?
        private var currentItemBehavior: UIDynamicItemBehavior?
        private var pendingItems: [Item] = []

        private(set) var currentItemIDs: [BookID] = []

        init(onTap: @escaping @MainActor (BookID) -> Void, onLongPress: @escaping @MainActor (BookID) -> Void) {
            self.onTap = onTap
            self.onLongPress = onLongPress
        }

        func rebuild(with items: [Item]) {
            guard let container else {
                pendingItems = items
                return
            }
            // 既存ビューを一度全消去して作り直す
            animator?.removeAllBehaviors()
            animator = nil
            for (_, view) in itemViews { view.removeFromSuperview() }
            itemViews.removeAll()
            currentCollision = nil
            currentGravity = nil
            currentItemBehavior = nil
            pendingItems = items
            currentItemIDs = items.map(\.id)

            let size = container.bounds.size
            if size.width > 0, size.height > 0 {
                installItems(items, in: size)
            }
            // サイズ未確定ならレイアウト確定時 (handleLayout) に installItems が走る。
        }

        func refreshContent(items: [Item]) {
            for item in items {
                itemViews[item.id]?.update(item: item)
            }
        }

        /// コンテナのレイアウト確定・サイズ変更時に呼ばれる。
        /// まだアイテムをインストールしていなければここで実行、既に設置済みなら衝突境界だけ貼り直す。
        private func handleLayout(size: CGSize) {
            guard size.width > 0, size.height > 0 else { return }
            if itemViews.isEmpty, !pendingItems.isEmpty {
                installItems(pendingItems, in: size)
            } else if !itemViews.isEmpty {
                rebuildCollisions(for: size)
            }
        }

        /// サイズが確定している前提で、アイテムの UIView 生成・物理挙動の wiring を全部やる。
        private func installItems(_ items: [Item], in size: CGSize) {
            guard let container else { return }
            let padding: CGFloat = 20

            for (index, item) in items.enumerated() {
                let s = item.size
                let maxX = max(padding, size.width - padding - s.width)
                let x = CGFloat.random(in: padding...max(padding + 1, maxX))
                // index * 36 で縦にずらして同時衝突を減らす
                let y = -s.height - 20 - CGFloat(index) * 36
                let view = ItemView(item: item,
                                    onTap: { [weak self] id in self?.onTap(id) },
                                    onLongPress: { [weak self] id in self?.onLongPress(id) })
                view.frame = CGRect(origin: CGPoint(x: x, y: y), size: s)
                container.addSubview(view)
                itemViews[item.id] = view
            }

            // サイズ確定後に animator を生成（referenceView の bounds が有効になってから）
            let animator = UIDynamicAnimator(referenceView: container)
            self.animator = animator

            let views = Array(itemViews.values)
            guard !views.isEmpty else { return }

            // Notion 02 の物理値: restitution 0.1 / friction 0.8 / 角度ダンピング 0.6
            let itemBehavior = UIDynamicItemBehavior(items: views)
            itemBehavior.elasticity = 0.1
            itemBehavior.friction = 0.8
            itemBehavior.angularResistance = 0.6
            itemBehavior.allowsRotation = true
            animator.addBehavior(itemBehavior)
            currentItemBehavior = itemBehavior

            let gravity = UIGravityBehavior(items: views)
            gravity.magnitude = 1.0
            animator.addBehavior(gravity)
            currentGravity = gravity

            rebuildCollisions(for: size)
        }

        /// 上辺は開放し、左・右・床の 3 本だけ境界にする。
        /// 閉じた矩形にすると負 y で生成したアイテムが外側上辺にぶつかって画面に入ってこない。
        private func rebuildCollisions(for size: CGSize) {
            guard let animator else { return }
            if let old = currentCollision { animator.removeBehavior(old) }
            let views = Array(itemViews.values)
            let collision = UICollisionBehavior(items: views)
            collision.translatesReferenceBoundsIntoBoundary = false

            let floorY = max(size.height - 4, 1)
            let left = UIBezierPath()
            left.move(to: CGPoint(x: 0, y: -1000))
            left.addLine(to: CGPoint(x: 0, y: floorY))
            collision.addBoundary(withIdentifier: "left" as NSString, for: left)

            let right = UIBezierPath()
            right.move(to: CGPoint(x: size.width, y: -1000))
            right.addLine(to: CGPoint(x: size.width, y: floorY))
            collision.addBoundary(withIdentifier: "right" as NSString, for: right)

            let floor = UIBezierPath()
            floor.move(to: CGPoint(x: 0, y: floorY))
            floor.addLine(to: CGPoint(x: size.width, y: floorY))
            collision.addBoundary(withIdentifier: "floor" as NSString, for: floor)

            animator.addBehavior(collision)
            currentCollision = collision
        }
    }

    // MARK: - Per-item view

    final class ItemView: UIView {
        private let imageView = UIImageView()
        private let titleLabel = UILabel()
        private let tapRecognizer = UITapGestureRecognizer()
        private let longPressRecognizer = UILongPressGestureRecognizer()
        private var bookID: BookID
        private let onTap: (BookID) -> Void
        private let onLongPress: (BookID) -> Void

        init(item: Item, onTap: @escaping (BookID) -> Void, onLongPress: @escaping (BookID) -> Void) {
            self.bookID = item.id
            self.onTap = onTap
            self.onLongPress = onLongPress
            super.init(frame: .zero)
            backgroundColor = .white
            layer.cornerRadius = 3
            clipsToBounds = true
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.12
            layer.shadowRadius = 3
            layer.shadowOffset = CGSize(width: 0, height: 2)

            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(imageView)

            titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
            titleLabel.textColor = .darkGray
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 2
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(titleLabel)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
                imageView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])

            tapRecognizer.addTarget(self, action: #selector(didTap))
            addGestureRecognizer(tapRecognizer)
            longPressRecognizer.minimumPressDuration = 0.5
            longPressRecognizer.addTarget(self, action: #selector(didLongPress))
            addGestureRecognizer(longPressRecognizer)

            update(item: item)
        }

        required init?(coder: NSCoder) { nil }

        func update(item: Item) {
            bookID = item.id
            if let data = item.imageData, let image = UIImage(data: data) {
                imageView.image = image
                titleLabel.isHidden = true
            } else {
                imageView.image = nil
                titleLabel.isHidden = false
                titleLabel.text = String(item.title.prefix(8))
            }
        }

        @objc private func didTap() {
            onTap(bookID)
        }

        @objc private func didLongPress(_ gr: UILongPressGestureRecognizer) {
            guard gr.state == .began else { return }
            onLongPress(bookID)
        }
    }
}

#endif
