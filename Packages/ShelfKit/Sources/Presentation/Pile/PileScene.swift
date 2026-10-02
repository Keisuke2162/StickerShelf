#if canImport(UIKit)
import SpriteKit
import Domain

/// 積読画面の物理シーン。古い順に上から落として下に積む。
final class PileScene: SKScene {
    struct Item: Sendable {
        let id: BookID
        let title: String
        let orientation: Orientation
        let image: SendableImageData?
    }

    enum Orientation: Sendable {
        case vertical, horizontal

        var size: CGSize {
            switch self {
            case .vertical: return CGSize(width: 52, height: 74)
            case .horizontal: return CGSize(width: 74, height: 52)
            }
        }
    }

    struct SendableImageData: Sendable {
        let data: Data
    }

    var onTap: ((BookID) -> Void)?
    var onLongPress: ((BookID) -> Void)?

    private var nodesByID: [BookID: SKNode] = [:]

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 4, width: size.width, height: size.height - 4))
        physicsBody?.restitution = 0.1
        physicsBody?.friction = 0.8
        rebuildDecorations()

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPress)
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began, let view = gr.view as? SKView else { return }
        let locationInView = gr.location(in: view)
        let scenePoint = convertPoint(fromView: locationInView)
        let hit = nodes(at: scenePoint).first { $0.userData?["bookID"] != nil }
        guard let hit, let raw = hit.userData?["bookID"] as? String, let uuid = UUID(uuidString: raw) else { return }
        onLongPress?(BookID(uuid))
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 4, width: size.width, height: size.height - 4))
        physicsBody?.restitution = 0.1
        physicsBody?.friction = 0.8
        rebuildDecorations()
    }

    private func rebuildDecorations() {
        children.filter { $0.name == "decoration" }.forEach { $0.removeFromParent() }

        // 方眼線（1pt, 26pt 間隔）
        let gridPath = CGMutablePath()
        var x: CGFloat = 0
        while x < size.width {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
            x += 26
        }
        var y: CGFloat = 0
        while y < size.height {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
            y += 26
        }
        let grid = SKShapeNode(path: gridPath)
        grid.strokeColor = UIColor(red: 213/255, green: 218/255, blue: 225/255, alpha: 1) // pileGrid #D5DAE1
        grid.lineWidth = 1
        grid.zPosition = -2
        grid.name = "decoration"
        addChild(grid)

        // 床ライン（高さ 4pt, pileFloor #9AA2AE）
        let floor = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: 4))
        floor.fillColor = UIColor(red: 154/255, green: 162/255, blue: 174/255, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = -1
        floor.name = "decoration"
        addChild(floor)
    }

    func update(items: [Item], initial: Bool) {
        // Remove nodes for IDs no longer present
        let newIDs = Set(items.map(\.id))
        for (id, node) in nodesByID where !newIDs.contains(id) {
            node.removeFromParent()
            nodesByID.removeValue(forKey: id)
        }

        let lower: CGFloat = min(40, size.width / 4)
        let upper: CGFloat = max(size.width - 40, lower + 1)
        for (index, item) in items.enumerated() {
            if nodesByID[item.id] != nil { continue }
            let node = makeNode(for: item)
            let x = CGFloat.random(in: lower...upper)
            if initial {
                // 「追加日の古い順に 0.08 秒間隔で上から落として積む」
                node.position = CGPoint(x: x, y: size.height + 40)
                node.isHidden = true
                let waitAction = SKAction.wait(forDuration: 0.08 * Double(index))
                let unhide = SKAction.run { node.isHidden = false }
                addChild(node)
                node.run(SKAction.sequence([waitAction, unhide]))
            } else {
                node.position = CGPoint(x: x, y: size.height + 20)
                addChild(node)
            }
            nodesByID[item.id] = node
        }
    }

    private func makeNode(for item: PileScene.Item) -> SKNode {
        let size = item.orientation.size
        let container = SKNode()
        container.name = item.id.rawValue.uuidString
        container.userData = NSMutableDictionary()
        container.userData?.setValue(item.id.rawValue.uuidString, forKey: "bookID")

        let background = SKShapeNode(rectOf: size, cornerRadius: 3)
        background.fillColor = .white
        background.strokeColor = .clear
        container.addChild(background)

        if let data = item.image?.data, let image = UIImage(data: data) {
            let texture = SKTexture(image: image)
            let sprite = SKSpriteNode(texture: texture, size: CGSize(width: size.width - 4, height: size.height - 4))
            container.addChild(sprite)
        } else {
            let label = SKLabelNode(text: String(item.title.prefix(8)))
            label.fontColor = .darkGray
            label.fontSize = 10
            label.verticalAlignmentMode = .center
            container.addChild(label)
        }

        let body = SKPhysicsBody(rectangleOf: size)
        body.restitution = 0.1
        body.friction = 0.8
        body.angularDamping = 0.6
        body.allowsRotation = true
        container.physicsBody = body
        return container
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = nodes(at: location).first { $0.userData?["bookID"] != nil }
        guard let node, let raw = node.userData?["bookID"] as? String, let uuid = UUID(uuidString: raw) else { return }
        onTap?(BookID(uuid))
    }
}

#endif
