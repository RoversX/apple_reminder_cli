---
name: apple-reminders
description: Manage Apple Reminders via apple_reminder_cli (list, add, edit, complete, delete). Supports lists, date filters, per-list policy, and JSON/plain output.
homepage: https://github.com/roversx/apple_reminder_cli
metadata:
  {
    "openclaw":
      {
        "emoji": "⏰",
        "os": ["darwin"],
        "requires": { "bins": ["apple_reminder_cli"] },
        "install":
          [
            {
              "id": "brew",
              "kind": "brew",
              "formula": "roversx/tap/apple_reminder_cli",
              "bins": ["apple_reminder_cli"],
              "label": "Install apple_reminder_cli via Homebrew",
            },
          ],
      },
  }
---

# Apple Reminders CLI (apple_reminder_cli)

Use `apple_reminder_cli` to manage Apple Reminders directly from the terminal.

## When to Use

✅ **USE this skill when:**

- User explicitly mentions "reminder" or "Reminders app"
- Creating personal to-dos with due dates that sync to iOS
- Managing Apple Reminders lists
- User wants tasks to appear in their iPhone/iPad Reminders app

## When NOT to Use

❌ **DON'T use this skill when:**

- Scheduling OpenClaw tasks or alerts → use `cron` tool with systemEvent instead
- Calendar events or appointments → use Apple Calendar
- Project/work task management → use Notion, GitHub Issues, or task queue
- One-time notifications → use `cron` tool for timed alerts
- User says "remind me" but means an OpenClaw alert → clarify first

## Setup

- macOS-only; grant Reminders permission when prompted
- Check status: `apple_reminder_cli status`
- Request access: `apple_reminder_cli authorize`

## Common Commands

### View Reminders

```bash
apple_reminder_cli                        # Today's reminders
apple_reminder_cli show today             # Today
apple_reminder_cli show tomorrow          # Tomorrow
apple_reminder_cli show week              # This week
apple_reminder_cli show overdue           # Past due
apple_reminder_cli show all              # Everything
apple_reminder_cli show 2026-01-04        # Specific date
apple_reminder_cli show --list Work       # Filter by list
```

### Manage Lists

```bash
apple_reminder_cli list                   # List all lists
apple_reminder_cli list Work              # Show specific list
```

### Create Reminders

```bash
apple_reminder_cli add "Buy milk"
apple_reminder_cli add --title "Call mom" --list Personal --due tomorrow
apple_reminder_cli add --title "Meeting prep" --due "2026-02-15 09:00"
apple_reminder_cli add "Review docs" --priority high
```

### Edit / Complete / Delete

```bash
apple_reminder_cli edit <id> --title "New title" --due tomorrow
apple_reminder_cli complete <id> [id...]
apple_reminder_cli delete <id> [id...]
```

### Output Formats

```bash
apple_reminder_cli show today --json      # JSON for scripting
apple_reminder_cli show today --plain     # Stable line-based output
apple_reminder_cli show today --quiet     # Counts only
```

### Per-list Policy

Control which operations are allowed per list:

```bash
apple_reminder_cli policy                             # Show current policy
apple_reminder_cli policy Work                        # Show policy for a list
apple_reminder_cli policy set Work delete deny        # Deny delete on Work list
apple_reminder_cli policy set defaults readCompleted deny
apple_reminder_cli policy unset Work delete           # Remove override
apple_reminder_cli permission-setting                 # Interactive arrow-key editor
```

## Date Formats

Accepted by `--due` and date filters:

- `today`, `tomorrow`, `yesterday`
- `YYYY-MM-DD`
- `YYYY-MM-DD HH:mm`
- ISO 8601 (`2026-01-04T12:34:56Z`)

## Example: Clarifying User Intent

User: "Remind me to check on the deploy in 2 hours"

**Ask:** "Do you want this in Apple Reminders (syncs to your phone) or as an OpenClaw alert (I'll message you here)?"

- Apple Reminders → use this skill
- OpenClaw alert → use `cron` tool with systemEvent
