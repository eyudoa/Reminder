;===============================================================================
; 工作生活APP（Reminder） — 個人專用本機程式（AutoIt3）
; 版本：v1.0.3
;
; 本版基於 v1.0.2 原始程式碼，**只新增一項功能：語言設定（繁體中文 / English）**
;   [A] 介面文字全部抽離成兩套語言表，_T() 統一取字
;   [B] 側邊欄新增「設定 › 語言」下拉選單，切換即時生效，不需重啟
;   [C] 預設繁體中文；選擇寫入資料檔的 [設定] › Language（zh / en），下次啟動沿用
;   [D] 杜絕語種不匹配：任務狀態在 INI 內一律保存原始字串「待提醒／已提醒／已錯過」，
;       介面只做「顯示時翻譯」，所有邏輯比較都用原始字串，切換語言不影響時間判斷與任務儲存
;   [E] 原有功能全部保留：任務計劃、查看任務、刪除任務、時間提醒、INI 讀寫、F11 全屏
;
; 功能：
;   1. 任務計劃：新增任務、設定提醒時間（HH:MM，24小時制，留空=不提醒）
;   2. 查看任務：瀏覽全部任務、刪除任務
;   3. F11 鍵切換全屏 / 視窗模式
;   4. 背景每 10 秒偵測提醒時間，到點彈出右下角 Windows 系統桌面通知
;      （每個任務只提醒一次；程式關閉即停止偵測）
;
; 資料：目標資料.ini（與本程式同一資料夾，不寫死任何磁碟路徑）
;
; v1.0.1 相對 v1.0.0 的修正（只修 bug，不新增功能）：
;   [1] 任務名稱含半形「|」會讓任務清單欄位錯亂 → 寫入前轉為全形「｜」
;   [2] 提醒時間輸入容錯：接受 9:30、09.30 等寫法，自動正規化為 09:30
;   [3] 新增任務時若提醒時間已過，原本會在 10 秒內誤彈提醒 → 改記為「已錯過」，不再誤報
;   [4] 同一輪偵測有多個任務到點時，通知會互相覆蓋只剩最後一個 → 合併為一則通知
;   [5] 未選取任務就按刪除時，錯誤訊息蓋掉「共 N 個任務」計數 → 改用訊息框提示
;   [6] F11 退出全屏時殘留 WS_POPUP 樣式，視窗可能還原成無邊框 → 還原時清除該樣式
;   [7] 視窗標題列與側邊欄底部加上版本號，方便確認執行的是哪一版
;
; v1.0.2 相對 v1.0.1 的修正（只修 bug，不新增功能）：
;   [8] 刪除任務後計數標籤被「已刪除任務（目前 N 個）」改寫，格式與清單不一致 → 不再覆寫，維持「共 N 個任務」
;   [9] 任務清單欄寬總和超出可視寬度，底部一直出現水平滾動條 → 重新配寬，滾動條消失
;   [10] 程式重啟後，INI 裡「今天已經過了卻還掛著待提醒」的任務永遠不會觸發也永遠不標記
;        → 啟動時掃描一次：時間已過（12 小時內）的待提醒任務記為「已錯過」
;   [11] 提醒時間輸入全形數字／全形冒號（０９：３０）一律被判格式錯誤 → 自動轉半形再正規化
;   [12] 同一份程式可以同時開多個，兩邊會各彈一次提醒、並同時覆寫同一個 INI → 加單一實例鎖
;===============================================================================
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <StaticConstants.au3>
#include <FileConstants.au3>
#include <Misc.au3>
#include <WinAPISysWin.au3>
#include <WinAPISysInternals.au3>
#include <WinAPIConstants.au3>

; 內部識別名（單一實例鎖用）。刻意固定為中文原名，不隨介面語言改變，
; 這樣切換語言後仍能與另一份執行中的程式撞到同一個鎖。
Global Const $APP_NAME = "工作生活APP"
Global Const $APP_VERSION = "1.0.3"

