# Running iBurn on a physical device

Simulator work is the default (see [../SKILL.md](../SKILL.md)); this file covers
the extra setup needed to build, install, and launch on real hardware.

## Enabling the device workflow

XcodeBuildMCP only exposes device tools when the `device` workflow is enabled in
`.xcodebuildmcp/config.yaml`:

```yaml
schemaVersion: 1
enabledWorkflows: ["simulator", "device"]
```

After creating or modifying this file, restart the XcodeBuildMCP MCP server
(`/mcp` → reconnect in Claude Code).

## Device discovery

```bash
# List connected physical devices (USB or network)
xcrun devicectl list devices
```

## XcodeBuildMCP device workflow

1. `list_devices` — List connected devices and their UDIDs
2. `session_set_defaults` — Set workspace, scheme, and `deviceId` (UDID)
3. `build_run_device` — Build, install, and launch on device (single step)
4. `launch_app_device` — Launch an already-installed app
5. `start_device_log_cap` / `stop_device_log_cap` — Capture device logs
6. `test_device` — Run tests on the physical device

## Requirements

- Code signing must be configured in Xcode for the target device
- Device must have Developer Mode enabled
- Device must be unlocked for app launch to succeed
- Device builds need the Bash sandbox disabled — the sandbox hides the Keychain,
  so `codesign` can't find the iOS Development certificate
