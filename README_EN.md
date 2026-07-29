# Quota for Codex

[中文说明](README.md) · [License](LICENSE)

Quota for Codex is a native macOS 14+ menu bar app and WidgetKit extension that shows your remaining Codex quota and seven-day token usage.

> This is an independent third-party open-source project and is not affiliated with OpenAI.

## Features

- Small widget with five-hour and weekly quota windows.
- Medium widget with quota information and a seven-day usage chart.
- Menu bar status, manual refresh, connection diagnostics, and settings.
- Automatic Codex executable discovery with a manual path override.
- Optional launch at login.
- Local-only snapshot storage. The app never reads or stores Codex credentials.

Some accounts may expose only one quota window. Missing data is shown as unavailable instead of a false 100%.

## Requirements

- macOS 14 Sonoma or later.
- A signed-in ChatGPT/Codex desktop app or Codex CLI.
- Full Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) when building from source.

There is no notarized public DMG yet, so the current installation method builds the app locally.

## Install from source

```bash
git clone https://github.com/yuanjuju/QuotaForCodex.git
cd QuotaForCodex
brew install xcodegen
./scripts/install-local.sh
```

Before running the installer, open Xcode and sign in under `Settings -> Accounts`. The script installs the app to:

```text
~/Applications/Quota for Codex.app
```

If team detection fails, provide it explicitly:

```bash
APPLE_TEAM_ID='YOUR_TEAM_ID' ./scripts/install-local.sh
```

If Apple reports that the bundle identifier is unavailable, configure a unique reverse-DNS prefix:

```bash
./scripts/configure-identifiers.sh com.yourname
./scripts/install-local.sh
```

After installation, right-click the desktop, choose **Edit Widgets**, search for **Quota for Codex**, and add the small or medium widget. Enable **Launch at Login** in settings for continued updates.

Widget refresh timing is ultimately controlled by macOS. Menu bar data normally updates sooner than the desktop widget.

## How it works

The menu bar app starts the locally installed:

```text
codex app-server --listen stdio://
```

It initializes a JSON-RPC session and reads:

- `account/rateLimits/read`
- `account/usage/read`

The resulting snapshot is written atomically to a local App Group container. The widget only reads this snapshot; it does not start Codex or access authentication credentials.

## Development

Generate the Xcode project and run the complete test suite:

```bash
./scripts/bootstrap.sh
```

Run only the Swift package tests:

```bash
swift test
```

Run a read-only probe against the currently signed-in Codex account:

```bash
swift run QuotaProbe
```

Run the account-independent smoke test:

```bash
swift run QuotaSmoke
```

`project.yml` is the source of truth for the generated Xcode project. See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes.

## Privacy

Quota snapshots remain on the current Mac. The app does not read `~/.codex/auth.json`, store API keys, or use a hosted backend.

## Known limitations

- Widget refreshes are scheduled by macOS and are not real-time.
- Future Codex app-server protocol changes may require compatibility updates.
- Model-specific quota buckets are not displayed.
- macOS only; no iPhone/iPad app, cloud sync, notifications, or auto-updater.

## License

[MIT](LICENSE)