Global $sDataFile = @ScriptDir & "\目標資料.ini"

Global $hMain
Global $lblBrand, $btnPlan, $btnView
Global $lblSettingsHead, $lblLanguage, $cboLang, $lblVer
Global $lblNameTitle, $inpName, $lblTimeTitle, $inpTime, $lblTimeHint, $btnAdd, $lblMsg
Global $grpTasks, $lstTasks, $btnDelete, $lblCount

Global $iCurrentView = 1
Global $iTaskCount = 0
Global $aTaskIds[0]
Global $bFullscreen = False
Global $iPrevX, $iPrevY, $iPrevW, $iPrevH

; 目前介面語言：zh = 繁體中文（預設）、en = English
Global $sLang = "zh"

_Main()

Func _Main()
    ; [v1.0.3] 先讀語言設定，後面的訊息框與介面才知道要用哪套文字
    $sLang = _LoadLanguage()

    ; [v1.0.2] 單一實例鎖：避免同時開兩份，各彈一次提醒又一起覆寫同一個資料檔
    If _Singleton($APP_NAME, 1) = 0 Then
        MsgBox(0x40, _T("title"), _T("msgSingleton"))
        Return
    EndIf

    ; 托盤圖示提示（通知彈窗由程式托盤發出）
    TraySetToolTip(_T("title") & " v" & $APP_VERSION)

    ; 建立資料檔（若不存在）。Language 鍵只在新檔時寫入預設值，不影響既有任務資料
    If Not FileExists($sDataFile) Then
        IniWrite($sDataFile, "設定", "NextID", "1")
        IniWrite($sDataFile, "設定", "Language", "zh")
    EndIf

    $hMain = GUICreate(_T("title") & " v" & $APP_VERSION, 760, 520)
    GUISetBkColor(0xF5F5F5, $hMain)

    ;---------- 側邊欄 ----------
    $lblBrand = GUICtrlCreateLabel("", 18, 16, 130, 30)
    GUICtrlSetFont($lblBrand, 14, 600)
    GUICtrlSetColor($lblBrand, 0x1F6FB2)

    $btnPlan = GUICtrlCreateButton("", 12, 58, 128, 44)
    GUICtrlSetFont($btnPlan, 11, 600)
    $btnView = GUICtrlCreateButton("", 12, 110, 128, 44)
    GUICtrlSetFont($btnView, 11, 600)

    ;---------- 設定（語言切換） ----------
    $lblSettingsHead = GUICtrlCreateLabel("", 18, 170, 120, 18)
    GUICtrlSetFont($lblSettingsHead, 9, 600)
    GUICtrlSetColor($lblSettingsHead, 0x707070)
    $lblLanguage = GUICtrlCreateLabel("", 18, 194, 120, 18)
    GUICtrlSetFont($lblLanguage, 8.5, 400)
    GUICtrlSetColor($lblLanguage, 0x808080)
    $cboLang = GUICtrlCreateCombo("", 12, 214, 128, 24)

    $lblVer = GUICtrlCreateLabel("v" & $APP_VERSION, 18, 480, 120, 18)
    GUICtrlSetFont($lblVer, 8.5, 400)
    GUICtrlSetColor($lblVer, 0x909090)

    GUICtrlCreateLabel("", 152, 8, 1, 504, $SS_SUNKEN)

    ;---------- 任務計劃 檢視 ----------
    $lblNameTitle = GUICtrlCreateLabel("", 180, 62, 90, 22)
    $inpName = GUICtrlCreateInput("", 270, 58, 280, 26)
    $lblTimeTitle = GUICtrlCreateLabel("", 180, 102, 90, 22)
    $inpTime = GUICtrlCreateInput("", 270, 98, 120, 26)
    $lblTimeHint = GUICtrlCreateLabel("", 400, 102, 290, 22)
    GUICtrlSetColor($lblTimeHint, 0x808080)
    $btnAdd = GUICtrlCreateButton("", 270, 140, 120, 32)
    $lblMsg = GUICtrlCreateLabel("", 180, 196, 520, 48)

    ;---------- 查看任務 檢視 ----------
    $grpTasks = GUICtrlCreateGroup("", 172, 40, 560, 432)
    $lstTasks = GUICtrlCreateListView("", 188, 66, 528, 340)
    _GUICtrlListView_SetColumnWidth($lstTasks, 0, 312)
    _GUICtrlListView_SetColumnWidth($lstTasks, 1, 104)
    _GUICtrlListView_SetColumnWidth($lstTasks, 2, 96)
    _GUICtrlListView_SetExtendedListViewStyle($lstTasks, $LVS_EX_FULLROWSELECT)
    $btnDelete = GUICtrlCreateButton("", 188, 424, 120, 28)
    $lblCount = GUICtrlCreateLabel("", 560, 428, 160, 22)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    ; [v1.0.3] 統一由語言表上字（包含清單欄頭與下拉選單選項）
    _ApplyLanguage()

    _ShowView(1)

    GUISetState(@SW_SHOW, $hMain)

    AdlibRegister("_CheckReminders", 10000)
    AdlibRegister("_CheckF11", 200)

    ; [v1.0.2] 啟動先掃一次：今天已經過去、卻還掛著「待提醒」的任務不會再自己觸發
    _MarkMissedOnStart()

    While 1
        Switch GUIGetMsg()
            Case $GUI_EVENT_CLOSE
                ExitLoop
            Case $btnPlan
                _ShowView(1)
            Case $btnView
                _ShowView(2)
            Case $btnAdd
                _AddTask()
            Case $btnDelete
                _DeleteTask()
            Case $cboLang
                _OnLangChanged()
        EndSwitch
    WEnd

    AdlibUnRegister("_CheckReminders")
    AdlibUnRegister("_CheckF11")
    GUIDelete($hMain)
