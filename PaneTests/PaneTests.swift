import Foundation
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
