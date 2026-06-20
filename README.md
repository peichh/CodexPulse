# CodexPulse

**CodexPulse** is a lightweight macOS menu bar app for OpenAI Codex usage.

It reads local Codex session logs, shows the current rate-limit window in the menu bar, and opens a compact dashboard with token totals, estimated limits, reset countdowns, and model usage.

Built with Codex.

## Features

- Menu bar title: `use xx% | hh:mm`
- Real-time reset countdown without constantly re-parsing logs
- Efficient 5-second log refresh with file metadata caching
- 5h and weekly usage windows from Codex `rate_limits`
- Estimated token limit and estimated tokens left
- Today and all-time token totals
- Usage by model
- Launch-at-login via LaunchAgent
- Menu bar only, no Dock icon

## Requirements

- macOS 14 or newer
- Xcode Command Line Tools
- Codex session logs in `~/.codex`

Install Xcode Command Line Tools if needed:

```bash
xcode-select --install
```

## Install

### Option 1: Clone and install

```bash
git clone https://github.com/peichh/CodexPulse.git
cd CodexPulse
./script/install.sh
```

The installer:

- builds a release binary with SwiftPM
- installs the app to `~/Applications/CodexPulse.app`
- enables launch-at-login with `~/Library/LaunchAgents/dev.codex.CodexPulse.plist`
- opens the app immediately

### Option 2: Download ZIP from GitHub

1. Open the GitHub repository.
2. Click **Code**.
3. Click **Download ZIP**.
4. Unzip it.
5. Open Terminal in the extracted folder.
6. Run:

```bash
./script/install.sh
```

### Option 3: Download from Releases

1. Open the [latest release](https://github.com/peichh/CodexPulse/releases/latest).
2. Download **Source code (zip)**.
3. Unzip it.
4. Open Terminal in the extracted folder.
5. Run:

```bash
./script/install.sh
```

### Option 4: One-line install

```bash
git clone https://github.com/peichh/CodexPulse.git /tmp/CodexPulse && /tmp/CodexPulse/script/install.sh
```

## Uninstall

From the repository folder:

```bash
./script/uninstall.sh
```

Or manually:

```bash
launchctl bootout "gui/$UID" "$HOME/Library/LaunchAgents/dev.codex.CodexPulse.plist" 2>/dev/null || true
pkill -x CodexPulse 2>/dev/null || true
rm -rf "$HOME/Applications/CodexPulse.app"
rm -f "$HOME/Library/LaunchAgents/dev.codex.CodexPulse.plist"
```

## How It Works

CodexPulse reads:

- `$CODEX_HOME/sessions`
- `$CODEX_HOME/archived_sessions`
- default `CODEX_HOME`: `~/.codex`

It searches recursively for `rollout-*.jsonl` files and parses the latest `token_count` event in each file.

Usage comes from:

- `payload.info.total_token_usage`
- fallback-compatible parsing for top-level token events

Rate limits come from:

- `payload.rate_limits.primary`
- `payload.rate_limits.secondary`

The app caches files by size and modification time, so repeat refreshes only parse changed logs.

## Estimated Tokens

Codex logs expose percent used, reset time, and token usage, but not the official token quota. CodexPulse estimates quota like this:

```text
estimated_limit = tokens_used_since_window_start / (used_percent / 100)
estimated_left = estimated_limit - tokens_used_since_window_start
```

This is an estimate, not an official Codex server limit.

## Development

Build:

```bash
swift build
```

Run locally:

```bash
./script/build_and_run.sh
```

Verify launch:

```bash
./script/build_and_run.sh --verify
```

## Privacy

CodexPulse reads local Codex log files only. It does not send data to any server.

## License

MIT