EndFunc   ;==>_Main

;===============================================================================
; 語言：讀取 / 切換 / 套用 / 取字
;===============================================================================

;---------- 讀取已存的語言設定（zh / en，其他值一律回繁體中文） ----------
Func _LoadLanguage()
    Local $s = IniRead($sDataFile, "設定", "Language", "zh")
    If $s = "en" Then Return "en"
    Return "zh"
EndFunc   ;==>_LoadLanguage

;---------- 下拉選單變更 → 立即切換（不重啟、不重建介面） ----------
Func _OnLangChanged()
    Local $sSel = GUICtrlRead($cboLang)
    Local $sNew = "zh"
    If $sSel = "English" Then $sNew = "en"
    _SetLanguage($sNew)
EndFunc   ;==>_OnLangChanged

Func _SetLanguage($sNew)
    If $sNew <> "zh" And $sNew <> "en" Then Return
    If $sNew = $sLang Then Return
    $sLang = $sNew
    ; 只多寫一個 [設定] › Language 鍵，任務區段完全不動
    IniWrite($sDataFile, "設定", "Language", $sLang)
    _ApplyLanguage()
EndFunc   ;==>_SetLanguage

;---------- 把目前語言的文字套到所有可見控件 ----------
Func _ApplyLanguage()
    Local $sTitle = _T("title") & " v" & $APP_VERSION
    _SetWindowTitle($sTitle)
    TraySetToolTip($sTitle)

    GUICtrlSetData($lblBrand, _T("brand"))
    GUICtrlSetData($btnPlan, _T("navPlan"))
    GUICtrlSetData($btnView, _T("navView"))

    GUICtrlSetData($lblSettingsHead, _T("settingsHead"))
    GUICtrlSetData($lblLanguage, _T("languageLabel"))
    ; 下拉選單的兩個選項固定用各自的母語名稱，選中的一項依目前語言帶出
    GUICtrlSetData($cboLang, "繁體中文|English", _LangItemName())

    GUICtrlSetData($lblNameTitle, _T("nameTitle"))
    GUICtrlSetData($lblTimeTitle, _T("timeTitle"))
    GUICtrlSetData($lblTimeHint, _T("timeHint"))
    GUICtrlSetData($btnAdd, _T("btnAdd"))

    GUICtrlSetData($grpTasks, _T("groupAll"))
    GUICtrlSetData($btnDelete, _T("btnDelete"))

    ; 清單欄頭：任務名稱 / 提醒時間 / 狀態
    Local $aCols = StringSplit(_T("colHeader"), "|")
    If $aCols[0] >= 3 Then
        _GUICtrlListView_SetColumn($lstTasks, 0, $aCols[1])
        _GUICtrlListView_SetColumn($lstTasks, 1, $aCols[2])
        _GUICtrlListView_SetColumn($lstTasks, 2, $aCols[3])
    EndIf

    ; 上一輪的提示文字是舊語言，直接清掉；清單則重畫一次以翻譯狀態欄
    GUICtrlSetData($lblMsg, "")
    If $iCurrentView = 2 Then
        _RefreshList()
    Else
        GUICtrlSetData($lblCount, "")
    EndIf
