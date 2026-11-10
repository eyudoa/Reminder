# Work & Life App (Reminder) Changelog

## v1.0.1 — 2026-11-10

This update only includes version upgrades and bug fixes, with no new features added.

### Bug Fixes

1. **Task names containing half-width `|` break the list layout**
The vertical pipe is the column separator for the task list. If it appears inside a task name, the whole row will be split into multiple columns and misaligned with headers.
Now it will automatically convert to full-width `｜` before saving, keeping the three-column layout intact.

2. **Flexible input for reminder time**
The old version only accepted two-digit formats like `09:30`. Inputs such as `9:30` or `09.30` were marked as invalid.
Now inputs will be auto-normalized to `09:30`. Truly invalid values (e.g. `25:00`, `9:70`) will still be rejected with a prompt.

3. **False alert popping up immediately when adding a task with a past time**
The old logic checked if the current time >= target time. If you added a 09:30 task at 20:00, the reminder would trigger within 10 seconds.
Now tasks with past time will be marked as "Missed" on creation, no false alerts. The status column will show "Missed".

4. **Notifications overwrite each other when multiple tasks trigger at the same time**
The old version sent system notifications one by one. Later notifications replaced earlier ones, so only the last one was visible.
All due tasks detected in the same check cycle are merged into one single notification now.

5. **Task counter gets overwritten when pressing Delete without selecting a task**
The old version wrote the warning text "Please select a task to delete." into the label showing "Total N tasks", overwriting the count permanently.
A message box is used for the prompt instead, leaving the task counter untouched.

6. **Window becomes borderless after exiting fullscreen with F11**
The `WS_POPUP` style added for fullscreen was not removed on restore. The restored window might lack a title bar and cannot be dragged or resized.
Now the style is cleared before restoring, bringing back the title bar and resizable borders.

7. **Version label update**
Window title changes to "Work & Life App v1.0.1". A grey `v1.0.1` label is added at the bottom of the sidebar, and the tray tooltip also shows the new version.

8. **Risk of failing to locate AutoIt3 launcher**
The old version only checked the 32-bit (`WOW6432Node`) registry view. It worked on your machine but failed on PCs with 64-bit AutoIt installations.
Now it checks in order: 64-bit registry view → 32-bit registry view → current user → two common install paths → PATH. It launches if any location is found.
The launcher file stays pure ASCII. It uses its own folder as the base path, so the whole folder can be moved without edits.

### Unchanged on purpose
- Data file `目標資料.ini` format stays fully compatible with v1.0.0. Old data can be used directly with no conversion.
- Reminder engine remains the same: background check every 10 seconds, one alert per task, checks stop once the program closes.
- UI layout, button positions and double-click startup flow are unchanged.
- No new features.

## v1.0.0 — 2026-10-24
Initial release: task planner (add tasks / set reminder time), task view (browse / delete), F11 fullscreen toggle,
Windows desktop notifications in the bottom-right corner (each task alerts only once).
