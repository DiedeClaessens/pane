import Foundation
import SwiftUI
import Testing
@testable import Pane

private func tabsFile() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)/tabs.json")
}

@Test func anAddressWithoutSchemeOpensOverHTTPS() {
    #expect(Browser.destination(for: " example.com/docs ", searchingWith: .google) == URL(string: "https://example.com/docs"))
}

@Test func anAddressWithSchemeOpensAsTyped() {
    #expect(Browser.destination(for: "http://localhost:4000/a", searchingWith: .google) == URL(string: "http://localhost:4000/a"))
    #expect(Browser.destination(for: "HTTP://localhost:4000/a", searchingWith: .google) == URL(string: "HTTP://localhost:4000/a"))
}

@Test func wordsSearchGoogle() {
    #expect(Browser.destination(for: "swift.org release notes", searchingWith: .google) == URL(string: "https://www.google.com/search?q=swift.org%20release%20notes"))
    #expect(Browser.destination(for: "weather", searchingWith: .google) == URL(string: "https://www.google.com/search?q=weather"))
}

@Test func wordsSearchThePickedEngine() {
    #expect(Browser.destination(for: "weather", searchingWith: .duckDuckGo) == URL(string: "https://duckduckgo.com/?q=weather"))
    #expect(Browser.destination(for: "weather", searchingWith: .startpage) == URL(string: "https://www.startpage.com/sp/search?query=weather"))
}

@Test func blankInputGoesNowhere() {
    #expect(Browser.destination(for: "   ", searchingWith: .google) == nil)
}

@Test func linksOpenNextToTheCurrentTab() {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "https://a.com")!)
    browser.open(URL(string: "https://c.com")!)
    browser.select(browser.tabs[0])
    browser.open(URL(string: "https://b.com")!)
    #expect(browser.tabs.map { $0.url.host() } == ["a.com", "b.com", "c.com"])
    #expect(browser.selected?.url.host() == "b.com")
}

@Test func closingTheSelectedTabSelectsTheNextOne() {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "https://a.com")!)
    browser.open(URL(string: "https://b.com")!)
    browser.open(URL(string: "https://c.com")!)
    browser.select(browser.tabs[1])
    browser.close(browser.tabs[1])
    #expect(browser.selected?.url.host() == "c.com")
    browser.close(browser.tabs[1])
    #expect(browser.selected?.url.host() == "a.com")
}

@Test func aPaneLinkOpensItsAddressInANewTab() {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "https://a.com")!)
    browser.open(paneLink: URL(string: "pane:https://b.com/x?y=1")!)
    #expect(browser.tabs.map { $0.url.host() } == ["a.com", "b.com"])
    #expect(browser.selected?.url == URL(string: "https://b.com/x?y=1"))
}

@Test func nextTabWrapsAround() {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "https://a.com")!)
    browser.open(URL(string: "https://b.com")!)
    browser.select(offset: 1)
    #expect(browser.selected?.url.host() == "a.com")
    browser.select(offset: -1)
    #expect(browser.selected?.url.host() == "b.com")
}

@Test func tabsComeBackAfterARestart() {
    let file = tabsFile()
    let browser = Browser(file: file)
    browser.open(URL(string: "https://a.com/x")!)
    browser.open(URL(string: "https://b.com/y")!)
    browser.select(browser.tabs[0])
    browser.save()

    let restarted = Browser(file: file)
    #expect(restarted.tabs.map(\.url.absoluteString) == ["https://a.com/x", "https://b.com/y"])
    #expect(restarted.selected?.url == URL(string: "https://a.com/x"))
    #expect(restarted.tabs[1].page.url == nil)
}

@Test func darkPagesTurnAWhitePageDark() async throws {
    let browser = Browser(file: tabsFile())
    let darkPages = browser.darkPages
    browser.darkPages = true
    defer { browser.darkPages = darkPages }
    browser.open(URL(string: "about:blank")!)
    let page = try #require(browser.selected).page
    for try await _ in page.load(html: "<p>Hello</p>") {}
    let background = try await page.callJavaScript("return getComputedStyle(document.documentElement).backgroundColor") as? String
    #expect(background == "rgb(24, 26, 27)")
}

@Test func switchingTabsClosesTheCommandBar() {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "https://a.com")!)
    browser.open(URL(string: "https://b.com")!)
    browser.showCommandBar(.currentTab)
    browser.select(offset: 1)
    #expect(browser.commandBar == nil)
    #expect(browser.selected?.url.host() == "a.com")
}