EndFunc   ;==>_ApplyLanguage

; 改視窗標題（直接用 SetWindowTextW，不需要舊標題字串比對）
Func _SetWindowTitle($sText)
    DllCall("user32.dll", "bool", "SetWindowTextW", "hwnd", $hMain, "wstr", $sText)
EndFunc   ;==>_SetWindowTitle

; 目前語言對應的下拉選單項目名稱
Func _LangItemName()
    If $sLang = "en" Then Return "English"
    Return "繁體中文"
EndFunc   ;==>_LangItemName

;---------- 語言表：同一個 key 回傳目前語言的文字 ----------
Func _T($sKey)
    Local $sZh = "", $sEn = ""
    Switch $sKey
        Case "title"
            $sZh = "工作生活APP"
            $sEn = "Work & Life"
        Case "brand"
            $sZh = "工作生活"
            $sEn = "Work & Life"
        Case "navPlan"
            $sZh = "任務計劃"
            $sEn = "Task Planner"
        Case "navView"
            $sZh = "查看任務"
            $sEn = "All Tasks"
        Case "settingsHead"
            $sZh = "設定"
            $sEn = "Settings"
        Case "languageLabel"
            $sZh = "語言："
            $sEn = "Language:"
        Case "nameTitle"
            $sZh = "任務名稱："
            $sEn = "Task name:"
        Case "timeTitle"
            $sZh = "提醒時間："
            $sEn = "Remind at:"
        Case "timeHint"
            $sZh = "格式 HH:MM（24小時制），留空 = 不提醒"
            $sEn = "HH:MM (24h); blank = no reminder"
        Case "btnAdd"
            $sZh = "新增任務"
            $sEn = "Add Task"
        Case "groupAll"
            $sZh = "全部任務"
            $sEn = "All Tasks"
        Case "colHeader"
            $sZh = "任務名稱|提醒時間|狀態"
            $sEn = "Task name|Time|Status"
        Case "btnDelete"
            $sZh = "刪除任務"
            $sEn = "Delete Task"
        Case "countOne"
            $sZh = "共 1 個任務"
            $sEn = "1 task"
        Case "countFmt"
            $sZh = "共 %d 個任務"
            $sEn = "%d tasks"
        Case "statusPending"
            $sZh = "待提醒"
            $sEn = "Pending"
        Case "statusReminded"
            $sZh = "已提醒"
            $sEn = "Reminded"
        Case "statusMissed"
            $sZh = "已錯過"
            $sEn = "Missed"
        Case "noTime"
            $sZh = "無"
            $sEn = "None"
        Case "msgNameEmpty"
            $sZh = "請先輸入任務名稱。"
            $sEn = "Please enter a task name first."
        Case "msgTimeBad"
            $sZh = "提醒時間格式不正確，請用 HH:MM（例如 14:30），或留空不提醒。"
            $sEn = "Invalid time. Use HH:MM (e.g. 14:30), or leave it blank."
        Case "msgAddedOk"
            $sZh = "已新增任務：「%s」，提醒時間 %s"
            $sEn = "Task added: %s - reminder at %s"
        Case "msgAddedNoTime"
            $sZh = "已新增任務：「%s」（未設定提醒時間）"
            $sEn = "Task added: %s (no reminder time)"
        Case "msgAddedMissed"
            $sZh = "已新增任務：「%s」，提醒時間 %s 已過，本次不提醒。"
            $sEn = "Task added: %s - %s has passed today, no reminder this time."
        Case "msgDeleteNone"
            $sZh = "請先選取要刪除的任務。"
            $sEn = "Please select a task to delete first."
        Case "msgSingleton"
            $sZh = "程式已經在執行中，請看工作列上既有的視窗。"
            $sEn = "The app is already running. Please check the existing window on the taskbar."
        Case "notifyTitleOne"
            $sZh = "任務提醒：%s"
            $sEn = "Task reminder: %s"
        Case "notifyBodyOne"
            $sZh = "時間到！現在 %s（設定 %s）"
            $sEn = "Time is up - now %s (set for %s)"
        Case "notifyTitleMany"
            $sZh = "任務提醒：%d 個任務時間到"
            $sEn = "Task reminder: %d tasks are due"
        Case "notifyBodyMany"
            $sZh = "現在 %s：%s"
            $sEn = "Now %s: %s"
        Case "joinSep"
            $sZh = "、"
            $sEn = ", "
        Case Else
            Return ""
    EndSwitch
    If $sLang = "en" Then Return $sEn
    Return $sZh
