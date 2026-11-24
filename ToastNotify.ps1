# 工作生活APP — 右下角 Windows 系統桌面通知（toast）
# 由主程式 工作生活APP.au3 呼叫：到達提醒時間時，把標題與內容寫入資料檔後執行本腳本
param([string]$DataFile)

$ErrorActionPreference = 'Stop'

try {
    $lines = @(Get-Content -LiteralPath $DataFile -Encoding UTF8)
    $title = '任務提醒'
    $message = ''
    if ($lines.Count -gt 0) { $title = $lines[0] }
    if ($lines.Count -gt 1) { $message = $lines[1] }

    # 載入 WinRT 類型以彈出系統 toast
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    $escTitle = [System.Security.SecurityElement]::Escape($title)
    $escMessage = [System.Security.SecurityElement]::Escape($message)
    $xmlText = '<toast><visual><binding template="ToastGeneric"><text>' + $escTitle + '</text><text>' + $escMessage + '</text></binding></visual></toast>'

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($xmlText)

    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $notifier.Show($toast)
}
catch {
    # 若系統通知不可用，退回傳統訊息框（僅緊急備援）
    $s = New-Object -ComObject WScript.Shell
    $s.Popup($message, 6, $title, 64) | Out-Null
}
finally {
    Remove-Item -LiteralPath $DataFile -Force -ErrorAction SilentlyContinue
}
