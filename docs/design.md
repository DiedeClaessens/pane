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
- The sidebar hides when you tap the page or pick a tab.
- While the sidebar is open, a swipe left closes it.

## Back and forward

- A quick swipe right anywhere on the page goes back. A swipe left goes forward. Swipes that start at the left edge open the sidebar instead.
- The swipe runs alongside the page's own scrolling, so a quick horizontal swipe on a carousel or a map also goes back or forward.
- The sidebar buttons, Cmd+[ and Cmd+] also go back and forward.

## Dark pages

- The moon button at the top of the sidebar turns every page dark with Dark Reader's dynamic theme, the same engine as the Dark Reader extension. Turning it on or off reloads the open pages, so every frame on them changes, and it applies to every page that loads after. The sidebar and command bar turn dark with it. Pages keep the system's color scheme, so a site does not switch to its own dark theme and then get darkened again by Dark Reader. The setting is kept across launches.
- `Pane/darkreader.js` is version 4.9.133 of the `darkreader` npm package (MIT, license in `docs/darkreader-LICENSE`). Pane injects it into every frame at document start, in its own script world so pages cannot see it.
- There are no per-site exceptions or brightness and contrast settings yet.

## Command bar

- A floating field near the top. Cmd+T opens it for a new tab. Cmd+L, or tapping the host in the sidebar, opens it for the current tab with the address selected.
- Text that starts with `http://` or `https://`, in any case, opens as typed. Text with a dot and no spaces opens over HTTPS. Anything else is a search with the engine picked at the bottom of the sidebar: Google (the default), DuckDuckGo, Kagi, Brave Search, Startpage, Ecosia or Bing. The field's placeholder names the engine.
- Escape or a tap outside closes it.

## Tabs

- New tabs open right after the current tab and become the current tab.
- Links that open a new window (`target="_blank"`, `window.open`) open in a new tab. WebPage cannot create windows, so a small script turns `window.open` into a new-window link. The page gets no handle to the new tab, so sign-in popups that talk back to the page that opened them do not work.
- A new tab is a page of its own. When a tapped link in a frame opens one, that tab may open another app like any page.
- Closing the current tab selects the next one, or the previous one when it was the last.
- Open tabs and the current tab are saved when the app leaves the foreground and restored on launch. Restored tabs only load when you open them.

## Page dialogs and links

- A page's `alert`, `confirm` and `prompt` show as a system alert titled with the host of the page or frame that asks. A dialog that comes while another dialog or the Files picker is open is cancelled, so the alert on screen is always the one being answered.
- A file field opens the Files picker. Pane copies the picked files to its temporary folder and gives the page the copies. There is no separate photo library or camera option.
- Links that WebKit cannot load, such as `mailto:` and `tel:`, open in their own app when the page itself asks for it. A frame inside the page, such as an ad, cannot switch apps, even through a link tapped inside it.
- A page that asks for the camera or microphone gets the system permission prompt.

## Opening links from other apps

- Pane cannot be the default browser, because Apple only grants that entitlement to published browsers. Tapping a link in another app still opens the default browser.
- Instead, the "Open in Pane" shortcut (`shortcuts/Open in Pane.shortcut`) sits in the share sheet. It takes the shared link, puts `pane:` in front of it, and opens that. Pane opens the address in a new tab.
- The format is `pane:https://...` without `//` after `pane:`. With `pane://https://...`, iPadOS reads `https` as the host and rewrites the rest of the address.

## Keyboard

Cmd+T new tab, Cmd+L open location, Cmd+W close tab, Cmd+S sidebar, Cmd+[ back, Cmd+] forward, Cmd+R reload, Ctrl+Tab and Ctrl+Shift+Tab next and previous tab.

## Out of scope for now

- Workspaces, pinned tabs ("Essentials"), split view, bookmarks, history, downloads, content blocking, "Open in New Tab" in the long-press menu, and being the default browser (Apple only grants that entitlement to published browsers).