EndFunc   ;==>_T

;---------- 狀態值翻譯（INI 內永遠存原始中文，只在顯示時翻譯） ----------
Func _DisplayStatus($sStatus)
    Switch $sStatus
        Case "已提醒"
            Return _T("statusReminded")
        Case "已錯過"
            Return _T("statusMissed")
        Case Else
            Return _T("statusPending")
    EndSwitch
EndFunc   ;==>_DisplayStatus

;---------- 提醒時間顯示（空字串顯示為「無 / None」） ----------
Func _DisplayTime($sTime)
    If $sTime = "" Then Return _T("noTime")
    Return $sTime
EndFunc   ;==>_DisplayTime

;---------- 檢視切換 ----------
Func _ShowView($iView)
    $iCurrentView = $iView
    If $iView = 1 Then
        GUICtrlSetState($lblNameTitle, $GUI_SHOW)
        GUICtrlSetState($inpName, $GUI_SHOW)
        GUICtrlSetState($lblTimeTitle, $GUI_SHOW)
        GUICtrlSetState($inpTime, $GUI_SHOW)
        GUICtrlSetState($lblTimeHint, $GUI_SHOW)
        GUICtrlSetState($btnAdd, $GUI_SHOW)
        GUICtrlSetState($lblMsg, $GUI_SHOW)
        GUICtrlSetState($grpTasks, $GUI_HIDE)
        GUICtrlSetState($lstTasks, $GUI_HIDE)
        GUICtrlSetState($btnDelete, $GUI_HIDE)
        GUICtrlSetState($lblCount, $GUI_HIDE)
    Else
        GUICtrlSetState($lblNameTitle, $GUI_HIDE)
        GUICtrlSetState($inpName, $GUI_HIDE)
        GUICtrlSetState($lblTimeTitle, $GUI_HIDE)
        GUICtrlSetState($inpTime, $GUI_HIDE)
        GUICtrlSetState($lblTimeHint, $GUI_HIDE)
        GUICtrlSetState($btnAdd, $GUI_HIDE)
        GUICtrlSetState($lblMsg, $GUI_HIDE)
        GUICtrlSetState($grpTasks, $GUI_SHOW)
        GUICtrlSetState($lstTasks, $GUI_SHOW)
        GUICtrlSetState($btnDelete, $GUI_SHOW)
        GUICtrlSetState($lblCount, $GUI_SHOW)
        _RefreshList()
    EndIf
