# ⚡ FlowBar

A native macOS menu bar app for local automation — run Apple Shortcuts, n8n workflows, shell scripts, Node.js, and Python scripts on a schedule or on demand.

> **Local-first.** No cloud. No servers. Just your Mac.

---

## Features

| Feature | Details |
|---|---|
| **Menu bar native** | Lives in your menu bar, hides from Dock |
| **5 workflow types** | Apple Shortcuts · n8n · Shell · Node.js · Python |
| **Flexible scheduling** | Manual · Interval · Daily · Weekly |
| **launchd integration** | Auto-generates LaunchAgent plists for reliable background scheduling |
| **Live logs** | Captures stdout, stderr, exit codes, duration |
| **macOS Notifications** | Success / Failure / Scheduler paused alerts |
| **Keychain storage** | Secrets stored securely — never in plaintext |
| **Liquid Glass UI** | SwiftUI with vibrancy / ultra-thin material, dark mode |
| **Launch at login** | Optional via LaunchAtLogin |

---

## Screenshots

```
┌──────────────────────────────────────────┐
│  ⚡ FlowBar          ●1 running  ⏸ + ≡  │
│  ──────────────────────────────────────  │
│  🔍 Search workflows…                    │
│  ──────────────────────────────────────  │
│  ┌────────────────────────────────────┐  │
│  │ ✅ AI Token Monitor    Every 5m    │  │
│  │    Python · ai, monitoring         │  │
│  ├────────────────────────────────────┤  │
│  │ ⏺ Daily Git Backup   23:00 daily  │  │
│  │    Shell · git, backup             │  │
│  └────────────────────────────────────┘  │
│  ──────────────────────────────────────  │
│  2 active · 3 total              Quit ›  │
└──────────────────────────────────────────┘
```

---

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/alexanderbrunker-star/alexanderbrunker-star.git
cd alexanderbrunker-star/FlowBar

# Run setup (installs XcodeGen, generates project, installs example scripts)
bash setup.sh

# Or manually:
xcodegen generate --spec project.yml
open FlowBar.xcodeproj
```

Then in Xcode:
1. Select the **FlowBar** scheme
2. Set your **Team** in *Signing & Capabilities*
3. Press **⌘R** to build and run

---

## Project Structure

```
FlowBar/
├── project.yml                     # XcodeGen project spec
├── Makefile                        # Build shortcuts
├── setup.sh                        # One-command setup
│
└── FlowBar/
    ├── FlowBarApp.swift             # App entry + MenuBarExtra
    ├── AppState.swift               # Central ObservableObject
    │
    ├── Models/
    │   ├── Workflow.swift           # Workflow, WorkflowType, WorkflowSchedule, WorkflowStatus
    │   └── ExecutionLog.swift       # ExecutionLog, LogStore
    │
    ├── Services/
    │   ├── WorkflowRepository.swift # JSON persistence (~Library/Application Support/FlowBar/)
    │   ├── ExecutionService.swift   # Process runner (async, captures stdout/stderr/exit code)
    │   ├── SchedulerService.swift   # Timer-based in-app scheduling
    │   ├── LaunchAgentManager.swift # launchd plist install/uninstall/reload
    │   ├── NotificationService.swift# UNUserNotificationCenter wrapper
    │   ├── LogService.swift         # Log storage + retrieval
    │   └── KeychainService.swift    # Secure secret storage
    │
    ├── Views/
    │   ├── MenuBarView.swift        # Main dropdown (header, search, list, footer)
    │   ├── WorkflowRowView.swift    # Expandable row with status dot + quick actions
    │   ├── WorkflowDetailView.swift # Full edit + log history sheet
    │   ├── LogsView.swift           # Searchable log explorer (split view)
    │   ├── AddEditWorkflowView.swift# Create / edit workflow sheet
    │   └── SettingsView.swift       # App preferences + Launch at Login
    │
    ├── Utilities/
    │   ├── PlistGenerator.swift     # Generates launchd plist XML
    │   └── Extensions.swift         # Date, Color, View helpers
    │
    └── Resources/
        └── ai_token_monitor.py      # Example: AI token budget monitor
