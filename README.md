# Commit Pet Touch Bar

A native macOS companion for Commit Pet. Boo reads the public `commit-pet.svg`
from a GitHub profile repository and mirrors its level, mood, streak, today's
contributions, and yearly total in a window and the MacBook Pro Touch Bar.

## Current milestone

- Native Swift/AppKit application
- Animated pixel ghost
- Public GitHub data source; no access token required
- Touch Bar scene using Apple's public `NSTouchBar` API
- Persistent Boo logo in the Control Strip using dynamically resolved private APIs
- Menu-bar controls and 15-minute refresh
- Top repository today and this week from public GitHub events
- Latest public GitHub activity and daily macOS notifications
- Local cached state for offline launches
- Terminal build that produces a clickable `.app`

The standard Touch Bar scene appears while Commit Pet is frontmost. The compact
Boo logo uses undocumented macOS APIs so it can remain in the Control Strip when
other applications are active. This persistent mode is intended for personal use:
Apple can change or remove those APIs in a future macOS release, and an app using
them is not suitable for the Mac App Store.

Tap the persistent Boo logo to open the full bar. Use the 👻 menu-bar menu to
restore or hide it.

GitHub's public events API does not require login, but GitHub documents that its
events can lag by 30 seconds to six hours. Private activity, the notification
inbox, and personalized repository news will require GitHub authentication in a
future milestone.

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

1. GitHub OAuth/device flow for private activity and notification-inbox news
2. Scheduled morning/evening and weekly Boo reports
3. Transparent desktop pet window
4. Launch-at-login and signed/notarized releases
5. Additional interactions and milestone animations

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.
