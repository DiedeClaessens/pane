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
    var searchEngine = SearchEngine(rawValue: UserDefaults.standard.string(forKey: "searchEngine") ?? "") ?? .google {
        didSet { UserDefaults.standard.set(searchEngine.rawValue, forKey: "searchEngine") }
    }
    /// Turns every page dark with Dark Reader, also the pages that are already open.
    var darkPages = UserDefaults.standard.bool(forKey: "darkPages") {
        didSet {
            UserDefaults.standard.set(darkPages, forKey: "darkPages")
            installScripts()
            for tab in tabs where tab.page.url != nil {
                Task { try? await tab.page.callJavaScript(darkPages ? Self.darkReader : "DarkReader.disable()", contentWorld: .defaultClient) }
            }
        }
    }
    private let file: URL
    private let scripts = WKUserContentController()

    var selected: Tab? { tabs.first { $0.id == selectedID } }

    init(file: URL = .applicationSupportDirectory.appending(path: "tabs.json")) {
        self.file = file
        installScripts()
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
        guard let url = Self.destination(for: input, searchingWith: searchEngine) else { return }
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

    /// A web address when the input looks like one, otherwise a search.
    static func destination(for input: String, searchingWith engine: SearchEngine) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("http://") || text.hasPrefix("https://"), let url = URL(string: text) { return url }
        if !text.contains(" "), text.contains("."), let url = URL(string: "https://" + text) { return url }
        var search = URLComponents(string: engine.address)!
        search.queryItems = [URLQueryItem(name: engine.queryName, value: text)]
        return search.url
    }

    private func makeTab(url: URL?, title: String = "") -> Tab {
        var configuration = WebPage.Configuration()
        configuration.userContentController = scripts
        return Tab(page: WebPage(configuration: configuration, navigationDecider: NewWindowsAsTabs { [weak self] in self?.open($0) }), url: url, title: title)
    }

    private func installScripts() {
        scripts.removeAllUserScripts()
        guard darkPages else { return }
        scripts.addUserScript(WKUserScript(source: Self.darkReader, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .defaultClient))
    }

    /// Loads Dark Reader (darkreader.js, MIT, from the darkreader npm package) once per page and turns it on.
    private static let darkReader = """
        if (!self.DarkReader) {
        \(try! String(contentsOf: Bundle.main.url(forResource: "darkreader", withExtension: "js")!, encoding: .utf8))
        }
        DarkReader.setFetchMethod(self.fetch);
        DarkReader.enable({});
        """

    private struct Saved: Codable {
        struct Tab: Codable {
            var url: URL
            var title: String
        }

        var tabs: [Tab]
        var selected: Int?
    }
}

enum SearchEngine: String, CaseIterable, Identifiable {
    case google = "Google", duckDuckGo = "DuckDuckGo", kagi = "Kagi", brave = "Brave Search", startpage = "Startpage", ecosia = "Ecosia", bing = "Bing"

    var id: Self { self }

    var address: String {
        switch self {
        case .google: "https://www.google.com/search"
        case .duckDuckGo: "https://duckduckgo.com/"
        case .kagi: "https://kagi.com/search"
        case .brave: "https://search.brave.com/search"
        case .startpage: "https://www.startpage.com/sp/search"
        case .ecosia: "https://www.ecosia.org/search"
        case .bing: "https://www.bing.com/search"
        }
    }

    var queryName: String { self == .startpage ? "query" : "q" }
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
