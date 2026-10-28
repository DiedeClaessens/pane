<img src="assets/icon.svg" width="64" height="64" alt="">

# Pane

A personal iPad browser with nothing on screen but the page, like Zen's compact mode. Swipe in from the left edge for the tabs, and swipe right or left anywhere to go back or forward. See [docs/design.md](docs/design.md) for what it does.

> [!WARNING]
> Pane is a personal project I put together for fun, because I wanted a browser that works exactly the way I like. It is not on the App Store and never will be. It gets no security fixes or regular updates, so I don't recommend using it as your browser. Read the code or borrow ideas from it if you like.

## Run it on your iPad

You need a Mac with Xcode 27 and an iPad on iPadOS 27 or later.

1. Connect the iPad with a cable and open `Pane.xcodeproj` in Xcode.
2. On the iPad, turn on Settings > Privacy & Security > Developer Mode (it appears after the first connection) and restart.
3. Pick the iPad as the run destination and press Run. Signing uses your free Personal Team.
4. The first time, trust the developer on the iPad: Settings > General > VPN & Device Management.

With a free Apple ID the app stops opening after 7 days. Press Run again to reinstall it. Your tabs and logins stay.

## Open links from other apps in Pane

Pane cannot be the default browser. To send a link to it, AirDrop `shortcuts/Open in Pane.shortcut` to the iPad, or open it on a Mac signed in to the same iCloud account, and add it to Shortcuts. Check that "Show in Share Sheet" is on in its details. Then share a link from any app and pick "Open in Pane".

To build the shortcut by hand instead, make a shortcut that receives URLs from the share sheet, with two actions: Text with `pane:` followed by the Shortcut Input, then Open URLs with that Text.

## Automatic reinstall

`scripts/reinstall-ipad.sh` rebuilds Pane and reinstalls it on the iPad, so the 7-day signature never runs out. When Pane's signing profile has less than two days left, the script removes it so Xcode fetches a new one. A launch agent runs the script every day at 13:10, or when the Mac wakes up if it was asleep then. It needs the Mac logged in, and the iPad on the cable or on the same Wi-Fi. The log is in `~/Library/Logs/pane-reinstall.log`.

Turn it on:

```sh
cp scripts/com.diedeclaessens.pane.reinstall.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.diedeclaessens.pane.reinstall.plist
```

Run it now with `launchctl kickstart gui/$(id -u)/com.diedeclaessens.pane.reinstall`. Turn it off with `launchctl bootout gui/$(id -u)/com.diedeclaessens.pane.reinstall`.

## Tests

```sh
xcodebuild test -project Pane.xcodeproj -scheme Pane -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)'
```
