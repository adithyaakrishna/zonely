<p align="center">
  <img src="Assets/ZonelyAppIcon.png" width="144" alt="Zonely app icon">
</p>

<h1 align="center">Zonely</h1>

<p align="center">A focused macOS menu-bar utility for finding humane meeting times across time zones.</p>

<p align="center">
  <a href="https://github.com/adithyaakrishna/zonely/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/adithyaakrishna/zonely/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/adithyaakrishna/zonely/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/adithyaakrishna/zonely?display_name=tag"></a>
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

Zonely turns the working day in each city into one compact timeline. Move the glass selector to compare local times instantly, reorder locations as your priorities change, or let Zonely find the nearest time that works for everyone.

## Features

- Lives entirely in the macOS menu bar.
- Shows working, edge, and off-hours across up to six time zones.
- Supports fractional UTC offsets such as India Standard Time.
- Searches any city worldwide, plus IANA identifiers, IATA airport codes, and common time-zone abbreviations.
- Resolves offsets from current IANA rules, including daylight-saving transitions.
- Drag-to-reorder timezone rows with a synchronized timeline preview.
- Finds the nearest meeting time with the best overlap.
- Persists timezone selections locally between launches.
- Includes native pointer, keyboard, and accessibility behavior.

## Install

Zonely requires macOS 14 or later.

1. Download the latest signed and notarized DMG from [Releases](https://github.com/adithyaakrishna/zonely/releases).
2. Open the DMG and drag **Zonely** into **Applications**.
3. Launch Zonely. Its full-color app icon appears in the menu bar.

Release downloads are universal binaries for Apple silicon and Intel Macs. SHA-256 checksum files are published beside every DMG and ZIP.

## Use

- Click the menu-bar icon to open or close Zonely.
- Drag horizontally across the timeline to change the selected UTC hour.
- Drag the six-dot handle beside a city to reorder it.
- Select **+** to add, remove, or search time zones. Zonely supports one to six locations.
- Select **Find best time** to jump to the strongest working-hours overlap.
- Right-click the menu-bar icon to reset the selected time or quit.

## Develop

The project is a native Swift Package Manager app with no third-party runtime dependencies.

```bash
git clone git@github.com:adithyaakrishna/zonely.git
cd zonely
swift test
./script/build_and_run.sh
```

Useful checks:

```bash
swift format lint --recursive --strict Sources Tests Package.swift
bash -n script/*.sh
swift test --parallel
```

Build a local universal DMG and ZIP:

```bash
VERSION=0.1.0 BUILD_NUMBER=1 ./script/build_distribution.sh
VERSION=0.1.0 ./script/verify_distribution.sh
```

Local distribution builds are ad-hoc signed. Public releases are Developer ID signed, notarized by Apple, stapled, Gatekeeper-verified, and published to GitHub Releases.

## Releases

Zonely has two local release channels behind one command:

```bash
./script/release.sh github 1.0.0
./script/release.sh app-store 1.0.0
```

Run the one-time interactive setup first:

```bash
./script/setup_release_credentials.sh all
```

The setup uses the Developer ID Application identity installed in the login Keychain, saves notarization credentials in a named macOS Keychain profile, checks GitHub CLI authentication, and records only non-secret settings in the ignored `.env` file. It does not require a base64 certificate or Apple password in the repository.

If `.env` still contains the old certificate or Apple password values from the runner workflow, remove those entries after the Keychain profile is working. Local releases do not use them.

Always rehearse each channel without publishing:

```bash
./script/release.sh github 1.0.0 --dry-run
./script/release.sh app-store 1.0.0 --dry-run
```

### GitHub release

The GitHub command runs lint and tests, builds a universal app, signs it with the local Developer ID certificate, notarizes and staples the app and DMG, verifies Gatekeeper acceptance, creates checksums and categorized release notes, creates and pushes the version tag, and publishes all artifacts with `gh`. A real release requires a clean Git worktree. Publishing locally does not start a release runner.

Prerequisites:

- A Developer ID Application certificate created in Xcode under **Settings > Accounts > Manage Certificates**.
- An authenticated GitHub CLI session from `gh auth login`.
- A working `Zonely-Notary` Keychain profile created by the setup script.

### Mac App Store release

The App Store command runs lint and tests, archives the checked-in `Zonely.xcodeproj` application target, applies App Sandbox and hardened runtime, uses Xcode automatic signing and provisioning, validates the archive, and uploads it to App Store Connect.

Before the first upload:

- Register the explicit app ID `com.adikris.Zonely` in the Apple Developer portal.
- Create the matching macOS app record in App Store Connect.
- Add the team Apple Account in **Xcode > Settings > Accounts**.
- Run `./script/setup_release_credentials.sh app-store` to save the Team ID locally.

After upload processing finishes, choose the build and complete screenshots, pricing, privacy, compliance, and **Submit for Review** in App Store Connect. These review decisions intentionally remain manual.

### Manual runner fallback

The GitHub Actions release workflow is available through **Actions > Release > Run workflow** as a fallback. It is manual-only, so tags created by a local release do not start a duplicate runner release.

Release Drafter maintains a categorized draft release whenever pull requests are merged into `main`. It labels pull requests from their title, branch, and changed files; chooses the next semantic version from those labels; and groups changes into features, fixes, accessibility, performance, documentation, dependencies, and maintenance.

The reusable Release Notes workflow remains available to regenerate notes manually with an existing `vX.Y.Z` tag when notes need to be refreshed from a runner.

Configure these repository secrets only if you want to use the manual runner fallback:

| Secret | Purpose |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded Developer ID Application `.p12` certificate |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_ID` | Apple ID used for notarization |
| `TEAM_ID` | Apple Developer Program Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for `notarytool` |

To encode the certificate on macOS:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

The CI workflow runs formatting checks, shell syntax validation, tests, and an unsigned universal distribution build for every pull request and every push to `main`. Dependabot checks GitHub Actions dependencies weekly.

## Privacy

Zonely has no analytics or accounts. Worldwide city searches use Apple's geocoding service; selected time zones are stored locally using macOS `UserDefaults`.

## License

Zonely is available under the [MIT License](LICENSE).
