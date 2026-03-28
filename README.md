# apple_reminder_cli

Forget the app, not the task ✅

Fast CLI for Apple Reminders on macOS.

This repository is based on [steipete/remindctl](https://github.com/steipete/remindctl) and continues in the same direction with project-specific improvements.

Notable additions in this fork:
- stronger permissions flow for Reminders access, including explicit `authorize`, `status`, and guided `permission-setting` commands
- local per-list policy controls for reads, edits, deletes, completion, and list management
- clearer agent/automation-oriented behavior through JSON/plain output modes and policy-aware safeguards

## Install

### Homebrew (Home Pro)
```bash
brew install RoversX/tap/apple_reminder_cli
```

### From source
```bash
make build
# binary at ./bin/apple_reminder_cli
```

## Development
```bash
make apple_reminder_cli ARGS="status"   # clean build + run
make check                     # lint + test + coverage gate
```

## Requirements
- macOS 14+ (Sonoma or later)
- Swift 6.2+
- Reminders permission (System Settings → Privacy & Security → Reminders)

## Usage
```bash
apple_reminder_cli                      # show today (default)
apple_reminder_cli today                 # show today
apple_reminder_cli tomorrow              # show tomorrow
apple_reminder_cli week                  # show this week
apple_reminder_cli overdue               # overdue
apple_reminder_cli upcoming              # upcoming
apple_reminder_cli completed             # completed
apple_reminder_cli all                   # all reminders
apple_reminder_cli 2026-01-03            # specific date

apple_reminder_cli list                  # lists
apple_reminder_cli list Work             # show list
apple_reminder_cli list Work --rename Office
apple_reminder_cli list Work --delete
apple_reminder_cli list Projects --create

apple_reminder_cli add "Buy milk"
apple_reminder_cli add --title "Call mom" --list Personal --due tomorrow
apple_reminder_cli edit 1 --title "New title" --due 2026-01-04
apple_reminder_cli complete 1 2 3
apple_reminder_cli delete 4A83 --force
apple_reminder_cli policy                # show effective policy
apple_reminder_cli policy Work           # show one list's policy
apple_reminder_cli policy lists         # show known lists and overrides
apple_reminder_cli policy set Work delete deny
apple_reminder_cli policy unset Work delete
apple_reminder_cli permission-setting    # guided policy editor
apple_reminder_cli status                # permission status
apple_reminder_cli authorize             # request permissions
```

## Output formats
- `--json` emits JSON arrays/objects.
- `--plain` emits tab-separated lines.
- `--quiet` emits counts only.

## Local policy
Per-list behavior is configured in `~/.config/apple_reminder_cli/policy.json`.
The first reminders command creates this file automatically with permissive defaults:
- all lists are allowed by default
- completed reminder history is hidden by default

Example:
```json
{
  "defaults": {
    "add": true,
    "complete": true,
    "createList": true,
    "delete": true,
    "deleteList": true,
    "edit": true,
    "readActive": true,
    "readCompleted": false,
    "renameList": true
  },
  "lists": {
    "Private": {
      "readActive": false,
      "readCompleted": false
    },
    "Work": {
      "delete": false,
      "readCompleted": true
    }
  }
}
```

This policy is a local behavior guard for agents and automation. It is not a hard security boundary.
Use `apple_reminder_cli policy` to inspect the current effective rules and
`apple_reminder_cli policy set/unset` for direct edits.
Use `apple_reminder_cli permission-setting` if you want a guided step-by-step editor.
For stable automation or precise edits, prefer `apple_reminder_cli policy set` and `apple_reminder_cli policy unset`.

## Date formats
Accepted by `--due` and filters:
- `today`, `tomorrow`, `yesterday`
- `YYYY-MM-DD`
- `YYYY-MM-DD HH:mm`
- ISO 8601 (`2026-01-03T12:34:56Z`)

## Permissions
Run `apple_reminder_cli authorize` to trigger the system prompt. If access is denied, enable
Terminal (or apple_reminder_cli) in System Settings → Privacy & Security → Reminders.
If running over SSH, grant access on the Mac that runs the command.
