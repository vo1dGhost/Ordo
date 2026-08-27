import CoreGraphics
import Foundation

/// 将鼠标相对手势分类到八个 45° 扇区，并提供半径与角度迟滞。
struct RadialGestureClassifier: Sendable, Equatable {
    static let defaultEntryRadius: CGFloat = 24
    static let defaultExitRadius: CGFloat = 16
    static let defaultAngularHysteresis: CGFloat = 6 * .pi / 180

    let entryRadius: CGFloat
    let exitRadius: CGFloat
    let angularHysteresis: CGFloat

    private(set) var currentLayout: SnapLayout?

    init(
        entryRadius: CGFloat = RadialGestureClassifier.defaultEntryRadius,
        exitRadius: CGFloat = RadialGestureClassifier.defaultExitRadius,
        angularHysteresis: CGFloat = RadialGestureClassifier.defaultAngularHysteresis
    ) {
        let safeEntryRadius = max(0, entryRadius)
        self.entryRadius = safeEntryRadius
        self.exitRadius = min(max(0, exitRadius), safeEntryRadius)
        self.angularHysteresis = min(max(0, angularHysteresis), .pi / 8)
    }

    @discardableResult
    mutating func update(from origin: CGPoint, to location: CGPoint) -> SnapLayout? {
        let vector = CGVector(dx: location.x - origin.x, dy: location.y - origin.y)
        let distance = hypot(vector.dx, vector.dy)

        if currentLayout == nil {
            guard distance > entryRadius else {
                return nil
            }
            currentLayout = Self.layout(for: vector)
            return currentLayout
        }

        if distance <= exitRadius {
            currentLayout = nil
            return nil
        }

        guard let currentLayout else {
            return nil
        }

        let angle = atan2(vector.dy, vector.dx)
        let currentCenter = Self.centerAngle(for: currentLayout)
        let distanceFromCenter = abs(Self.normalizedAngle(angle - currentCenter))
        let retainedHalfAngle = .pi / 8 + angularHysteresis

        if distanceFromCenter > retainedHalfAngle {
            self.currentLayout = Self.layout(for: vector)
        }
        return self.currentLayout
    }

    mutating func reset() {
        currentLayout = nil
    }

    static func layout(for vector: CGVector) -> SnapLayout {
        let angle = atan2(vector.dy, vector.dx)
        let sector = Int((angle / (.pi / 4)).rounded(.toNearestOrAwayFromZero))
        let normalizedSector = (sector % 8 + 8) % 8

        switch normalizedSector {
        case 0:
            return .right
        case 1:
            return .bottomRight
        case 2:
            return .bottom
        case 3:
            return .bottomLeft
        case 4:
            return .left
        case 5:
            return .topLeft
        case 6:
            return .top
        default:
            return .topRight
        }
    }

    private static func centerAngle(for layout: SnapLayout) -> CGFloat {
        switch layout {
        case .right:
            return 0
        case .bottomRight:
            return .pi / 4
        case .bottom:
            return .pi / 2
        case .bottomLeft:
            return 3 * .pi / 4
        case .left:
            return .pi
        case .topLeft:
            return -3 * .pi / 4
        case .top:
            return -.pi / 2
        case .topRight:
            return -.pi / 4
        }
    }

    private static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var normalized = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if normalized > .pi {
            normalized -= 2 * .pi
        } else if normalized < -.pi {
            normalized += 2 * .pi
        }
        return normalized
    }
}
