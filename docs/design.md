# Pane design

Pane is a personal iPad browser in the style of Zen's compact mode: the page fills the whole screen and there is no address bar or tab strip. It is built for one person and is not published on the App Store.

## Platform

- Native Swift app (SwiftUI and the SwiftUI `WebView` with `WebPage`) for iPadOS 27. Every iPad browser uses WebKit, so pages render like in Safari.
- Installed from Xcode with a free Apple ID, and reinstalled every day by a launch agent, the same way as Slate.
- No sync. Cookies and logins persist in the app's own website data store.

## Screen

- The page fills the screen, under the status bar and home indicator, which are hidden.
- A thin progress line runs along the top while a page loads.
- With no tabs open, the command bar is shown and cannot be dismissed.

## Sidebar

- Swipe in from the left edge, or move the pointer to the left edge, to show it. Cmd+S toggles it.
- It holds back, forward and reload, the current host (tap it to edit the address), the tabs in a vertical list with favicons, and "New Tab".
- Tap a tab to switch to it. The cross closes it.
- The sidebar hides when you tap the page, pick a tab, or move the pointer out of it.
- The left edge opens the sidebar, so the swipe-back gesture is off. Go back with the sidebar button or Cmd+[.

## Command bar

- A floating field near the top. Cmd+T opens it for a new tab. Cmd+L, or tapping the host in the sidebar, opens it for the current tab with the address selected.
- Text that starts with `http://` or `https://` opens as typed. Text with a dot and no spaces opens over HTTPS. Anything else is a Google search.
- Escape or a tap outside closes it.

## Tabs

- New tabs open right after the current tab and become the current tab.
- Links that open a new window (`target="_blank"`, `window.open`) open in a new tab.
- Closing the current tab selects the next one, or the previous one when it was the last.
- Open tabs and the current tab are saved when the app leaves the foreground and restored on launch. Restored tabs only load when you open them.

## Keyboard

Cmd+T new tab, Cmd+L open location, Cmd+W close tab, Cmd+S sidebar, Cmd+[ back, Cmd+] forward, Cmd+R reload, Ctrl+Tab and Ctrl+Shift+Tab next and previous tab.

## Out of scope for now

- Workspaces, pinned tabs ("Essentials"), split view, bookmarks, history, downloads, content blocking, a choice of search engine, "Open in New Tab" in the long-press menu, and being the default browser (Apple only grants that entitlement to published browsers).
