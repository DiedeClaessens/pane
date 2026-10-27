import Foundation
import Observation
import WebKit

@Observable final class Tab: Identifiable {
    let id = UUID()
    let page: WebPage
    private let savedURL: URL?
    private let savedTitle: String

    init(page: WebPage, url: URL?, title: String = "") {
        self.page = page
        savedURL = url
        savedTitle = title
    }

    var url: URL? { page.url ?? savedURL }
    var title: String {
        if !page.title.isEmpty { return page.title }
        if !savedTitle.isEmpty { return savedTitle }
        return url?.host() ?? "New Tab"
    }

    /// Restored tabs only start loading once they are shown.
    func wake() {
        if page.url == nil, !page.isLoading { page.load(savedURL) }
    }
}

@Observable final class Browser {
    enum CommandBar { case newTab, currentTab }

    private(set) var tabs: [Tab] = []
    private(set) var selectedID: Tab.ID?
    var showsSidebar = false
    var commandBar: CommandBar?
    private let file: URL

    var selected: Tab? { tabs.first { $0.id == selectedID } }

    init(file: URL = .applicationSupportDirectory.appending(path: "tabs.json")) {
        self.file = file
        guard let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        tabs = saved.tabs.map { makeTab(url: $0.url, title: $0.title) }
        if let index = saved.selected, tabs.indices.contains(index) { select(tabs[index]) }
    }

    func open(_ url: URL) {
        let tab = makeTab(url: url)
        let index = tabs.firstIndex { $0.id == selectedID }.map { $0 + 1 } ?? tabs.endIndex
        tabs.insert(tab, at: index)
        select(tab)
    }

    func select(_ tab: Tab) {
        selectedID = tab.id
        tab.wake()
    }

    func select(offset: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        select(tabs[(index + offset + tabs.count) % tabs.count])
    }

    func close(_ tab: Tab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)
        if tab.id == selectedID, !tabs.isEmpty { select(tabs[min(index, tabs.count - 1)]) }
    }

    func go(to input: String, in mode: CommandBar) {
        guard let url = Self.destination(for: input) else { return }
        if mode == .currentTab, let selected { selected.page.load(url) } else { open(url) }
        commandBar = nil
    }

    func showCommandBar(_ mode: CommandBar) {
        showsSidebar = false
        commandBar = mode
    }

    func goBack() {
        guard let page = selected?.page, let item = page.backForwardList.backList.last else { return }
        page.load(item)
    }

    func goForward() {
        guard let page = selected?.page, let item = page.backForwardList.forwardList.first else { return }
        page.load(item)
    }

    func save() {
        let saved = Saved(tabs: tabs.compactMap { tab in tab.url.map { Saved.Tab(url: $0, title: tab.title) } }, selected: tabs.firstIndex { $0.id == selectedID })
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(saved).write(to: file)
    }

    /// A web address when the input looks like one, otherwise a Google search.
    static func destination(for input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("http://") || text.hasPrefix("https://"), let url = URL(string: text) { return url }
        if !text.contains(" "), text.contains("."), let url = URL(string: "https://" + text) { return url }
        var search = URLComponents(string: "https://www.google.com/search")!
        search.queryItems = [URLQueryItem(name: "q", value: text)]
        return search.url
    }

    private func makeTab(url: URL?, title: String = "") -> Tab {
        Tab(page: WebPage(navigationDecider: NewWindowsAsTabs { [weak self] in self?.open($0) }), url: url, title: title)
    }

    private struct Saved: Codable {
        struct Tab: Codable {
            var url: URL
            var title: String
        }

        var tabs: [Tab]
        var selected: Int?
    }
}

/// Links that would open a new window (target="_blank", window.open) open in a new tab instead.
private struct NewWindowsAsTabs: WebPage.NavigationDeciding {
    let open: (URL) -> Void

    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        guard action.target == nil, let url = action.request.url else { return .allow }
        open(url)
        return .cancel
    }
}
