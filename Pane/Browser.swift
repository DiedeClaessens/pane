import Observation
import UIKit
import WebKit

final class Tab: Identifiable {
    let id = UUID()
    let page: WebPage
    private let savedURL: URL
    private let savedTitle: String

    init(page: WebPage, url: URL, title: String = "") {
        self.page = page
        savedURL = url
        savedTitle = title
    }

    var url: URL { page.url ?? savedURL }
    var title: String {
        if !page.title.isEmpty { return page.title }
        if !savedTitle.isEmpty { return savedTitle }
        return url.host() ?? "New Tab"
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
    /// A page's alert, confirm or prompt, waiting for an answer.
    var dialog: Dialog?
    /// A page's file field, waiting for files.
    var fileRequest: FileRequest?
    var searchEngine = SearchEngine(rawValue: UserDefaults.standard.string(forKey: "searchEngine") ?? "") ?? .google {
        didSet { UserDefaults.standard.set(searchEngine.rawValue, forKey: "searchEngine") }
    }
    /// Turns every page dark with Dark Reader. Open pages reload so every frame picks up the change.
    var darkPages = UserDefaults.standard.bool(forKey: "darkPages") {
        didSet {
            UserDefaults.standard.set(darkPages, forKey: "darkPages")
            installScripts()
            for tab in tabs where tab.page.url != nil { tab.page.reload() }
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

    func open(_ url: URL) { open(URLRequest(url: url)) }

    /// Opens the request in a new tab after the current one. A form posted to a new window keeps its method and body.
    func open(_ request: URLRequest) {
        guard let url = request.url else { return }
        let tab = makeTab(url: url)
        let index = tabs.firstIndex { $0.id == selectedID }.map { $0 + 1 } ?? tabs.endIndex
        tabs.insert(tab, at: index)
        tab.page.load(request)
        select(tab)
    }

    /// Closes the command bar, which holds the address of the tab it was opened on.
    func select(_ tab: Tab) {
        selectedID = tab.id
        commandBar = nil
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

    /// Opens a pane:<address> link, sent by the "Open in Pane" shortcut, in a new tab.
    func open(paneLink link: URL) {
        go(to: link.absoluteString.replacing(/^pane:/, with: ""), in: .newTab)
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

    /// Answers the open dialog. A prompt answers with the dialog's text.
    func closeDialog(ok: Bool) {
        let dialog = dialog
        self.dialog = nil
        dialog?.answer(ok ? dialog?.text : nil)
    }

    /// Hands the picked files to the page. Nil cancels.
    func closeFileRequest(_ files: [URL]?) {
        let request = fileRequest
        fileRequest = nil
        request?.answer(files)
    }

    /// A dialog that comes while another dialog or the file picker is open is cancelled, so the alert on screen is always the one being answered.
    fileprivate func ask(_ kind: Dialog.Kind, _ message: String, from frame: WebPage.FrameInfo, text: String = "") async -> String? {
        guard dialog == nil, fileRequest == nil else { return nil }
        return await withCheckedContinuation { answer in
            dialog = Dialog(kind: kind, site: frame.securityOrigin.host, message: message, text: text) { answer.resume(returning: $0) }
        }
    }

    fileprivate func askForFiles(multiple: Bool) async -> [URL]? {
        guard fileRequest == nil, dialog == nil else { return nil }
        return await withCheckedContinuation { answer in
            fileRequest = FileRequest(multiple: multiple) { answer.resume(returning: $0) }
        }
    }

    func save() {
        let saved = Saved(tabs: tabs.map { Saved.Tab(url: $0.url, title: $0.title) }, selected: tabs.firstIndex { $0.id == selectedID })
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(saved).write(to: file, options: .atomic)
    }

    /// A web address when the input looks like one, otherwise a search.
    static func destination(for input: String, searchingWith engine: SearchEngine) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()) { return url }
        if !text.contains(" "), text.contains("."), let url = URL(string: "https://" + text) { return url }
        var search = URLComponents(string: engine.address)!
        search.queryItems = [URLQueryItem(name: engine.queryName, value: text)]
        return search.url
    }

    private func makeTab(url: URL, title: String = "") -> Tab {
        var configuration = WebPage.Configuration()
        configuration.userContentController = scripts
        let page = WebPage(configuration: configuration, navigationDecider: Links { [weak self] in self?.open($0) }, dialogPresenter: Dialogs(browser: self))
        return Tab(page: page, url: url, title: title)
    }

    private func installScripts() {
        scripts.removeAllUserScripts()
        scripts.addUserScript(WKUserScript(source: Self.windowOpen, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .page))
        guard darkPages else { return }
        scripts.addUserScript(WKUserScript(source: Self.darkReader, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .defaultClient))
    }

    /// WebPage cannot create windows, so `window.open` would return null and open nothing.
    /// It clicks a new-window link instead, which opens a tab. The page gets no handle to that tab.
    private static let windowOpen = """
        window.open = url => {
            if (url) Object.assign(document.createElement("a"), { href: url, target: "_blank" }).click();
            return null;
        };
        """

    /// Dark Reader (darkreader.js, MIT, from the darkreader npm package), turned on.
    /// Its fetch loads stylesheets from other hosts. A bare `fetch` would lose `this` and fail.
    private static let darkReader = """
        \(try! String(contentsOf: Bundle.main.url(forResource: "darkreader", withExtension: "js")!, encoding: .utf8))
        DarkReader.setFetchMethod(url => fetch(url));
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

struct Dialog {
    enum Kind { case alert, confirm, prompt }

    /// A new identity makes SwiftUI show a new alert, even when the last one is still closing.
    let id = UUID()
    let kind: Kind
    /// The host of the page or frame that asks, so a frame cannot pose as the page.
    let site: String
    let message: String
    var text: String
    /// Nil is Cancel.
    let answer: (String?) -> Void
}

struct FileRequest {
    let multiple: Bool
    /// Nil is Cancel.
    let answer: ([URL]?) -> Void
}

/// Links that would open a new window (target="_blank", window.open) open in a new tab instead.
/// Links WebKit cannot load, such as mailto: and tel:, open in their own app when the page itself asks for it, not a frame inside it such as an ad.
private struct Links: WebPage.NavigationDeciding {
    let open: (URLRequest) -> Void

    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        if let url = action.request.url, let scheme = url.scheme, !WKWebView.handlesURLScheme(scheme) {
            if action.source.isMainFrame { await UIApplication.shared.open(url) }
            return .cancel
        }
        guard action.target == nil else { return .allow }
        open(action.request)
        return .cancel
    }
}

/// Shows a page's alert, confirm, prompt and file field in the browser.
private struct Dialogs: WebPage.DialogPresenting {
    weak var browser: Browser?

    func handleJavaScriptAlert(message: String, initiatedBy frame: WebPage.FrameInfo) async {
        _ = await browser?.ask(.alert, message, from: frame)
    }

    func handleJavaScriptConfirm(message: String, initiatedBy frame: WebPage.FrameInfo) async -> WebPage.JavaScriptConfirmResult {
        await browser?.ask(.confirm, message, from: frame) == nil ? .cancel : .ok
    }

    func handleJavaScriptPrompt(message: String, defaultText: String?, initiatedBy frame: WebPage.FrameInfo) async -> WebPage.JavaScriptPromptResult {
        guard let text = await browser?.ask(.prompt, message, from: frame, text: defaultText ?? "") else { return .cancel }
        return .ok(text)
    }

    func handleFileInputPrompt(parameters: WKOpenPanelParameters, initiatedBy frame: WebPage.FrameInfo) async -> WebPage.FileInputPromptResult {
        guard let files = await browser?.askForFiles(multiple: parameters.allowsMultipleSelection) else { return .cancel }
        return .selected(files)
    }
}
