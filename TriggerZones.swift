import Foundation
import CoreGraphics

struct TriggerZones {
    let screens: [CGRect]
    let regions: [CGRect]

    init(screens: [CGRect], length: Double, width: Double, mainOnly: Bool) {
        self.screens = screens
        let active = mainOnly ? Array(screens.prefix(1)) : screens
        regions = active.map { frame in
            let height = min(length, frame.height)
            return CGRect(x: frame.minX, y: frame.midY - height / 2,
                          width: width, height: height)
        }
    }

    func contains(_ point: CGPoint) -> Bool {
        regions.contains { region in
            region.contains(point) && !screens.contains { frame in
                frame.contains(CGPoint(x: region.minX - 1, y: point.y))
            }
        }
    }
}