EndFunc   ;==>_ShowView

;---------- 提醒時間正規化（合法回傳 HH:MM，不合法回傳空字串） ----------
Func _NormalizeTime($sRaw)
    Local $s = StringStripWS($sRaw, 3)
    If $s = "" Then Return ""
    ; [v1.0.2] 全形數字與全形標點一律先轉半形，否則「０９：３０」會被判格式錯誤
    Local $aFull[10] = ["０", "１", "２", "３", "４", "５", "６", "７", "８", "９"]
    For $i = 0 To 9
        $s = StringReplace($s, $aFull[$i], String($i))
    Next
    $s = StringReplace($s, "．", ":")
    $s = StringReplace($s, ".", ":")
    $s = StringReplace($s, "：", ":")
    If StringRegExp($s, "^\d{1,2}:\d{1,2}$") = 0 Then Return ""
    Local $aParts = StringSplit($s, ":")
    Local $iH = Int($aParts[1])
    Local $iM = Int($aParts[2])
    If $iH > 23 Or $iM > 59 Then Return ""
    Return StringFormat("%02d:%02d", $iH, $iM)
EndFunc   ;==>_NormalizeTime

;---------- 新增任務 ----------
Func _AddTask()
    Local $sName = StringStripWS(GUICtrlRead($inpName), 3)
    If $sName = "" Then
        GUICtrlSetData($lblMsg, _T("msgNameEmpty"))
        Return
    EndIf
    ; [v1.0.1] 半形 | 是 ListView 的欄位分隔符，直接寫入會讓清單欄位錯亂
    $sName = StringReplace($sName, "|", "｜")

    Local $sTimeRaw = StringStripWS(GUICtrlRead($inpTime), 3)
    Local $sTime = ""
    If $sTimeRaw <> "" Then
        $sTime = _NormalizeTime($sTimeRaw)
        If $sTime = "" Then
            GUICtrlSetData($lblMsg, _T("msgTimeBad"))
            Return
        EndIf
    EndIf

    ; [v1.0.1] 新增時若時間已過，記為「已錯過」，避免 10 秒內立刻誤彈提醒
    Local $sNow = StringFormat("%02d:%02d", Int(@HOUR), Int(@MIN))
    Local $sStatus = "待提醒"
    Local $bMissed = False
    If $sTime <> "" And $sTime < $sNow Then
        $sStatus = "已錯過"
        $bMissed = True
    EndIf

    Local $iNext = Int(IniRead($sDataFile, "設定", "NextID", "1"))
    Local $sSection = "Task_" & $iNext
    IniWrite($sDataFile, $sSection, "Name", $sName)
    IniWrite($sDataFile, $sSection, "Time", $sTime)
    IniWrite($sDataFile, $sSection, "Status", $sStatus)
    IniWrite($sDataFile, "設定", "NextID", $iNext + 1)

    GUICtrlSetData($inpName, "")
    GUICtrlSetData($inpTime, "")
    If $sTime = "" Then
        GUICtrlSetData($lblMsg, StringFormat(_T("msgAddedNoTime"), $sName))
    ElseIf $bMissed Then
        GUICtrlSetData($lblMsg, StringFormat(_T("msgAddedMissed"), $sName, $sTime))
    Else
        GUICtrlSetData($lblMsg, StringFormat(_T("msgAddedOk"), $sName, $sTime))
    EndIf
EndFunc   ;==>_AddTask

