# Commit Pet Touch Bar

A native macOS companion for Commit Pet. Boo reads the public `commit-pet.svg`
from a GitHub profile repository and mirrors its level, mood, streak, today's
contributions, and yearly total in a window and the MacBook Pro Touch Bar.

## Current milestone

- Native Swift/AppKit application
- Animated pixel ghost
- Public GitHub activity without login, plus optional GitHub device authentication
- Touch Bar scene using Apple's public `NSTouchBar` API
- Persistent Boo logo in the Control Strip using dynamically resolved private APIs
- Menu-bar-only launch with no Dock icon by default
- Transparent, draggable desktop Boo available across Spaces
- Speech bubbles for recent GitHub activity
- Menu-bar controls and 15-minute refresh
- Top repository today and this week from public GitHub events
- Latest public GitHub activity and daily macOS notifications
- Authenticated unread notifications for mentions, comments, reviews, and assignments
- OAuth token stored in macOS Keychain
- Local cached state for offline launches
- Terminal build that produces a clickable `.app`

The standard Touch Bar scene appears while Commit Pet is frontmost. The compact
Boo logo uses undocumented macOS APIs so it can remain in the Control Strip when
other applications are active. This persistent mode is intended for personal use:
Apple can change or remove those APIs in a future macOS release, and an app using
them is not suitable for the Mac App Store.

Tap the persistent Boo logo to open the full bar. Use the 👻 menu-bar menu to
restore or hide it.

The app starts without a Dock icon. From the 👻 menu, choose **Show or hide
desktop Boo** to toggle the floating companion. The dashboard temporarily shows
the app in the Dock while it is open and hides it again when closed.

Desktop Boo floats over other windows, can be dragged by its transparent window,
and shows timed message bubbles for new public GitHub activity. Clicking Boo
replays the latest activity message.

GitHub's public events API does not require login, but GitHub documents that its
events can lag by 30 seconds to six hours. Connecting GitHub lets Boo read your
unread notification inbox without marking messages as read.

## Connect GitHub

GitHub's device flow requires a public OAuth App Client ID. This is a one-time
setup; a client secret is not required or stored.

1. Choose **Connect GitHub…** from the 👻 menu.
2. Choose **Create OAuth App**.
3. Enter any valid homepage and callback URL, such as https://github.com.
4. On the new OAuth App's settings page, enable **Device Flow**.
5. Paste the Client ID into Commit Pet.
6. Boo copies a short code and opens GitHub for approval.

Commit Pet requests only **notifications** and **read:user**. It does not request
the broad **repo** scope, so it cannot read private repository contents. The OAuth
access token is stored in macOS Keychain and can be removed with **GitHub:
@username ✓** → **Disconnect**.

## Touch Bar troubleshooting

1. Open System Settings → Keyboard → Touch Bar Settings.
2. Set **Touch Bar shows** to **App Controls** or **App Controls with Control Strip**.
3. Bring the Commit Pet window to the front.
4. From the 👻 menu-bar menu, choose **Reinstall Touch Bar Boo**.

The app provides its Touch Bar directly from the key window, so it does not
depend on a text field or other view becoming first responder.

## Build and run

```bash
./Scripts/check.sh
./Scripts/build-app.sh
open "Build/Commit Pet.app"
```

The app defaults to the `silviafeiwang` GitHub profile. To use another profile:

```bash
defaults write dev.commitpet.touchbar githubUsername YOUR_GITHUB_USERNAME
```

The profile repository must contain `commit-pet.svg` on its `main` branch.

## Roadmap

1. Scheduled morning/evening and weekly Boo reports
2. Launch-at-login and signed/notarized releases
3. Additional interactions and milestone animations

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.
