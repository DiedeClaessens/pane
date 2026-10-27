import Foundation
import Testing
@testable import Pane

private func tabsFile() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)/tabs.json")
}

@Test func anAddressWithoutSchemeOpensOverHTTPS() {
    #expect(Browser.destination(for: " example.com/docs ") == URL(string: "https://example.com/docs"))
}

@Test func anAddressWithSchemeOpensAsTyped() {
    #expect(Browser.destination(for: "http://localhost:4000/a") == URL(string: "http://localhost:4000/a"))
}

@Test func wordsSearchGoogle() {
    #expect(Browser.destination(for: "swift.org release notes") == URL(string: "https://www.google.com/search?q=swift.org%20release%20notes"))
    #expect(Browser.destination(for: "weather") == URL(string: "https://www.google.com/search?q=weather"))
}

@Test func blankInputGoesNowhere() {
    #expect(Browser.destination(for: "   ") == nil)
}

@Test func linksOpenNextToTheCurrentTab() {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "https://a.com")!)
    browser.open(URL(string: "https://c.com")!)
    browser.select(browser.tabs[0])
    browser.open(URL(string: "https://b.com")!)
    #expect(browser.tabs.map { $0.url?.host() } == ["a.com", "b.com", "c.com"])
    #expect(browser.selected?.url?.host() == "b.com")
}

@Test func closingTheSelectedTabSelectsTheNextOne() {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "https://a.com")!)
    browser.open(URL(string: "https://b.com")!)
    browser.open(URL(string: "https://c.com")!)
    browser.select(browser.tabs[1])
    browser.close(browser.tabs[1])
    #expect(browser.selected?.url?.host() == "c.com")
    browser.close(browser.tabs[1])
    #expect(browser.selected?.url?.host() == "a.com")
}

@Test func nextTabWrapsAround() {
    let browser = Browser(file: tabsFile())
    browser.open(URL(string: "https://a.com")!)
    browser.open(URL(string: "https://b.com")!)
    browser.select(offset: 1)
    #expect(browser.selected?.url?.host() == "a.com")
    browser.select(offset: -1)
    #expect(browser.selected?.url?.host() == "b.com")
}

@Test func tabsComeBackAfterARestart() {
    let file = tabsFile()
    let browser = Browser(file: file)
    browser.open(URL(string: "https://a.com/x")!)
    browser.open(URL(string: "https://b.com/y")!)
    browser.select(browser.tabs[0])
    browser.save()

    let restarted = Browser(file: file)
    #expect(restarted.tabs.map(\.url) == [URL(string: "https://a.com/x"), URL(string: "https://b.com/y")])
    #expect(restarted.selected?.url == URL(string: "https://a.com/x"))
}
