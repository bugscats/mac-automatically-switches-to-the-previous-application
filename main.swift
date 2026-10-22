import AppKit

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = Switcher()
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}