@Test(.timeLimit(.minutes(1))) func aPageCanAskToConfirm() async throws {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "about:blank")!)
    let page = try #require(browser.selected).page
    for try await _ in page.load(html: "<p>Hello</p>", baseURL: URL(string: "https://example.com/")!) {}
    async let answer = page.callJavaScript("return confirm('Leave?')") as? Bool
    while browser.dialog == nil { try await Task.sleep(for: .milliseconds(10)) }
    #expect(browser.dialog?.site == "example.com")
    #expect(browser.dialog?.message == "Leave?")
    browser.closeDialog(ok: true)
    #expect(try await answer == true)
}

@Test(.timeLimit(.minutes(1))) func aPagePromptGetsTheTypedText() async throws {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "about:blank")!)
    let page = try #require(browser.selected).page
    for try await _ in page.load(html: "<p>Hello</p>") {}
    async let answer = page.callJavaScript("return prompt('Name?', 'Ann')") as? String
    while browser.dialog == nil { try await Task.sleep(for: .milliseconds(10)) }
    #expect(browser.dialog?.text == "Ann")
    browser.dialog?.text = "Bo"
    browser.closeDialog(ok: true)
    #expect(try await answer == "Bo")
}

@Test(.timeLimit(.minutes(1))) func aSecondDialogIsCancelledWhileTheFirstIsOpen() async throws {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "about:blank")!)
    browser.open(URL(string: "about:blank")!)
    let first = browser.tabs[0].page, second = browser.tabs[1].page
    for try await _ in first.load(html: "<p>A</p>") {}
    for try await _ in second.load(html: "<p>B</p>") {}
    async let firstAnswer = first.callJavaScript("return confirm('First')") as? Bool
    while browser.dialog == nil { try await Task.sleep(for: .milliseconds(10)) }
    #expect(try await second.callJavaScript("return confirm('Second')") as? Bool == false)
    #expect(browser.dialog?.message == "First")
    browser.closeDialog(ok: true)
    #expect(try await firstAnswer == true)
}

private func shownAlert(in host: UIViewController, saying message: String) async throws -> UIAlertController {
    while true {
        if let alert = host.presentedViewController as? UIAlertController, alert.message == message, !alert.isBeingPresented { return alert }
        try await Task.sleep(for: .milliseconds(50))
    }
}

private func tap(_ title: String, in alert: UIAlertController) {
    alert.perform(NSSelectorFromString("_dismissWithAction:"), with: alert.actions.first { $0.title == title })
}

@Test(.timeLimit(.minutes(1))) func anAlertRightAfterAConfirmShows() async throws {
    let window = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow)
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "about:blank")!)
    let page = try #require(browser.selected).page
    for try await _ in page.load(html: "<p>Hello</p>") {}
    let host = UIHostingController(rootView: BrowserView(browser: browser))
    let previous = window.rootViewController
    window.rootViewController = host
    defer { window.rootViewController = previous }
    async let done = page.callJavaScript("return confirm('one') && (alert('two'), 'answered')") as? String
    defer { browser.closeDialog(ok: false) }
    tap("OK", in: try await shownAlert(in: host, saying: "one"))
    tap("OK", in: try await shownAlert(in: host, saying: "two"))
    #expect(try await done == "answered")
}

@Test(.timeLimit(.minutes(1))) func windowOpenOpensATab() async throws {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "about:blank")!)
    let page = try #require(browser.selected).page
    for try await _ in page.load(html: "<p>Hello</p>") {}
    _ = try await page.callJavaScript("window.open('https://b.com/x')")
    while browser.tabs.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
    #expect(browser.selected?.url == URL(string: "https://b.com/x"))
}

@Test(.timeLimit(.minutes(1))) func aDialogWhileTheFilePickerIsOpenIsCancelled() async throws {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "about:blank")!)
    let page = try #require(browser.selected).page
    for try await _ in page.load(html: "<p>Hello</p>") {}
    browser.fileRequest = FileRequest(multiple: false) { _ in }
    #expect(try await page.callJavaScript("return confirm('Leave?')") as? Bool == false)
    #expect(browser.dialog == nil)
}

@Test func darkPagesLeaveThePageOwnColorSchemeAlone() async throws {
    let window = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow)
    let browser = Browser(file: tabsFile())
    let darkPages = browser.darkPages
    browser.darkPages = true
    defer { browser.darkPages = darkPages }
    browser.open(URL(string: "about:blank")!)
    let page = try #require(browser.selected).page
    let host = UIHostingController(rootView: BrowserView(browser: browser))
    host.overrideUserInterfaceStyle = .light
    let previous = window.rootViewController
    window.rootViewController = host
    defer { window.rootViewController = previous }
    for try await _ in page.load(html: "<p>Hello</p>") {}
    try await Task.sleep(for: .milliseconds(500))
    #expect(try await page.callJavaScript("return matchMedia('(prefers-color-scheme: dark)').matches") as? Bool == false)
}
