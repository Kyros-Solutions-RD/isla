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

Isla registers the `isla://` URL scheme:

| URL | What it does |
| --- | --- |
| `isla://open/<tab>` | Opens the Nook on a tab (`home`, `shelf`, `clipboard`, `calendar`, `tasks`, `timers`, `notes`, `mirror`, `teleprompter`, `shortcuts`). Add `?screen=main` to target the built-in display. |
| `isla://close` | Closes every notch. |
| `isla://settings` | Opens Settings. |
| `isla://demo/<activity>` | **Debug only.** Shows a sample live activity: `charging`, `lowbattery`, `airpods`, `volume`, `brightness`, `caps`, `download`, `downloaded`, `meeting`, `timer`, `timerdone`, `shelf`, `track`. |
| `isla://demo/data` | **Debug only.** Fills every tab with sample content, handy for screenshots. |

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

Isla is published from a Mac to the project's cPanel server, with GitHub as the source of truth.

1. Save the cPanel API token once in `~/.config/isla/cpanel.env` (see `scripts/cpanel.env.example`).
2. First time only: `./scripts/setup-server.sh` creates `isla.kyrosrd.com`, requests SSL and connects cPanel Git to this repository.
3. Add a `## x.y.z` section to `CHANGELOG.md`, commit, then run:

   ```bash
   ./scripts/release.sh x.y.z
   ```

   The script builds a universal DMG, signs it for Sparkle with the key stored in your login Keychain (`generate_keys --account isla`), adds it to `website/updates/appcast.xml`, tags and pushes to GitHub, creates the GitHub Release, uploads the DMG to `isla.kyrosrd.com/downloads` and redeploys the website. Installed copies of Isla pick the update up within a day.

To publish only website changes: push to `main` and run `./scripts/deploy-site.sh`.
