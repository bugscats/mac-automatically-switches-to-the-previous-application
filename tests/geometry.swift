import Foundation

@main
struct GeometryTests {
    static func main() {
        let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let left = CGRect(x: -1280, y: 0, width: 1280, height: 800)
        func zones(_ screens: [CGRect], mainOnly: Bool = false) -> TriggerZones {
            TriggerZones(screens: screens, length: 300, width: 5, mainOnly: mainOnly)
        }
        let single = zones([main])
        precondition(single.contains(CGPoint(x: 1, y: 450)))
        precondition(!single.contains(CGPoint(x: 5, y: 450)))
        precondition(!single.contains(CGPoint(x: 1, y: 299)))
        precondition(!single.contains(CGPoint(x: 1, y: 601)))
        let dual = zones([main, left])
        precondition(!dual.contains(CGPoint(x: 1, y: 450)), "Shared edge must not switch apps")
        precondition(dual.contains(CGPoint(x: -1279, y: 400)))
        let primaryOnly = zones([main, left], mainOnly: true)
        precondition(!primaryOnly.contains(CGPoint(x: -1279, y: 400)))
        precondition(!primaryOnly.contains(CGPoint(x: 1, y: 450)), "Primary screen still respects shared edges")
        let partial = zones([main, CGRect(x: -1280, y: 500, width: 1280, height: 800)])
        precondition(partial.contains(CGPoint(x: 1, y: 450)))
        precondition(!partial.contains(CGPoint(x: 1, y: 550)))
        let short = zones([CGRect(x: 0, y: 0, width: 100, height: 100)])
        precondition(short.contains(CGPoint(x: 1, y: 1)))
        precondition(zones([]).contains(.zero) == false)
        print("12 项区域边界检查通过")
    }
}
