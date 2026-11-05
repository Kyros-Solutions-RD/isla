# Contributing to Isla

Thanks for helping make Isla better. ¡Gracias por contribuir!

## Getting set up

1. Install Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. Clone the repository and generate the project:

   ```bash
   git clone https://github.com/Kyros-Solutions-RD/isla.git
   cd isla
   xcodegen generate
   open Isla.xcodeproj
   ```

3. Run the **Isla** scheme. The first time, Xcode asks you to trust the SwiftTerm build plugin; choose **Trust & Enable**. On the command line pass `-skipPackagePluginValidation`. The project is defined in `project.yml`; edit that file rather than the generated `.xcodeproj`, then run `xcodegen generate` again.

## Handy tools in Debug builds

Debug builds have their own identity, so testing never touches an installed Isla: bundle identifier `com.kyrossolutions.isla.dev`, URL scheme `isla-dev://`, and their own settings and data folder (`~/Library/Application Support/Isla Dev`). Quit the installed Isla while testing, or both draw a notch.

Launch with `--env ISLA_TEST=1` (for example `open -n -a Isla.app --env ISLA_TEST=1`) to skip the welcome tour and every service that could ask for a permission. `--env ISLA_AGENTS_REPORT=1 --stdout <file>` prints the agents, AI apps and local models Isla finds, then quits.

Isla registers the `isla://` URL scheme (`isla-dev://` in Debug builds):

| URL | What it does |
| --- | --- |
| `isla://open/<tab>` | Opens the Nook on a tab (`home`, `agents`, `shelf`, `clipboard`, `calendar`, `tasks`, `timers`, `notes`, `mirror`, `teleprompter`, `shortcuts`, `terminal`). Add `?screen=main` to target the built-in display. |
| `isla://close` | Closes every notch. |
| `isla://settings[/<pane>]` | Opens Settings, optionally on a pane (`general`, `appearance`, `nook`, `activities`, `agents`, `media`, `shelf`, `clipboard`, `calendar`, `focus`, `keyboard`, `permissions`, `about`). |
| `isla-dev://demo/<activity>` | **Debug only.** Shows a sample live activity: `charging`, `lowbattery`, `airpods`, `volume`, `brightness`, `caps`, `download`, `downloaded`, `meeting`, `timer`, `timerdone`, `shelf`, `track`, `agent-done`, `agent-needs`. `agents-empty` / `agents-live` preview the AI tab's empty state. |
| `isla-dev://demo/data` | **Debug only.** Fills every tab with sample content, handy for screenshots. |

## Guidelines

- **Feel native.** Use system materials (Liquid Glass), SF Symbols, the shared styles in `Support/DesignSystem.swift` and the motion curves in `IslaMotion`.
- **Ask for permissions lazily.** A feature should request access only when the user turns it on, and work gracefully without it.
- **Keep data local.** Do not add analytics or send user content anywhere. Network calls must be essential to a feature and documented in the README.
- **Localize.** User-facing strings go through `LocalizedStringKey` or `String(localized:)`. Add the Spanish translation in `Isla/Resources/Localizable.xcstrings`.
- **Stay warning free.** The project builds with zero warnings; please keep it that way.

## Pull requests

1. Create a branch from `main`.
2. Keep each pull request focused on one change and describe what it does and how you tested it.
3. Include a screenshot or short recording for visual changes.

## Reporting bugs

Open an [issue](https://github.com/Kyros-Solutions-RD/isla/issues) with your macOS version, Mac model, whether the display has a notch, and the steps to reproduce.

## Releasing (maintainers)

GitHub is the source of truth; the website and the Sparkle feed are served from the project's cPanel server at **isla.kyrosrd.com**.

**Server (one-time):** in cPanel create the subdomain `isla.kyrosrd.com` (document root `isla.kyrosrd.com`) and add this cron job every 10 minutes:

```
/bin/bash -c 'export PATH=/usr/local/cpanel/3rdparty/bin:/usr/local/bin:/usr/bin:/bin; [ -d "$HOME/repositories/isla" ] || git clone -q https://github.com/Kyros-Solutions-RD/isla.git "$HOME/repositories/isla"; /bin/bash "$HOME/repositories/isla/scripts/server/sync.sh"' >> "$HOME/isla-sync.log" 2>&1
```

`scripts/server/sync.sh` pulls `main`, mirrors every DMG referenced by the appcast from GitHub Releases into `/downloads`, and then deploys `website/`. No API tokens are involved.

**New version:** add a `## x.y.z — YYYY-MM-DD` section to `CHANGELOG.md` and its Spanish twin to `CHANGELOG.es.md` (an image line such as `![Alt text](website/assets/app/shot.jpg)` is shown on the website and on GitHub, not in the update window), commit, then run:

```bash
./scripts/release.sh x.y.z
```

It builds a universal DMG, signs it for Sparkle with the key in your login Keychain (`generate_keys --account isla`), adds it to `website/updates/appcast.xml`, regenerates the changelog page `website/novedades/` (`scripts/lib/changelog_page.py`), tags, creates the GitHub Release with the DMG and pushes. Within about ten minutes the server mirrors the DMG and publishes the appcast; installed copies of Isla update within a day.

**Signed and notarized builds (Developer ID):** community builds are signed ad hoc, so macOS asks people to confirm the first launch. With an Apple Developer Program membership:

1. In Xcode › Settings › Accounts, add the account and create a **Developer ID Application** certificate (Manage Certificates › +).
2. Store notarization credentials in the Keychain once (you type your Apple ID and an app-specific password yourself):

   ```bash
   xcrun notarytool store-credentials isla-notary --apple-id you@example.com --team-id TEAMID
   ```

3. Release with:

   ```bash
   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ISLA_TEAM_ID=TEAMID NOTARY_PROFILE=isla-notary ./scripts/release.sh x.y.z
   ```

The app then keeps the hardened runtime, the disk image is signed, notarized and stapled, and Gatekeeper opens it without warnings. Moving from ad-hoc to Developer ID changes the app's identity once, so macOS asks for its permissions one more time.

**Permissions check:** `ISLA_PERMISSION_REPORT=1 /Applications/Isla.app/Contents/MacOS/Isla` prints which permissions a build has, without asking for any.

**Website only:** push to `main`; the server deploys it on its next run.

**Installer design:** `scripts/package-dmg.sh` builds the disk image window: the painted artwork, Isla on the left, the Applications link on the right and the app icon as the volume icon. Finder lays it out through AppleScript, so the first run asks once for permission to control Finder. To change the artwork or the text, edit `design/dmg/artwork.png` or `scripts/lib/dmg-background.swift`, then run:

```bash
swift scripts/lib/dmg-background.swift design/dmg/artwork.png design/dmg
```

`design/dmg/preview.png` shows the result. Icon positions in `package-dmg.sh` must match the ones in `dmg-background.swift`.
