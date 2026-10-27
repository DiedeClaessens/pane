<img src="assets/icon.svg" width="64" height="64" alt="">

# Pane

A personal iPad browser with nothing on screen but the page, like Zen's compact mode. Swipe in from the left edge for the tabs. See [docs/design.md](docs/design.md) for what it does.

## Run it on your iPad

1. Connect the iPad with a cable and open `Pane.xcodeproj` in Xcode.
2. On the iPad, turn on Settings > Privacy & Security > Developer Mode (it appears after the first connection) and restart.
3. Pick the iPad as the run destination and press Run. Signing uses your free Personal Team.
4. The first time, trust the developer on the iPad: Settings > General > VPN & Device Management.

With a free Apple ID the app stops opening after 7 days. Press Run again to reinstall it. Your tabs and logins stay.

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
