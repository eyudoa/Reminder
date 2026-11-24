
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

Global $sDataFile = @ScriptDir & "\目標資料.ini"

Global $hMain
Global $btnPlan, $btnView
Global $lblNameTitle, $inpName, $lblTimeTitle, $inpTime, $lblTimeHint, $btnAdd, $lblMsg
Global $grpTasks, $lstTasks, $btnDelete, $lblCount

Global $iCurrentView = 1
Global $iTaskCount = 0
Global $aTaskIds[0]
Global $bFullscreen = False
Global $iPrevX, $iPrevY, $iPrevW, $iPrevH

_Main()

Func _Main()
	; 托盤圖示提示（通知彈窗由程式托盤發出）
	TraySetToolTip("工作生活APP")

	; 建立資料檔（若不存在）
	If Not FileExists($sDataFile) Then
		IniWrite($sDataFile, "設定", "NextID", "1")
	EndIf

	$hMain = GUICreate("工作生活APP", 760, 520)
	GUISetBkColor(0xF5F5F5, $hMain)

	;---------- 側邊欄 ----------
	GUICtrlCreateLabel("工作生活", 18, 16, 110, 30)
	GUICtrlSetFont(-1, 14, 600)
	GUICtrlSetColor(-1, 0x1F6FB2)

	$btnPlan = GUICtrlCreateButton("任務計劃", 12, 58, 128, 44)
	GUICtrlSetFont($btnPlan, 11, 600)
	$btnView = GUICtrlCreateButton("查看任務", 12, 110, 128, 44)
	GUICtrlSetFont($btnView, 11, 600)

	GUICtrlCreateLabel("", 152, 8, 1, 504, $SS_SUNKEN)

	;---------- 任務計劃 檢視 ----------
	$lblNameTitle = GUICtrlCreateLabel("任務名稱：", 180, 62, 90, 22)
	$inpName = GUICtrlCreateInput("", 270, 58, 280, 26)
	$lblTimeTitle = GUICtrlCreateLabel("提醒時間：", 180, 102, 90, 22)
	$inpTime = GUICtrlCreateInput("", 270, 98, 120, 26)
	$lblTimeHint = GUICtrlCreateLabel("格式 HH:MM（24小時制），留空 = 不提醒", 400, 102, 280, 22)
	GUICtrlSetColor($lblTimeHint, 0x808080)
	$btnAdd = GUICtrlCreateButton("新增任務", 270, 140, 120, 32)
	$lblMsg = GUICtrlCreateLabel("", 180, 196, 520, 48)

	;---------- 查看任務 檢視 ----------
	$grpTasks = GUICtrlCreateGroup("全部任務", 172, 40, 560, 432)
	$lstTasks = GUICtrlCreateListView("任務名稱|提醒時間|狀態", 188, 66, 528, 340)
	_GUICtrlListView_SetColumnWidth($lstTasks, 0, 310)
	_GUICtrlListView_SetColumnWidth($lstTasks, 1, 105)
	_GUICtrlListView_SetColumnWidth($lstTasks, 2, 105)
	_GUICtrlListView_SetExtendedListViewStyle($lstTasks, $LVS_EX_FULLROWSELECT)
	$btnDelete = GUICtrlCreateButton("刪除任務", 188, 424, 120, 28)
	$lblCount = GUICtrlCreateLabel("", 560, 428, 160, 22)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	_ShowView(1)

	GUISetState(@SW_SHOW, $hMain)

	AdlibRegister("_CheckReminders", 10000)
	AdlibRegister("_CheckF11", 200)

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
		EndSwitch
	WEnd

	AdlibUnRegister("_CheckReminders")
	AdlibUnRegister("_CheckF11")
	GUIDelete($hMain)
EndFunc   ;==>_Main

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

