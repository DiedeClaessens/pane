import SwiftUI
import WebKit

/// The page fills the screen. Swipe in from the left edge, or move the pointer there, to show the sidebar.
struct BrowserView: View {
    let browser: Browser
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)
            if let tab = browser.selected {
                WebView(tab.page)
                    .webViewBackForwardNavigationGestures(.disabled)
                    .webViewElementFullscreenBehavior(.enabled)
                    .id(tab.id)
                if tab.page.isLoading {
                    ProgressView(value: tab.page.estimatedProgress)
                        .progressViewStyle(.linear)
                }
            }
            Color.clear
                .frame(width: 12)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 10).onChanged { drag in
                    if drag.translation.width > 20 { browser.showsSidebar = true }
                })
                .onHover { if $0 { browser.showsSidebar = true } }
            if browser.showsSidebar {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { browser.showsSidebar = false }
                Sidebar(browser: browser)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .overlay {
            if let mode = browser.commandBar ?? (browser.tabs.isEmpty ? .newTab : nil) {
                CommandBarView(browser: browser, mode: mode)
            }
        }
        .animation(.snappy(duration: 0.25), value: browser.showsSidebar)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) {
            if scenePhase != .active { browser.save() }
        }
    }
}

private struct Sidebar: View {
    let browser: Browser

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                Button("Back", systemImage: "chevron.left") { browser.goBack() }
                Button("Forward", systemImage: "chevron.right") { browser.goForward() }
                Button("Reload", systemImage: "arrow.clockwise") { browser.selected?.page.reload() }
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .padding(.horizontal, 8)

            Button { browser.showCommandBar(.currentTab) } label: {
                Text(browser.selected?.url?.host() ?? "Search or enter address")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary, in: .rect(cornerRadius: 10))
            }
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(browser.tabs) { tab in
                        TabRow(browser: browser, tab: tab)
                    }
                }
            }

            Button("New Tab", systemImage: "plus") { browser.showCommandBar(.newTab) }
                .padding(.horizontal, 8)
        }
        .padding(12)
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(8)
        .tint(.primary)
        .onHover { if !$0 { browser.showsSidebar = false } }
    }
}

private struct TabRow: View {
    let browser: Browser
    let tab: Tab

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: tab.url?.host().flatMap { URL(string: "https://\($0)/favicon.ico") }) { image in
                image.resizable()
            } placeholder: {
                Image(systemName: "globe").foregroundStyle(.secondary)
            }
            .frame(width: 16, height: 16)
            Text(tab.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Close", systemImage: "xmark") { browser.close(tab) }
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(tab.id == browser.selectedID ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
        .contentShape(.rect)
        .onTapGesture {
            browser.select(tab)
            browser.showsSidebar = false
        }
    }
}

private struct CommandBarView: View {
    let browser: Browser
    let mode: Browser.CommandBar
    @State private var text: String
    @State private var selection: TextSelection?
    @FocusState private var focused: Bool

    init(browser: Browser, mode: Browser.CommandBar) {
        self.browser = browser
        self.mode = mode
        let text = mode == .currentTab ? browser.selected?.url?.absoluteString ?? "" : ""
        _text = State(initialValue: text)
        _selection = State(initialValue: TextSelection(range: text.startIndex..<text.endIndex))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { browser.commandBar = nil }
            TextField("Search or enter address", text: $text, selection: $selection)
                .font(.title3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .focused($focused)
                .onSubmit { browser.go(to: text, in: mode) }
                .onKeyPress(.escape) {
                    browser.commandBar = nil
                    return .handled
                }
                .padding(18)
                .frame(maxWidth: 640)
                .glassEffect(in: .rect(cornerRadius: 20))
                .padding(.top, 120)
                .padding(.horizontal, 24)
        }
        .onAppear { focused = true }
    }
}