;---------- 重新整理任務清單 ----------
Func _RefreshList()
    _GUICtrlListView_DeleteAllItems($lstTasks)
    ReDim $aTaskIds[0]
    $iTaskCount = 0
    Local $iNext = Int(IniRead($sDataFile, "設定", "NextID", "1"))
    For $i = 1 To $iNext - 1
        Local $sSection = "Task_" & $i
        Local $sName = IniRead($sDataFile, $sSection, "Name", "")
        If $sName = "" Then ContinueLoop
        Local $sTime = IniRead($sDataFile, $sSection, "Time", "")
        Local $sStatus = IniRead($sDataFile, $sSection, "Status", "待提醒")
        ReDim $aTaskIds[$iTaskCount + 1]
        $aTaskIds[$iTaskCount] = $sSection
        _GUICtrlListView_AddItem($lstTasks, $sName)
        ; [v1.0.3] 時間與狀態都只在顯示時轉換語言，INI 內容不變
        _GUICtrlListView_AddSubItem($lstTasks, $iTaskCount, _DisplayTime($sTime), 1)
        _GUICtrlListView_AddSubItem($lstTasks, $iTaskCount, _DisplayStatus($sStatus), 2)
        $iTaskCount += 1
    Next
    If $iTaskCount = 1 Then
        GUICtrlSetData($lblCount, _T("countOne"))
    Else
        GUICtrlSetData($lblCount, StringReplace(_T("countFmt"), "%d", String($iTaskCount)))
    EndIf
EndFunc   ;==>_RefreshList

;---------- 刪除任務 ----------
Func _DeleteTask()
    Local $sSel = _GUICtrlListView_GetSelectedIndices($lstTasks)
    If $sSel = "" Then
        ; [v1.0.1] 原本直接寫進計數標籤，會把「共 N 個任務」蓋掉且不復原
        MsgBox(0x30, _T("title"), _T("msgDeleteNone"))
        Return
    EndIf
    Local $iItem = Int($sSel)
    If $iItem < 0 Or $iItem >= UBound($aTaskIds) Then Return
    Local $sSection = $aTaskIds[$iItem]
    If $sSection = "" Then Return
    IniDelete($sDataFile, $sSection)
    ; [v1.0.2] _RefreshList 已經會更新「共 N 個任務」，不再另外覆寫計數標籤
    _RefreshList()
EndFunc   ;==>_DeleteTask

;---------- 啟動掃描：把今天已過、仍掛待提醒的任務標為「已錯過」 ----------
Func _MarkMissedOnStart()
    Local $iNext = Int(IniRead($sDataFile, "設定", "NextID", "1"))
    Local $iNow = Int(@HOUR) * 60 + Int(@MIN)
    Local $iChanged = 0
    For $i = 1 To $iNext - 1
        Local $sSection = "Task_" & $i
        Local $sName = IniRead($sDataFile, $sSection, "Name", "")
        If $sName = "" Then ContinueLoop
        Local $sTime = IniRead($sDataFile, $sSection, "Time", "")
        If $sTime = "" Then ContinueLoop
        If IniRead($sDataFile, $sSection, "Status", "待提醒") <> "待提醒" Then ContinueLoop
        Local $aParts = StringSplit($sTime, ":")
        If $aParts[0] < 2 Then ContinueLoop
        Local $iTask = Int($aParts[1]) * 60 + Int($aParts[2])
        Local $iDiff = $iNow - $iTask
        ; 過 1 分鐘到 12 小時 → 今天的時間已經過了，記為已錯過
        ; 超過 12 小時 → 視為「今晚還沒到」，保持待提醒
        If $iDiff > 0 And $iDiff <= 720 Then
            IniWrite($sDataFile, $sSection, "Status", "已錯過")
            $iChanged += 1
        EndIf
    Next
    If $iChanged > 0 And $iCurrentView = 2 Then _RefreshList()
EndFunc   ;==>_MarkMissedOnStart