;---------- 新增任務 ----------
Func _AddTask()
	Local $sName = StringStripWS(GUICtrlRead($inpName), 3)
	If $sName = "" Then
		GUICtrlSetData($lblMsg, "請先輸入任務名稱。")
		Return
	EndIf
	Local $sTime = StringStripWS(GUICtrlRead($inpTime), 3)
	If $sTime <> "" Then
		If Not StringRegExp($sTime, "^(?:[01]\d|2[0-3]):[0-5]\d$") Then
			GUICtrlSetData($lblMsg, "提醒時間格式不正確，請用 HH:MM（例如 14:30），或留空不提醒。")
			Return
		EndIf
	EndIf

	Local $iNext = Int(IniRead($sDataFile, "設定", "NextID", "1"))
	Local $sSection = "Task_" & $iNext
	IniWrite($sDataFile, $sSection, "Name", $sName)
	IniWrite($sDataFile, $sSection, "Time", $sTime)
	IniWrite($sDataFile, $sSection, "Status", "待提醒")
	IniWrite($sDataFile, "設定", "NextID", $iNext + 1)

	GUICtrlSetData($inpName, "")
	GUICtrlSetData($inpTime, "")
	If $sTime = "" Then
		GUICtrlSetData($lblMsg, "已新增任務：「" & $sName & "」（未設定提醒時間）")
	Else
		GUICtrlSetData($lblMsg, "已新增任務：「" & $sName & "」，提醒時間 " & $sTime)
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
		If $sTime = "" Then $sTime = "無"
		Local $sStatus = IniRead($sDataFile, $sSection, "Status", "待提醒")
		ReDim $aTaskIds[$iTaskCount + 1]
		$aTaskIds[$iTaskCount] = $sSection
		_GUICtrlListView_AddItem($lstTasks, $sName)
		_GUICtrlListView_AddSubItem($lstTasks, $iTaskCount, $sTime, 1)
		_GUICtrlListView_AddSubItem($lstTasks, $iTaskCount, $sStatus, 2)
		$iTaskCount += 1
	Next
	GUICtrlSetData($lblCount, "共 " & $iTaskCount & " 個任務")
EndFunc   ;==>_RefreshList

;---------- 刪除任務 ----------
Func _DeleteTask()
	Local $sSel = _GUICtrlListView_GetSelectedIndices($lstTasks)
	If $sSel = "" Then
		GUICtrlSetData($lblCount, "請先選取要刪除的任務。")
		Return
	EndIf
	Local $iItem = Int($sSel)
	If $iItem < 0 Or $iItem >= UBound($aTaskIds) Then Return
	Local $sSection = $aTaskIds[$iItem]
	If $sSection = "" Then Return
	IniDelete($sDataFile, $sSection)
	_RefreshList()
	GUICtrlSetData($lblCount, "已刪除任務（目前 " & $iTaskCount & " 個）")
EndFunc   ;==>_DeleteTask

;---------- 背景偵測提醒（每 10 秒） ----------
Func _CheckReminders()
	Local $iNext = Int(IniRead($sDataFile, "設定", "NextID", "1"))
	Local $sNow = StringFormat("%02d:%02d", Int(@HOUR), Int(@MIN))
	Local $bChanged = False
	For $i = 1 To $iNext - 1
		Local $sSection = "Task_" & $i
		Local $sName = IniRead($sDataFile, $sSection, "Name", "")
		If $sName = "" Then ContinueLoop
		Local $sTime = IniRead($sDataFile, $sSection, "Time", "")
		Local $sStatus = IniRead($sDataFile, $sSection, "Status", "待提醒")
		If $sTime <> "" And $sStatus = "待提醒" And $sNow >= $sTime Then
			_FireNotification($sName, $sTime)
			IniWrite($sDataFile, $sSection, "Status", "已提醒")
			$bChanged = True
		EndIf
	Next
	If $bChanged And $iCurrentView = 2 Then _RefreshList()
EndFunc   ;==>_CheckReminders

;---------- 彈出系統桌面通知（原生托盤通知，右下角系統彈窗，同進程、無外部依賴） ----------
Func _FireNotification($sName, $sTime)
	Local $sNow = StringFormat("%02d:%02d", Int(@HOUR), Int(@MIN))
	; TrayTip(主要文字, 次要文字, 顯示秒數, 圖示類型 1=資訊)
	TrayTip("任務提醒：" & $sName, "時間到！現在 " & $sNow & "（設定 " & $sTime & "）", 10, 1)
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
		$iStyle = BitOR($iStyle, BitOR($WS_CAPTION, $WS_THICKFRAME))
		_WinAPI_SetWindowLong($hMain, $GWL_STYLE, $iStyle)
		_WinAPI_SetWindowPos($hMain, 0, $iPrevX, $iPrevY, $iPrevW, $iPrevH, 0x0020)
		$bFullscreen = False
	EndIf
	GUISetState(@SW_SHOW, $hMain)
EndFunc   ;==>_ToggleFullscreen
