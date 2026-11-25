WorkLifeApp (Reminder) v1.0.1 — User Manual

Release Date: 2026-11-25
1. What’s inside this folder

    WorkLifeApp.au3 Main program (all source code is contained in this single file)
    LaunchWorkLifeApp.bat Startup script (opens CMD, locates AutoIt3 automatically and runs the program)
    CHANGELOG.md Version log (all fixes for v1.0.2 are documented here)
    User Manual.txt This document
    TaskData.ini Data file (automatically generated on first launch; no need to create it manually)

2. Dependencies

    AutoIt3 v3.3 or newer (installed locally at E:\APP\AutoIt3, version v3.3.18.0)
        AutoIt3.exe Interpreter to run the main script
        Au3Check.exe Syntax checker (optional)
        Aut2Exe\Aut2Exe.exe Compiler to build a standalone EXE (optional)
    Operating System: Windows 10 or later (modern toast notifications in the bottom-right corner are supported starting from Win10)
    Permissions: Administrator rights are NOT required. The program does not write to the registry or create Task Scheduler tasks.
    No browser, network, cloud service or external script dependencies.

3. How to Launch

Method A: Double-click LaunchWorkLifeApp.bat

    A CMD window will pop up. It searches for AutoIt3.exe via the registry / system PATH and runs the program if found.
    After you close the program, CMD stays at "Press any key to continue". You may close it manually.
    The whole folder can be copied to any location. The launcher uses its own directory as the working path, no hardcoded paths.

Method B: Open WorkLifeApp.au3 directly with AutoIt3.exe

    Same behaviour as Method A, without the CMD window.

Only one instance is allowed at a time. Launching the program again will show a prompt: Program is already running, and no second window will open.
4. Compile to standalone EXE (Optional)

Open CMD inside the folder and run this command:After WorkLifeApp.exe is generated, modify the last execution line inside LaunchWorkLifeApp.bat to:Benefits of the compiled build:

    Runs without AutoIt3 installed.
    Notification source name will show your EXE filename, instead of "AutoIt v3 Script" when running via interpreter.

5. Operations

    Sidebar [Task Planner]: Enter task name → (Optional) Enter reminder time → Click Add Task
        Time format: HH:MM (24-hour format). Inputs like 9:30, 09.30, or full-width ０９：３０ will be normalized to 09:30 automatically.
        Leave time blank = No reminder for this task.
        If the set time has already passed when adding the task, it will be marked as Missed and will not trigger an immediate alert.
    Sidebar [View Tasks]: List shows task name / reminder time / status. Select an entry and click Delete Task to remove it.
    F11: Toggle fullscreen / windowed mode (window must be focused first).

6. Reminder Mechanism

    While the program is running, it checks the time every 10 seconds. A Windows toast notification pops up at the bottom-right when the time matches.
    Each task triggers only once. Status changes to Reminded after notification, no repeated alerts.
    Multiple tasks due at the same time will be merged into one single notification.
    Closing the program stops all time checks and reminders. No Task Scheduler is used by design.
    No alerts during PC sleep. After wake-up, missed reminders will pop up on the next check cycle.
    On program restart: pending tasks whose set time fell within the last 12 hours will be marked as Missed and will not fire retroactively.

7. Data File

    Path: TaskData.ini in the same folder as the main program (no hardcoded path).
    File structure example:3. Fields: Name = Task title; Time = Reminder time (blank = no reminder); Status = Current state Valid status values: Pending / Reminded / Missed
    Encoding: This file must be ANSI (GBK). Do NOT save it as UTF-8 when editing manually with Notepad or other editors. AutoIt cannot read Chinese section names like [Settings] under UTF-8 encoding, which will make all tasks disappear. Best practice: Avoid manual edits while the program is closed. Modify tasks via the program UI.
    Clear all tasks: Close the program → Delete TaskData.ini → Restart the program. A blank data file will be regenerated automatically.

8. Fixes in v1.0.2

    Task counter label corrupted after deleting tasks → Fixed, keeps showing "Total: N tasks" correctly.
    Unwanted horizontal scrollbar at the bottom of task list → Adjusted column widths (312/104/96) to remove scrollbar.
    Tasks whose time had passed stayed Pending forever after restart → Added startup scan to mark overdue tasks as Missed.
    Full-width digits / full-width colons were treated as invalid time format → Convert to half-width characters before parsing.
    Multiple program instances running simultaneously, causing duplicate reminders and data file overwrites → Added single-instance lock.

See CHANGELOG.md for details. No new features are added in this release. The data format is fully compatible with v1.0.1.
9. Known Limitations

    Reminders only work while the program is open. Reminders stop once closed, this is intentional design.
    Notification source name: Shows "AutoIt v3 Script" for interpreted runs; shows the EXE name for compiled builds. Notifications auto-dismiss after roughly 10 seconds.
    Tasks are time-only, date is not tracked. Each task alerts only once. To repeat the reminder on the next day, you need to create a new task entry. Recurring schedule is not implemented in this version.
