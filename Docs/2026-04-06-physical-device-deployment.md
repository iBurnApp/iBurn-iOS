# Physical Device Deployment via XcodeBuildMCP

## Problem Statement
Need to build and deploy iBurn to a physical iPhone connected over the network using XcodeBuildMCP from Claude Code.

## Solution Overview
1. Created `.xcodebuildmcp/config.yaml` to enable the `device` workflow
2. Used XcodeBuildMCP tools to discover, configure, and deploy to the device
3. Documented the process in CLAUDE.md

## Key Changes

### Created: `.xcodebuildmcp/config.yaml`
```yaml
schemaVersion: 1
enabledWorkflows: ["simulator", "device"]
```

### Updated: `CLAUDE.md`
Added "Physical Device Deployment (XcodeBuildMCP)" section documenting:
- Config file format for enabling device workflow
- Device discovery commands
- XcodeBuildMCP device tool workflow
- Requirements (code signing, Developer Mode, unlocked device)

## Technical Details

### Device Information
- **Name**: BigPhone 17
- **Model**: iPhone 17 Pro Max (iPhone18,2)
- **UDID**: `1A09342E-71A1-59B4-A4F2-1891F5154214`
- **Connection**: localNetwork
- **CPU**: arm64e
- **Developer Mode**: enabled

### XcodeBuildMCP Device Tools (enabled by `device` workflow)
- `build_device`, `build_run_device` — Build for physical device
- `install_app_device`, `launch_app_device` — Install/launch
- `list_devices` — Discover connected devices
- `test_device` — Run tests on device
- `start_device_log_cap`, `stop_device_log_cap` — Log capture
- `stop_app_device`, `get_device_app_path` — Utility

### Session Defaults Used
```
workspacePath: /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace
scheme: iBurn
deviceId: 1A09342E-71A1-59B4-A4F2-1891F5154214
```

### Build Result
- Build and install: **succeeded**
- Launch: failed because device was locked (expected — unlock device and tap app icon or use `launch_app_device`)

## Decision Rationale
- Chose to add both `simulator` and `device` to `enabledWorkflows` to preserve existing simulator functionality
- Documented in CLAUDE.md rather than a separate file since it's a core development workflow
- Used `session_set_defaults` for session config rather than persisting deviceId in config.yaml, since device UDIDs may change

## Expected Outcomes
- XcodeBuildMCP device tools available after MCP server restart
- `build_run_device` successfully builds, installs, and launches iBurn on BigPhone 17
- Future Claude Code sessions can reference CLAUDE.md for device deployment steps
