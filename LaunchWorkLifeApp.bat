@echo off
title Run Reminder App
if exist "WorkLifeApp.au3" (
    start "" "WorkLifeApp.au3"
) else (
    echo 找不到 WorkLifeApp.au3！請把這個bat和au3放在同一個資料夾。
    pause
)
