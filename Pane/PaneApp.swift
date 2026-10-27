import SwiftUI

@main
struct PaneApp: App {
    @State private var browser = Browser()

    var body: some Scene {
        WindowGroup {
            BrowserView(browser: browser)
                .onOpenURL { browser.open(paneLink: $0) }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { browser.showCommandBar(.newTab) }
                    .keyboardShortcut("t")
                Button("Open Location") { browser.showCommandBar(.currentTab) }
                    .keyboardShortcut("l")
                Button("Close Tab") { browser.selected.map(browser.close) }
                    .keyboardShortcut("w")
            }
            CommandGroup(before: .sidebar) {
                Button("Toggle Sidebar") { browser.showsSidebar.toggle() }
                    .keyboardShortcut("s")
                Button("Back") { browser.goBack() }
                    .keyboardShortcut("[")
                Button("Forward") { browser.goForward() }
                    .keyboardShortcut("]")
                Button("Reload") { browser.selected?.page.reload() }
                    .keyboardShortcut("r")
                Button("Next Tab") { browser.select(offset: 1) }
                    .keyboardShortcut(.tab, modifiers: .control)
                Button("Previous Tab") { browser.select(offset: -1) }
                    .keyboardShortcut(.tab, modifiers: [.control, .shift])
            }
        }
    }
}
