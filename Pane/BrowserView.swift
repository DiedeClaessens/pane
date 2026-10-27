import SwiftUI
import WebKit

/// The page fills the screen. Swipe in from the left edge, or move the pointer there, to show the sidebar.
/// Swipe right or left anywhere else to go back or forward.
struct BrowserView: View {
    let browser: Browser
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    /// Dark pages darken the sidebar and command bar, but not the page's own color scheme, which Dark Reader handles.
    private var chromeScheme: ColorScheme { browser.darkPages ? .dark : colorScheme }

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
                    .environment(\.colorScheme, chromeScheme)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .gesture(Swipe(direction: .right) {
            if !browser.showsSidebar { browser.goBack() }
        })
        .gesture(Swipe(direction: .left) {
            if browser.showsSidebar { browser.showsSidebar = false } else { browser.goForward() }
        })
        .overlay {
            if let mode = browser.commandBar ?? (browser.tabs.isEmpty ? .newTab : nil) {
                CommandBarView(browser: browser, mode: mode)
                    .environment(\.colorScheme, chromeScheme)
                    .id(mode)
            }
        }
        .animation(.snappy(duration: 0.25), value: browser.showsSidebar)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) {
            if scenePhase != .active { browser.save() }
        }
        .background {
            Color.clear
                .alert(browser.dialog?.site ?? "", isPresented: .constant(browser.dialog != nil)) {
                    if browser.dialog?.kind == .prompt {
                        TextField("", text: Binding(get: { browser.dialog?.text ?? "" }, set: { browser.dialog?.text = $0 }))
                    }
                    if browser.dialog?.kind != .alert {
                        Button("Cancel", role: .cancel) { browser.closeDialog(ok: false) }
                    }
                    Button("OK") { browser.closeDialog(ok: true) }
                } message: {
                    Text(browser.dialog?.message ?? "")
                }
                .id(browser.dialog?.id)
        }
        .fileImporter(
            isPresented: .constant(browser.fileRequest != nil),
            allowedContentTypes: [.item],
            allowsMultipleSelection: browser.fileRequest?.multiple ?? false,
            onCompletion: { browser.closeFileRequest(try? $0.get().map(copyToTemporary)) },
            onCancellation: { browser.closeFileRequest(nil) }
        )
    }
}

/// Picked files are only readable while Pane holds access to them, so the page gets a copy.
private func copyToTemporary(_ file: URL) throws -> URL {
    let access = file.startAccessingSecurityScopedResource()
    defer { if access { file.stopAccessingSecurityScopedResource() } }
    let copy = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: file.lastPathComponent)
    try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: file, to: copy)
    return copy
}

/// A quick horizontal swipe anywhere but the left edge, which opens the sidebar.
/// It runs alongside the page's own scrolling and taps instead of blocking them.
private struct Swipe: UIGestureRecognizerRepresentable {
    let direction: UISwipeGestureRecognizer.Direction
    let action: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UISwipeGestureRecognizer {
        let swipe = UISwipeGestureRecognizer()
        swipe.direction = direction
        swipe.delegate = context.coordinator
        return swipe
    }

    func handleUIGestureRecognizerAction(_ recognizer: UISwipeGestureRecognizer, context: Context) {
        if recognizer.state == .ended { action() }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            touch.location(in: gestureRecognizer.view).x > 24
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
                Spacer()
                Toggle("Dark Pages", systemImage: "moon", isOn: Bindable(browser).darkPages)
                    .toggleStyle(.button)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .padding(.horizontal, 8)

            Button { browser.showCommandBar(.currentTab) } label: {
                Text(browser.selected?.url.host() ?? "Search or enter address")
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

            HStack {
                Button("New Tab", systemImage: "plus") { browser.showCommandBar(.newTab) }
                Spacer()
                Picker("Search with", systemImage: "magnifyingglass", selection: Bindable(browser).searchEngine) {
                    ForEach(SearchEngine.allCases) { Text($0.rawValue) }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(8)
        .tint(.primary)
    }
}

private struct TabRow: View {
    let browser: Browser
    let tab: Tab

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: tab.url.host().flatMap { URL(string: "https://\($0)/favicon.ico") }) { image in
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
        let text = mode == .currentTab ? browser.selected?.url.absoluteString ?? "" : ""
        _text = State(initialValue: text)
        _selection = State(initialValue: TextSelection(range: text.startIndex..<text.endIndex))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { browser.commandBar = nil }
            TextField("Search \(browser.searchEngine.rawValue) or enter address", text: $text, selection: $selection)
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
