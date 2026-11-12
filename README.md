# GitHub Touch Bar Pet

A native macOS pet that lives on your desktop and MacBook Pro Touch Bar and
grows with your GitHub contributions. Boo reads your contribution graph directly,
so there is nothing to set up in your profile: its level, mood, streak, today's
contributions, and yearly total stay live, and Boo nudges you when today's
square is still empty.

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
- Latest public GitHub activity and a daily report, all as Boo speech bubbles
- Streak reminders: if you haven't contributed yet today, Boo gets hungry and pops
  up on the desktop at 10:00, 15:00, 20:00, and 22:00 (each at most once a day)
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
restore or hide it. In the expanded bar, tap **‹ 👻** to collapse back to the
compact Control Strip Boo.

The app starts without a Dock icon. From the 👻 menu, choose **Show or hide
desktop Boo** to toggle the floating companion. The dashboard temporarily shows
the app in the Dock while it is open and hides it again when closed.

Press **Control–Option–B** from any application to show or hide desktop Boo. The
shortcut is registered system-wide and does not require Accessibility access.

Desktop Boo floats over other windows, can be dragged by its transparent window,
and shows timed message bubbles for new public GitHub activity. Clicking Boo
shows the latest activity message; clicking Boo again dismisses the bubble.

GitHub's public events API does not require login, but GitHub documents that its
events can lag by 30 seconds to six hours. Connecting GitHub lets Boo read your
unread notification inbox without marking messages as read.

## Streak reminders

Boo reads the same counts as the green squares on your profile. Without signing
in it uses the public profile graph; when GitHub is connected it uses the GraphQL
API, which also includes private contributions if your profile shows them. Days
follow GitHub's graph, and the streak isn't broken until today is over.

Boo's mood comes from the graph too: **Happy** once you've contributed today,
**Okay** in the morning after a day with contributions, **Hungry** when today is
still empty, and **Sick** after three or more empty days in a row. Level grows
with this year's total (20 contributions → Lv2, 80 → Lv3, 500 → Lv6).

If nothing has been contributed yet, Boo turns hungry and shows a reminder speech
bubble on the desktop, even if desktop Boo was hidden. The
reminders escalate through the day; after the Mac wakes, Boo shows only the
latest one that's due. Once a contribution lands, Boo thanks you for saving the
streak. Turn reminders off with **Remind me to keep my streak** in the 👻 menu.

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

To rename the pet:

```bash
defaults write dev.commitpet.touchbar petName Mochi
```

To check what Boo sees for a profile without launching the app:

```bash
swift run CommitPetTouchBar --print-stats YOUR_GITHUB_USERNAME
```

## Profile README card

`profile-card/` draws Boo's card for a profile README with exactly the same
rules as the desktop app. Add this workflow to your `<username>/<username>`
repository, replacing `YOUR_USERNAME` and the time zone:

```yaml
name: Boo
on:
  schedule:
    - cron: "7 * * * *"   # hourly
  workflow_dispatch:
permissions:
  contents: write
jobs:
  card:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Get the card generator
        run: git clone --depth 1 https://github.com/silviafeiwang/github-touchbar-pet.git "$RUNNER_TEMP/pet"
      - name: Render card
        env:
          GITHUB_TOKEN: ${{ github.token }}
        run: |
          node "$RUNNER_TEMP/pet/profile-card/generate.js" \
            --user YOUR_USERNAME --name Boo --species ghost \
            --tz America/Vancouver --out commit-pet.svg
      - name: Commit card if it changed
        run: |
          git add commit-pet.svg
          git diff --cached --quiet && exit 0
          git config user.name 'github-actions[bot]'
          git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
          git commit -m 'Update Boo 👻'
          git push
```

Then show it with `![Boo](commit-pet.svg)`. Preview locally with
`GITHUB_TOKEN=$(gh auth token) node profile-card/generate.js --user NAME --tz Area/City`.

## Roadmap

1. Scheduled morning/evening and weekly Boo reports
2. Launch-at-login and signed/notarized releases
3. Additional interactions and milestone animations

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.