;---------- 背景偵測提醒（每 10 秒） ----------
Func _CheckReminders()
    Local $iNext = Int(IniRead($sDataFile, "設定", "NextID", "1"))
    Local $sNow = StringFormat("%02d:%02d", Int(@HOUR), Int(@MIN))
    Local $aDueNames[0]
    Local $aDueTimes[0]
    Local $bChanged = False
    For $i = 1 To $iNext - 1
        Local $sSection = "Task_" & $i
        Local $sName = IniRead($sDataFile, $sSection, "Name", "")
        If $sName = "" Then ContinueLoop
        Local $sTime = IniRead($sDataFile, $sSection, "Time", "")
        Local $sStatus = IniRead($sDataFile, $sSection, "Status", "待提醒")
        ; 狀態比較一律用原始中文關鍵字，與介面語言無關
        If $sTime <> "" And $sStatus = "待提醒" And $sNow >= $sTime Then
            ReDim $aDueNames[UBound($aDueNames) + 1]
            ReDim $aDueTimes[UBound($aDueTimes) + 1]
            $aDueNames[UBound($aDueNames) - 1] = $sName
            $aDueTimes[UBound($aDueTimes) - 1] = $sTime
            IniWrite($sDataFile, $sSection, "Status", "已提醒")
            $bChanged = True
        EndIf
    Next
    If UBound($aDueNames) > 0 Then _FireNotification($aDueNames, $aDueTimes, $sNow)
    If $bChanged And $iCurrentView = 2 Then _RefreshList()
EndFunc   ;==>_CheckReminders

;---------- 彈出系統桌面通知（原生托盤通知，右下角系統彈窗，同進程、無外部依賴） ----------
Func _FireNotification($aNames, $aTimes, $sNow)
    If UBound($aNames) = 1 Then
        ; TrayTip(主要文字, 次要文字, 顯示秒數, 圖示類型 1=資訊)
        TrayTip(StringFormat(_T("notifyTitleOne"), $aNames[0]), StringFormat(_T("notifyBodyOne"), $sNow, $aTimes[0]), 10, 1)
        Return
    EndIf
    ; [v1.0.1] 多個任務同時到點時合併為一則，避免後一則蓋掉前一則
    Local $sList = ""
    For $i = 0 To UBound($aNames) - 1
        If $sList <> "" Then $sList &= _T("joinSep")
        $sList &= $aNames[$i]
    Next
    TrayTip(StringFormat(_T("notifyTitleMany"), UBound($aNames)), StringFormat(_T("notifyBodyMany"), $sNow, $sList), 10, 1)
EndFunc   ;==>_FireNotification

;---------- F11 全屏切換 ----------
Func _CheckF11()
    If _IsPressed("7A") And WinActive($hMain) Then
        _ToggleFullscreen()
        While _IsPressed("7A")
            Sleep(50)
        WEnd
    EndIf
EndFunc   ;==>_CheckF11

Func _ToggleFullscreen()
    Local $iStyle = _WinAPI_GetWindowLong($hMain, $GWL_STYLE)
    If Not $bFullscreen Then
        Local $aPos = WinGetPos($hMain)
        $iPrevX = $aPos[0]
        $iPrevY = $aPos[1]
        $iPrevW = $aPos[2]
        $iPrevH = $aPos[3]
        $iStyle = BitOR(BitAND($iStyle, BitNOT(BitOR($WS_CAPTION, $WS_THICKFRAME))), $WS_POPUP)
        _WinAPI_SetWindowLong($hMain, $GWL_STYLE, $iStyle)
        _WinAPI_SetWindowPos($hMain, 0, 0, 0, @DesktopWidth, @DesktopHeight, 0x0020) ; SWP_FRAMECHANGED
        $bFullscreen = True
    Else
        ; [v1.0.1] 先清掉全屏時加上的 WS_POPUP，否則還原後可能變成無邊框視窗
        $iStyle = BitAND($iStyle, BitNOT($WS_POPUP))
        $iStyle = BitOR(BitOR($iStyle, $WS_CAPTION), $WS_THICKFRAME)
        _WinAPI_SetWindowLong($hMain, $GWL_STYLE, $iStyle)
        _WinAPI_SetWindowPos($hMain, 0, $iPrevX, $iPrevY, $iPrevW, $iPrevH, 0x0020)
        $bFullscreen = False
    EndIf
    GUISetState(@SW_SHOW, $hMain)
EndFunc   ;==>_ToggleFullscreen