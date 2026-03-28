# Manual tests

## Scope
Run on a local GUI session (not SSH-only) so the Reminders permission prompt can appear.

## Test data
- Use a dedicated list: `apple_reminder_cli-manual-YYYYMMDD` (create if missing).
- Create 3 reminders with distinct states:
  - `apple_reminder_cli test A` (due today, priority high)
  - `apple_reminder_cli test B` (due tomorrow)
  - `apple_reminder_cli test C` (no due date)

## Checklist
- authorize: `apple_reminder_cli authorize`
- status: `apple_reminder_cli status`
- list lists: `apple_reminder_cli list`
- list list contents: `apple_reminder_cli list "apple_reminder_cli-manual-YYYYMMDD"`
- add reminders (3 variants)
- show filters: `today`, `tomorrow`, `week`, `overdue`, `upcoming`, `completed`, `all`
- edit: update title/notes/priority/due date
- complete: mark one reminder complete
- delete: remove reminders, then delete list

## Results
- Date:
- Machine:
- Permission state before/after:
- Notes:
