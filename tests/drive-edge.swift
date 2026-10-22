import AppKit
import CoreGraphics

let bounds = CGDisplayBounds(CGMainDisplayID())
// Stage near the edge so synthetic long-distance moves do not activate other gestures.
let center = CGPoint(x: bounds.minX + 20, y: bounds.midY)
let edge = CGPoint(x: bounds.minX + 1, y: bounds.midY)

func moveMouse(to point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
            mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}

moveMouse(to: center)
RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
if CommandLine.arguments.dropFirst().first == "--center" { exit(0) }
let maximumMilliseconds = Double(CommandLine.arguments[2])!
let before = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
let requested = CommandLine.arguments[1]
let noSwitch = requested == "--no-switch"
let expected = noSwitch ? before : requested == "--pair"
    ? (before == "com.google.Chrome" ? "com.microsoft.VSCode" : "com.google.Chrome")
    : requested
if requested == "--pair" && !["com.google.Chrome", "com.microsoft.VSCode"].contains(before) {
    fputs("Test setup interrupted by another foreground application\n", stderr)
    exit(2)
}
let start = ProcessInfo.processInfo.systemUptime
moveMouse(to: edge)
var after = before
while ProcessInfo.processInfo.systemUptime - start < 2 {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.002))
    after = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    if after == expected { break }
}
let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000
// Staying inside the edge must not switch back a second time.
var observedApps: [String] = []
var pointerLeftZone = false
var pointerDeviation: [String: Double] = [:]
let holdUntil = ProcessInfo.processInfo.systemUptime + 0.25
while ProcessInfo.processInfo.systemUptime < holdUntil {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.002))
    let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    if observedApps.last != foreground { observedApps.append(foreground) }
    if let point = CGEvent(source: nil)?.location {
        if point.x < bounds.minX || point.x >= bounds.minX + 5 || abs(point.y - edge.y) >= 150 {
            pointerLeftZone = true
            if pointerDeviation.isEmpty { pointerDeviation = ["x": point.x, "y": point.y] }
        }
    }
}
let stableApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
let stable = observedApps.allSatisfy { $0 == expected } && stableApp == expected && !pointerLeftZone
moveMouse(to: center)
let passed = (noSwitch || before != expected) && after == expected && stable && elapsed < maximumMilliseconds
let result: [String: Any] = ["before": before, "after": after,
                           "expected": expected, "elapsed_ms": Int(elapsed),
                           "stable_app": stableApp,
                           "observed_apps": observedApps, "pointer_left_zone": pointerLeftZone,
                           "pointer_deviation": pointerDeviation,
                           "stable": stable, "passed": passed]
let data = try JSONSerialization.data(withJSONObject: result, options: .sortedKeys)
print(String(decoding: data, as: UTF8.self))
if pointerLeftZone {
    fputs("Test setup interrupted: pointer left the default trigger zone during the hold\n", stderr)
    exit(2)
}
exit(passed ? 0 : 1)