```

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                     SwiftUI Views                   │
│  MenuBarView → WorkflowRowView → WorkflowDetailView │
│  LogsView → AddEditWorkflowView → SettingsView      │
└────────────────────┬────────────────────────────────┘
                     │ @EnvironmentObject
┌────────────────────▼────────────────────────────────┐
│                    AppState                         │
│  @MainActor ObservableObject — central coordinator  │
└──┬──────────┬─────────────┬──────────┬─────────────┘
   │          │             │          │
   ▼          ▼             ▼          ▼
WorkflowRepo Execution  Scheduler  LaunchAgent
(JSON)      Service     Service    Manager
             │           │          │
             │     Timer loops   plist XML
             │           │       launchctl
             ▼           └───────────┘
          Process
        (bash/node/python/shortcuts/n8n)
             │
     stdout + stderr + exit code
             │
             ▼
         LogService ──→ Notifications
         (JSON file)    (UNUserNotification)
```

### Two-layer scheduling

FlowBar uses two complementary mechanisms:

| Layer | When | How |
|---|---|---|
| **In-app Timer** | App is running | `Timer` with `SchedulerService` |
| **launchd** | App not running / on schedule | `LaunchAgent` plist via `launchctl` |

Both layers converge on `ExecutionService.execute(_:)`.

---

## Workflow Types

### Apple Shortcut
```
shortcuts run "Shortcut Name"
```

### n8n Workflow
```
n8n execute --id WORKFLOW_ID
```
> Requires `n8n` installed globally: `npm install -g n8n`

### Shell Script
```
/bin/bash ~/path/to/script.sh
```

### Node.js
```
node ~/path/to/script.js
```

### Python
```
python3 ~/path/to/script.py
```

---

## Scheduling

FlowBar uses **native launchd LaunchAgents** for reliable background scheduling.

### Supported Triggers

| Type | launchd key | Example |
|---|---|---|
| Manual | — | Only runs on demand |
| Interval | `StartInterval` | Every 5 minutes: `300` |
| Daily | `StartCalendarInterval` | 09:00 every day |
| Weekly | `StartCalendarInterval` | Monday 09:00 |

Generated plist example (daily at 09:00):
```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key><integer>9</integer>
    <key>Minute</key><integer>0</integer>
</dict>
```

Plists are stored in `~/Library/LaunchAgents/com.flowbar.<workflow-uuid>.plist`.

---

## Included Example: AI Token Monitor

The first workflow (`ai_token_monitor.py`) demonstrates:

- Checking Claude / OpenAI token usage
- Sending macOS notification when budget is approached
- Creating a weekly 5-minute **"AI Token Budget Reset"** meeting in Apple Calendar (named **"AI"**)

Configure it with environment variables in the workflow editor:
```
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
BUDGET_USD=50
CALENDAR_NAME=AI
```

Schedule: **Every 5 minutes** (configurable)  
Weekly calendar reset meeting: created automatically every Monday

---

## Permissions Required

| Permission | Why |
|---|---|
| **Notifications** | Success / failure alerts |
| **Apple Events** | Running Apple Shortcuts via `shortcuts run` |
| **Calendars** | Creating AI budget reset meetings (optional) |
| **Keychain** | Storing secrets securely |
| **Network Client** | n8n webhook support, API calls |

> **Note:** App Sandbox is disabled to allow unrestricted local script execution. FlowBar is designed for local use only — never expose commands publicly.

---

## Security

- All execution is **local only** — no data leaves your Mac
- Secrets are stored in **macOS Keychain** (never in JSON)
- No sandbox = full filesystem/script access (by design for an automation tool)
- Scripts run as the current user — no privilege escalation

---

## Build & Development

```bash
# Generate project (after changing project.yml or adding files)
make generate

# Build
make build

# Build + Launch
make run

# Clean
make clean
```

---

## License

MIT — see LICENSE file.

---

## Roadmap

- [ ] Workflow dependencies (run B after A succeeds)
- [ ] Webhook triggers (local HTTP server)
- [ ] Retry logic with exponential backoff
- [ ] Drag-and-drop workflow reordering
- [ ] Custom background / leopard theme
- [ ] AI workflow monitor templates
- [ ] Import/export workflows as JSON
