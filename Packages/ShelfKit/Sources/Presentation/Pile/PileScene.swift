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
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        physicsBody?.restitution = 0.1
        physicsBody?.friction = 0.8
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        physicsBody?.restitution = 0.1
        physicsBody?.friction = 0.8
    }

    func update(items: [Item], initial: Bool) {
        // Remove nodes for IDs no longer present
        let newIDs = Set(items.map(\.id))
        for (id, node) in nodesByID where !newIDs.contains(id) {
            node.removeFromParent()
            nodesByID.removeValue(forKey: id)
        }

        for (index, item) in items.enumerated() {
            if nodesByID[item.id] != nil { continue }
            let node = makeNode(for: item)
            node.position = CGPoint(x: CGFloat.random(in: 40...size.width - 40), y: size.height + 20 + CGFloat(index) * 10)
            if initial {
                let delay = SKAction.wait(forDuration: 0.08 * Double(index))
                node.alpha = 0
                let fade = SKAction.fadeIn(withDuration: 0.1)
                node.run(SKAction.sequence([delay, fade]))
            }
            addChild(node)
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
