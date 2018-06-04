Local $mGWA2Version = '4.0.0' ; GWA2 Version
; Stability for buying/selling/gold changes, pointer management to avoid stale checks, code cleanup and loads of other features.
; -- Jon, 2018-06-04

#include-once
#RequireAdmin

If @AutoItX64 Then
	MsgBox(16, "Error!", "Please run all bots in 32-bit (x86) mode.")
	Exit
EndIf

#Region Declarations
Local $mKernelHandle
Local $mGWProcHandle
Local $mGWProcessId
Local $mGWWindowHandle
Local $mMemory
Local $mLabels[1][2]
Local $mBase = 0x00DE0000
Local $mASMString
Local $mASMSize
Local $mASMCodeOffset
Local $mGUI = GUICreate('GWA2')
Local $mSkillActivate
Local $mSkillCancel
Local $mSkillComplete
Local $mChatReceive
Local $mLoadFinished
Local $mSkillLogStruct = DllStructCreate('dword;dword;dword;float')
Local $mSkillLogStructPtr = DllStructGetPtr($mSkillLogStruct)
Local $mChatLogStruct = DllStructCreate('dword;wchar[256]')
Local $mChatLogStructPtr = DllStructGetPtr($mChatLogStruct)
GUIRegisterMsg(0x501, 'Event')
Local $mCharname
Local $mBasePointer
Local $mInstanceBasePointer
Local $mItemsBasePointer
Local $mPartyBasePointer
Local $mAgentBase
Local $mMaxAgents
Local $mMyID
Local $mMapLoading
Local $mCurrentTarget
Local $mPing
Local $mMapID
Local $mLoggedIn
Local $mRegion
Local $mLanguage
Local $mSkillBase
Local $mSkillTimer
Local $mBuildNumber
Local $mZoomStill
Local $mZoomMoving
Local $mCurrentStatus
Local $mQueueCounter
Local $mQueueSize
Local $mQueueBase
Local $mTargetLogBase
Local $mStringLogBase
Local $mMapIsLoaded
Local $mEnsureEnglish
Local $mTraderQuoteID
Local $mTraderCostID
Local $mTraderCostValue
Local $mDisableRendering
Local $mAgentCopyCount
Local $mAgentCopyBase
Local $mCharslots
#EndRegion Declarations

#Region ObjectStructInfo
; Item Struct Info
Local $mItemStructStr = 'long id;long agentId;byte unknown1[4];ptr bag;ptr modstruct;long modstructsize;ptr customized;long ModelFileID;byte type;byte IsContainer;short extraId;short value;byte unknown4[2];short interaction;long modelId;ptr modString;byte unknown5[4];ptr NameString;byte unknown6[15];byte quantity;byte equipped;byte unknown7[1];byte slot'
Local $mItemStructSize = 80 ; DllStructGetSize(DllStructCreate($mItemStructStr))
DeclareStructOffsets($mItemStructStr,'mItemStructInfo_')
; Agent Struct Info
Local $mAgentStructStr = 'ptr vtable;byte unknown1[24];byte unknown2[4];ptr NextAgent;byte unknown3[8];long Id;float Z;byte unknown4[8];float BoxHoverWidth;float BoxHoverHeight;byte unknown5[8];float Rotation;byte unknown6[8];long NameProperties;byte unknown7[24];float X;float Y;byte unknown8[8];float NameTagX;float NameTagY;float NameTagZ;byte unknown9[12];long Type;float MoveX;float MoveY;byte unknown10[28];long Owner;byte unknown30[8];long ExtraType;byte unknown11[24];float AttackSpeed;float AttackSpeedModifier;word PlayerNumber;byte unknown12[6];ptr Equip;byte unknown13[10];byte Primary;byte Secondary;byte Level;byte Team;byte unknown14[6];float EnergyPips;byte unknown[4];float EnergyPercent;long MaxEnergy;byte unknown15[4];float HPPips;byte unknown16[4];float HP;long MaxHP;long Effects;byte unknown17[4];byte Hex;byte unknown18[18];long ModelState;long TypeMap;byte unknown19[16];long InSpiritRange;byte unknown20[16];long LoginNumber;float ModelMode;byte unknown21[4];long ModelAnimation;byte unknown22[32];byte LastStrike;byte Allegiance;word WeaponType;word Skill;byte unknown23[4];word WeaponItemId;word OffhandItemId'
Local $mAgentStructSize = 448 ; DllStructGetSize(DllStructCreate($mAgentStructStr))
DeclareStructOffsets($mAgentStructStr,'mAgentStructInfo_')
; Bag Struct Info
Local $mBagStructStr = 'byte unknown1[4];long index;long id;ptr containerItem;long ItemsCount;ptr bagArray;ptr itemArray;long fakeSlots;long slots'
Local $mBagStructSize = 36 ; DllStructGetSize(DllStructCreate($mBagStructStr))
DeclareStructOffsets($mBagStructStr,'mBagStructInfo_')
; Skill Bar Struct info
Local $mSkillBarStructStr = 'long AgentId;long AdrenalineA1;long AdrenalineB1;dword Recharge1;dword Id1;dword Event1;long AdrenalineA2;long AdrenalineB2;dword Recharge2;dword Id2;dword Event2;long AdrenalineA3;long AdrenalineB3;dword Recharge3;dword Id3;dword Event3;long AdrenalineA4;long AdrenalineB4;dword Recharge4;dword Id4;dword Event4;long AdrenalineA5;long AdrenalineB5;dword Recharge5;dword Id5;dword Event5;long AdrenalineA6;long AdrenalineB6;dword Recharge6;dword Id6;dword Event6;long AdrenalineA7;long AdrenalineB7;dword Recharge7;dword Id7;dword Event7;long AdrenalineA8;long AdrenalineB8;dword Recharge8;dword Id8;dword Event8;dword disabled;byte unknown[8];dword Casting'
Local $mSkillBarStructSize = DllStructGetSize(DllStructCreate($mSkillBarStructStr))
DeclareStructOffsets($mSkillBarStructStr,'mSkillBarStructInfo_')
; Skill Struct info
Local $mSkillStructStr = 'long ID;byte Unknown1[4];long campaign;long Type;long Special;long ComboReq;long Effect1;long Condition;long Effect2;long WeaponReq;byte Profession;byte Attribute;byte Unknown2[2];long PvPID;byte Combo;byte Target;byte unknown3;byte EquipType;byte Unknown4;byte Energy;byte Unknown5[2];dword Adrenaline;float Activation;float Aftercast;long Duration0;long Duration15;long Recharge;byte Unknown6[12];long Scale0;long Scale15;long BonusScale0;long BonusScale15;float AoERange;float ConstEffect;byte unknown7[44]'
Local $mSkillStructSize = DllStructGetSize(DllStructCreate($mSkillStructStr))
DeclareStructOffsets($mSkillStructStr,'mSkillStructInfo_')

Func DeclareStructOffsets($aStructString,$aVarPrefix) ; NOTE: Struct elements MUST have names for this function to work properly!
	Local $lSplit = StringSplit($aStructString,';'), $lSplit2,$lElementName,$lElementType,$lElementOffset=0,$lElementSize=1, $lArrayMatch, $lDebug=0
	Local $lDebugArr=''
	For $i=1 to $lSplit[0]
		$lSplit2 = StringSplit($lSplit[$i],' ') ; Split on type and name
		$lArrayMatch = StringRegExp($lSplit[$i],"\[([0-9]+)\]$",2) ; Is this type an array of values?
		$lElementType = StringRegExpReplace($lSplit2[1],"\[[0-9]+\]$",'') ; byte[10] = byte (remove array declaration)
		$lElementName = StringRegExpReplace(($lSplit2[0] > 1 ? $lSplit2[2] : ''),"\[[0-9]+\]$",'') ; unknown2[4] = unknown2 (remove array declaration)
		; Calculate offset.
		$lElementSize=1
		Switch $lElementType ; Add other case statements when relevent
			Case 'long','ptr','float','dword'
				$lElementSize=4
			Case 'short','word','wchar'
				$lElementSize=2
		EndSwitch
		While Mod( $lElementOffset , $lElementSize ) > 0 ; Make sure the offset is valid for this size i.e. long datatype needs to be within multiple of 4 (e.g. 42 is invalid, 44 is OK)
			$lElementOffset+=1		
		WEnd 
		If UBound($lArrayMatch) Then ; This is an array of values.
			$lElementSize *= Number($lArrayMatch[1]) ; Multiply by array count.
			$lElementType &= $lArrayMatch[0] ; Add the array count to the type field.
		EndIf
		If $lElementName Then ; Element has a name - declare it as a global variable using the prefix.
			Local $lElementArr[2] = [$lElementType,$lElementOffset]
			Assign($aVarPrefix&$lElementName,$lElementArr,2) ; Assign this definition to global variable. Used later for GetItemProperty etc.
			If $lDebug Then $lDebugArr &= $aVarPrefix&$lElementName&' , '&$lElementType&' , '&$lElementOffset&@CRLF
		EndIf
		$lElementOffset+=$lElementSize
	Next
	If $lDebug Then MsgBox(0,'DeclareStructOffsets for '&$aVarPrefix,$lDebugArr)
EndFunc
#EndRegion

#EndRegion
#Region CommandStructs
Local $mUseSkill = DllStructCreate('ptr;dword;dword;dword')
Local $mUseSkillPtr = DllStructGetPtr($mUseSkill)

Local $mMove = DllStructCreate('ptr;float;float;float')
Local $mMovePtr = DllStructGetPtr($mMove)

Local $mChangeTarget = DllStructCreate('ptr;dword')
Local $mChangeTargetPtr = DllStructGetPtr($mChangeTarget)

Local $mPacket = DllStructCreate('ptr;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword')
Local $mPacketPtr = DllStructGetPtr($mPacket)

Local $mSellItem = DllStructCreate('ptr;dword;dword')
Local $mSellItemPtr = DllStructGetPtr($mSellItem)

Local $mAction = DllStructCreate('ptr;dword;dword')
Local $mActionPtr = DllStructGetPtr($mAction)

Local $mToggleLanguage = DllStructCreate('ptr;dword')
Local $mToggleLanguagePtr = DllStructGetPtr($mToggleLanguage)

Local $mUseHeroSkill = DllStructCreate('ptr;dword;dword;dword')
Local $mUseHeroSkillPtr = DllStructGetPtr($mUseHeroSkill)

Local $mBuyItem = DllStructCreate('ptr;dword;dword;dword')
Local $mBuyItemPtr = DllStructGetPtr($mBuyItem)

Local $mSendChat = DllStructCreate('ptr;dword')
Local $mSendChatPtr = DllStructGetPtr($mSendChat)

Local $mWriteChat = DllStructCreate('ptr')
Local $mWriteChatPtr = DllStructGetPtr($mWriteChat)

Local $mRequestQuote = DllStructCreate('ptr;dword')
Local $mRequestQuotePtr = DllStructGetPtr($mRequestQuote)

Local $mRequestQuoteSell = DllStructCreate('ptr;dword')
Local $mRequestQuoteSellPtr = DllStructGetPtr($mRequestQuoteSell)

Local $mTraderBuy = DllStructCreate('ptr')
Local $mTraderBuyPtr = DllStructGetPtr($mTraderBuy)

Local $mTraderSell = DllStructCreate('ptr')
Local $mTraderSellPtr = DllStructGetPtr($mTraderSell)

Local $mSalvage = DllStructCreate('ptr;dword;dword;dword')
Local $mSalvagePtr = DllStructGetPtr($mSalvage)

Local $mSetAttributes = DllStructCreate("ptr;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword;dword")
Local $mSetAttributesPtr = DllStructGetPtr($mSetAttributes)

Local $mMakeAgentArray = DllStructCreate('ptr;dword')
Local $mMakeAgentArrayPtr = DllStructGetPtr($mMakeAgentArray)

Local $mChangeStatus = DllStructCreate('ptr;dword')
Local $mChangeStatusPtr = DllStructGetPtr($mChangeStatus)
#EndRegion CommandStructs

#Region Headers
$SalvageMaterialsHeader = 0x7F
$SalvageModHeader = 0x80
$IdentifyItemHeader = 0x71
$EquipItemHeader = 0x36
$UseItemHeader = 0x83
$PickUpItemHeader = 0x45
$DropItemHeader = 0x32
$MoveItemHeader = 0x77
$MoveItemExHeader = $MoveItemHeader + 0x3
$AcceptAllItemsHeader = 0x78
$DropGoldHeader = 0x35
$ChangeGoldHeader = 0x81
$AddHeroHeader = 0x23
$KickHeroHeader = 0x24
$AddNpcHeader = 0xA5
$KickNpcHeader = 0xAE
$CommandHeroHeader = 0x1E
$CommandAllHeader = 0x1F
$LockHeroTargetHeader = 0x18
$SetHeroAggressionHeader = 0x17
$ChangeHeroSkillSlotStateHeader = 0x1C
$SetDisplayedTitleHeader = 0x5D
$RemoveDisplayedTitleHeader = 0x5E
$GoPlayerHeader = 0x39
$GoNPCHeader = 0x3F
$GoSignpostHeader = 0x57
$AttackHeader = 0x2C
$MoveMapHeader = 0xB7
$ReturnToOutpostHeader = 0xAD
$EnterChallengeHeader = 0xAB
$TravelGHHeader = 0xB6
$LeaveGHHeader = 0xB8
$AbandonQuestHeader = 0x12
$CallTargetHeader = 0x28
$CancelActionHeader = 0x2E
$OpenChestHeader = 0x59
$DropBuffHeader = 0x2F
$LeaveGroupHeader = 0xA8
$SwitchModeHeader = 0xA1
$DonateFactionHeader = 0x3B
$DialogHeader = 0x41
$SkipCinematicHeader = 0x68
$SetSkillbarSkillHeader = 0x61
$LoadSkillbarHeader = 0x62
$ChangeSecondProfessionHeader = 0x47
$SendChatHeader = 0x69
$SetAttributesHeader = 0x10
#EndRegion Headers

#Region Memory
;~ Description: Internal use only.
Func MemoryOpen($aPID)
	$mKernelHandle = DllOpen('kernel32.dll')
	Local $lOpenProcess = DllCall($mKernelHandle, 'int', 'OpenProcess', 'int', 0x1F0FFF, 'int', 1, 'int', $aPID)
	$mGWProcHandle = $lOpenProcess[0]
EndFunc   ;==>MemoryOpen

;~ Description: Internal use only.
Func MemoryClose()
	DllCall($mKernelHandle, 'int', 'CloseHandle', 'int', $mGWProcHandle)
	DllClose($mKernelHandle)
EndFunc   ;==>MemoryClose

;~ Description: Internal use only.
Func WriteBinary($aBinaryString, $aAddress)
	Local $lData = DllStructCreate('byte[' & 0.5 * StringLen($aBinaryString) & ']'), $i
	For $i = 1 To DllStructGetSize($lData)
		DllStructSetData($lData, 1, Dec(StringMid($aBinaryString, 2 * $i - 1, 2)), $i)
	Next
	DllCall($mKernelHandle, 'int', 'WriteProcessMemory', 'int', $mGWProcHandle, 'ptr', $aAddress, 'ptr', DllStructGetPtr($lData), 'int', DllStructGetSize($lData), 'int', 0)
EndFunc   ;==>WriteBinary

;~ Description: Internal use only.
Func MemoryWrite($aAddress, $aData, $aType = 'dword')
	Local $lBuffer = DllStructCreate($aType)
	DllStructSetData($lBuffer, 1, $aData)
	DllCall($mKernelHandle, 'int', 'WriteProcessMemory', 'int', $mGWProcHandle, 'int', $aAddress, 'ptr', DllStructGetPtr($lBuffer), 'int', DllStructGetSize($lBuffer), 'int', '')
EndFunc   ;==>MemoryWrite
Func MemoryRead($aAddress, $aType = 'dword') ;~ Description: Internal use only.
	Local $lStruct = MemoryReadStruct($aAddress,$aType)
	Local $data = DllStructGetData($lStruct, 1)
	$lStruct = ''
	Return $data
EndFunc   ;==>MemoryRead
Func MemoryReadPtr($aAddress, $aOffset, $aType = 'dword') ;~ Description: Internal use only. Steps through each address $aOffset to get the final $aAddress.
	Local $lPointerCount = UBound($aOffset) - 2, $lBuffer = DllStructCreate('ptr'), $lPtr = DllStructGetPtr($lBuffer), $lSize = DllStructGetSize($lBuffer)
	For $i = 0 To $lPointerCount
		If $i > 0 And $aOffset[$i] = 0 Then ContinueLoop
		$aAddress += $aOffset[$i]
		DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $aAddress, 'ptr', $lPtr, 'int', $lSize, 'int', '')
		$aAddress = DllStructGetData($lBuffer, 1)
		If $aAddress == 0 Then
			Local $lData[2] = [0, 0]
			Return $lData
		EndIf
	Next

	$aAddress += $aOffset[$lPointerCount + 1]
	$lBuffer = DllStructCreate($aType)
	DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $aAddress, 'ptr', DllStructGetPtr($lBuffer), 'int', DllStructGetSize($lBuffer), 'int', '')
	Local $lData[2] = [$aAddress, DllStructGetData($lBuffer, 1)]
	$lBuffer = ''
	Return $lData
EndFunc   ;==>MemoryReadPtr
Func MemoryReadStruct($aAddress, $aStruct = 'dword') ;~ Description: Reads consecutive values from memory to buffer struct. Author: 4D1. Referenced by MemoryRead
   If Not IsDllStruct($aStruct) Then $aStruct = DllStructCreate($aStruct)
   DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $aAddress, 'ptr', DllStructGetPtr($aStruct), 'int', DllStructGetSize($aStruct), 'int', '')
   Return $aStruct
EndFunc   ;==>MemoryReadStruct
;~ Description: Internal use only.
Func SwapEndian($aHex)
	Return StringMid($aHex, 7, 2) & StringMid($aHex, 5, 2) & StringMid($aHex, 3, 2) & StringMid($aHex, 1, 2)
EndFunc   ;==>SwapEndian
#EndRegion Memory

#Region Initialisation
;~ Description: Returns a list of logged characters
Func GetLoggedCharNames()
	Local $array = ScanGW()
	If $array[0] <= 0 Then Return ''
	Local $ret = $array[1]
	For $i=2 To $array[0]
		$ret &= "|"
		$ret &= $array[$i]
	Next
	Return $ret
EndFunc

;~ Description: Returns an array of logged characters of gw windows (at pos 0 there is the size of the array)
Func ScanGW()
	Local $lProcessList = processList("gw.exe")
	Local $lReturnArray[1] = [0]
	Local $lPid

	For $i = 1 To $lProcessList[0][0]
		MemoryOpen($lProcessList[$i][1])

		If $mGWProcHandle Then
			$lReturnArray[0] += 1
			ReDim $lReturnArray[$lReturnArray[0] + 1]
			$lReturnArray[$lReturnArray[0]] = ScanForCharname()
		EndIf

		MemoryClose()

		$mGWProcHandle = 0
	Next

	Return $lReturnArray
EndFunc

Func GetHwnd($aProc)
	Local $wins = WinList()
	For $i = 1 To UBound($wins)-1
		If (WinGetProcess($wins[$i][1]) == $aProc) And (BitAND(WinGetState($wins[$i][1]), 2)) Then Return $wins[$i][1]
	Next
EndFunc
Func GetItemsBasePtr()
	Local $lOffset[4] = [0, 0x18, 0x40, 0xB8]
	Local $lReturn = MemoryReadPtr($mBasePointer, $lOffset,'ptr')
	Return $lReturn[1]
EndFunc
Func GetInstanceBasePtr()
	Local $lOffset[3] = [0, 0x18, 0x2C] 
	Local $lReturn = MemoryReadPtr($mBasePointer, $lOffset, 'ptr')
	Return $lReturn[1]
EndFunc
Func GetPartyBasePtr()
	Local $lOffset[4] = [0, 0x18, 0x4C,0x54]
	Local $lReturn = MemoryReadPtr($mBasePointer, $lOffset,'ptr')
	Return $lReturn[1]
EndFunc
Func AssignBasePointers(); Used for internal pointer reads; only possible once we know what mBasePointer is.
	Local $lOffset, $lReturn
	; GetInstanceBasePtr() avoids having to call offsets [0,0x18,0x2C] every time. Used for getting details like foes killed or title progress.
	$mInstanceBasePointer = GetInstanceBasePtr()
	; GetItemsBasePtr() avoids having to call offsets [0, 0x18, 0x40, 0xB8] every time. Used pretty much any time you want info about an item.
	$mItemsBasePointer = GetItemsBasePtr()
	; GetPartyBasePtr() avoids having to call offsets [0,0x18,0x4C,0x54] every time. Used for any hero related functions.
	$mPartyBasePointer = GetPartyBasePtr()
EndFunc
;~ Description: Injects GWA² into the game client. 3rd and 4th arguments are here for legacy purposes
Func Initialize($aGW, $bChangeTitle = True, $notUsed1 = 0, $notUsed2 = 0)
	If IsString($aGW) Then
		Local $lProcessList = processList("gw.exe")
		For $i = 1 To $lProcessList[0][0]
			$mGWProcessId = $lProcessList[$i][1]
			$mGWWindowHandle = GetHwnd($mGWProcessId)
			MemoryOpen($mGWProcessId)
			If $mGWProcHandle Then
				If StringRegExp(ScanForCharname(), $aGW) = 1 Then ExitLoop
			EndIf
			MemoryClose()
			$mGWProcHandle = 0
		Next
	ElseIf $aGW <> 0 Then
		$mGWProcessId = $aGW
		$mGWWindowHandle = GetHwnd($mGWProcessId)
		MemoryOpen($aGW)
		ScanForCharname()
	EndIf

	If $mGWProcHandle = 0 Then Return False

	Scan()

	$mBasePointer = MemoryRead(GetScannedAddress('ScanBasePointer', -3))
	AssignBasePointers() ; Used for internal pointer reads; only possible once we know what mBasePointer is. See function definition for more info.
	SetValue('BasePointer', '0x' & Hex($mBasePointer, 8))
	$mAgentBase = MemoryRead(GetScannedAddress('ScanAgentBase', 13))
	SetValue('AgentBase', '0x' & Hex($mAgentBase, 8))
	$mMaxAgents = $mAgentBase + 8
	SetValue('MaxAgents', '0x' & Hex($mMaxAgents, 8))
	$mMyID = $mAgentBase - 84
	SetValue('MyID', '0x' & Hex($mMyID, 8))
	$mMapLoading = $mAgentBase - 240
	$mCurrentTarget = $mAgentBase - 1280
	SetValue('PacketLocation', '0x' & Hex(MemoryRead(GetScannedAddress('ScanBaseOffset', -3)), 8))
	$mPing = MemoryRead(GetScannedAddress('ScanPing', 7))
	$mMapID = MemoryRead(GetScannedAddress('ScanMapID', 71))
	$mLoggedIn = MemoryRead(GetScannedAddress('ScanLoggedIn', -3)) + 4
	$mRegion = MemoryRead(GetScannedAddress('ScanRegion', 8))
	$mLanguage = MemoryRead(GetScannedAddress('ScanLanguage', 8)) + 12
	$mSkillBase = MemoryRead(GetScannedAddress('ScanSkillBase', 9))
	$mSkillTimer = MemoryRead(GetScannedAddress('ScanSkillTimer', -3))
	$mBuildNumber = MemoryRead(GetScannedAddress('ScanBuildNumber', 0x54))
	$mZoomStill = GetScannedAddress("ScanZoomStill", -1)
	$mZoomMoving = GetScannedAddress("ScanZoomMoving", 5)
	$mCurrentStatus = MemoryRead(GetScannedAddress('ScanChangeStatusFunction', -3))
	$mCharslots = MemoryRead(GetScannedAddress('ScanCharslots', 22))

	Local $lTemp
	$lTemp = GetScannedAddress('ScanEngine', -16)
	SetValue('MainStart', '0x' & Hex($lTemp, 8))
	SetValue('MainReturn', '0x' & Hex($lTemp + 5, 8))
	SetValue('RenderingMod', '0x' & Hex($lTemp + 116, 8))
	SetValue('RenderingModReturn', '0x' & Hex($lTemp + 138, 8))
	$lTemp = GetScannedAddress('ScanTargetLog', 1)
	SetValue('TargetLogStart', '0x' & Hex($lTemp, 8))
	SetValue('TargetLogReturn', '0x' & Hex($lTemp + 5, 8))
	$lTemp = GetScannedAddress('ScanSkillLog', 1)
	SetValue('SkillLogStart', '0x' & Hex($lTemp, 8))
	SetValue('SkillLogReturn', '0x' & Hex($lTemp + 5, 8))
	$lTemp = GetScannedAddress('ScanSkillCompleteLog', -4)
	SetValue('SkillCompleteLogStart', '0x' & Hex($lTemp, 8))
	SetValue('SkillCompleteLogReturn', '0x' & Hex($lTemp + 5, 8))
	$lTemp = GetScannedAddress('ScanSkillCancelLog', 5)
	SetValue('SkillCancelLogStart', '0x' & Hex($lTemp, 8))
	SetValue('SkillCancelLogReturn', '0x' & Hex($lTemp + 6, 8))
	$lTemp = GetScannedAddress('ScanChatLog', 18)
	SetValue('ChatLogStart', '0x' & Hex($lTemp, 8))
	SetValue('ChatLogReturn', '0x' & Hex($lTemp + 6, 8))
	$lTemp = GetScannedAddress('ScanTraderHook', -7)
	SetValue('TraderHookStart', '0x' & Hex($lTemp, 8))
	SetValue('TraderHookReturn', '0x' & Hex($lTemp + 5, 8))
	$lTemp = GetScannedAddress('ScanStringFilter1', 29)
	SetValue('StringFilter1Start', '0x' & Hex($lTemp, 8))
	SetValue('StringFilter1Return', '0x' & Hex($lTemp + 5, 8))
	$lTemp = GetScannedAddress('ScanStringFilter2', 97)
	SetValue('StringFilter2Start', '0x' & Hex($lTemp, 8))
	SetValue('StringFilter2Return', '0x' & Hex($lTemp + 5, 8))
	SetValue('StringLogStart', '0x' & Hex(GetScannedAddress('ScanStringLog', 35), 8))
	SetValue('LoadFinishedStart', '0x' & Hex(GetScannedAddress('ScanLoadFinished', 79), 8))
	SetValue('PostMessage', '0x' & Hex(MemoryRead(GetScannedAddress('ScanPostMessage', 11)), 8))
	SetValue('Sleep', MemoryRead(MemoryRead(GetValue('ScanSleep') + 8) + 3))
	SetValue('SalvageFunction', MemoryRead(GetValue('ScanSalvageFunction') + 8) - 18)
	SetValue('SalvageGlobal', MemoryRead(MemoryRead(GetValue('ScanSalvageGlobal') + 8) + 1))
	SetValue('MoveFunction', '0x' & Hex(GetScannedAddress('ScanMoveFunction', 1), 8))
	SetValue('UseSkillFunction', '0x' & Hex(GetScannedAddress('ScanUseSkillFunction', 1), 8))
	SetValue('ChangeTargetFunction', '0x' & Hex(GetScannedAddress('ScanChangeTargetFunction', -119), 8))
	SetValue('WriteChatFunction', '0x' & Hex(GetScannedAddress('ScanWriteChatFunction', 1), 8))
	SetValue('SellItemFunction', '0x' & Hex(GetScannedAddress('ScanSellItemFunction', -85), 8))
	SetValue('PacketSendFunction', '0x' & Hex(GetScannedAddress('ScanPacketSendFunction', 1), 8))
	SetValue('ActionBase', '0x' & Hex(MemoryRead(GetScannedAddress('ScanActionBase', -9)), 8))
	SetValue('ActionFunction', '0x' & Hex(GetScannedAddress('ScanActionFunction', -5), 8))
	SetValue('UseHeroSkillFunction', '0x' & Hex(GetScannedAddress('ScanUseHeroSkillFunction', -0xA1), 8))
	SetValue('BuyItemFunction', '0x' & Hex(GetScannedAddress('ScanBuyItemFunction', 1), 8))
	SetValue('RequestQuoteFunction', '0x' & Hex(GetScannedAddress('ScanRequestQuoteFunction', -2), 8))
	SetValue('TraderFunction', '0x' & Hex(GetScannedAddress('ScanTraderFunction', -71), 8))
	SetValue('ClickToMoveFix', '0x' & Hex(GetScannedAddress("ScanClickToMoveFix", 30), 8))
	SetValue('ChangeStatusFunction', '0x' & Hex(GetScannedAddress("ScanChangeStatusFunction", 12), 8))

	SetValue('QueueSize', '0x00000010')
	SetValue('SkillLogSize', '0x00000010')
	SetValue('ChatLogSize', '0x00000010')
	SetValue('TargetLogSize', '0x00000200')
	SetValue('StringLogSize', '0x00000200')
	SetValue('CallbackEvent', '0x00000501')

	ModifyMemory()

	$mQueueCounter = MemoryRead(GetValue('QueueCounter'))
	$mQueueSize = GetValue('QueueSize') - 1
	$mQueueBase = GetValue('QueueBase')
	$mTargetLogBase = GetValue('TargetLogBase')
	$mStringLogBase = GetValue('StringLogBase')
	$mMapIsLoaded = GetValue('MapIsLoaded')
	$mEnsureEnglish = GetValue('EnsureEnglish')
	$mTraderQuoteID = GetValue('TraderQuoteID')
	$mTraderCostID = GetValue('TraderCostID')
	$mTraderCostValue = GetValue('TraderCostValue')
	$mDisableRendering = GetValue('DisableRendering')
	$mAgentCopyCount = GetValue('AgentCopyCount')
	$mAgentCopyBase = GetValue('AgentCopyBase')

	;EventSystem
	MemoryWrite(GetValue('CallbackHandle'), $mGUI)

	DllStructSetData($mUseSkill, 1, GetValue('CommandUseSkill'))
	DllStructSetData($mMove, 1, GetValue('CommandMove'))
	DllStructSetData($mChangeTarget, 1, GetValue('CommandChangeTarget'))
	DllStructSetData($mPacket, 1, GetValue('CommandPacketSend'))
	DllStructSetData($mSellItem, 1, GetValue('CommandSellItem'))
	DllStructSetData($mAction, 1, GetValue('CommandAction'))
	DllStructSetData($mToggleLanguage, 1, GetValue('CommandToggleLanguage'))
	DllStructSetData($mUseHeroSkill, 1, GetValue('CommandUseHeroSkill'))
	DllStructSetData($mBuyItem, 1, GetValue('CommandBuyItem'))
	DllStructSetData($mSendChat, 1, GetValue('CommandSendChat'))
	DllStructSetData($mSendChat, 2, $SendChatHeader)
	DllStructSetData($mWriteChat, 1, GetValue('CommandWriteChat'))
	DllStructSetData($mRequestQuote, 1, GetValue('CommandRequestQuote'))
	DllStructSetData($mRequestQuoteSell, 1, GetValue('CommandRequestQuoteSell'))
	DllStructSetData($mTraderBuy, 1, GetValue('CommandTraderBuy'))
	DllStructSetData($mTraderSell, 1, GetValue('CommandTraderSell'))
	DllStructSetData($mSalvage, 1, GetValue('CommandSalvage'))
	DllStructSetData($mSetAttributes, 1, GetValue('CommandPacketSend'))
	DllStructSetData($mSetAttributes, 2, 0x90)
	DllStructSetData($mSetAttributes, 3, $SetAttributesHeader)
	DllStructSetData($mMakeAgentArray, 1, GetValue('CommandMakeAgentArray'))
	DllStructSetData($mChangeStatus, 1, GetValue('CommandChangeStatus'))

	If $bChangeTitle Then WinSetTitle($mGWWindowHandle, '', 'Guild Wars - ' & GetCharname())
	Return $mGWWindowHandle
EndFunc   ;==>Initialize

;~ Description: Internal use only.
Func GetValue($aKey)
	For $i = 1 To $mLabels[0][0]
		If $mLabels[$i][0] = $aKey Then Return Number($mLabels[$i][1])
	Next
	Return -1
EndFunc   ;==>GetValue

;~ Description: Internal use only.
Func SetValue($aKey, $aValue)
	$mLabels[0][0] += 1
	ReDim $mLabels[$mLabels[0][0] + 1][2]
	$mLabels[$mLabels[0][0]][0] = $aKey
	$mLabels[$mLabels[0][0]][1] = $aValue
EndFunc   ;==>SetValue

;~ Description: Internal use only.
Func Scan()
	$mASMSize = 0
	$mASMCodeOffset = 0
	$mASMString = ''

	_('MainModPtr/4')
	_('ScanBasePointer:')
	AddPattern('85C0750F8BCE')
	_('ScanAgentBase:')
	AddPattern('568BF13BF07204')
	_('ScanEngine:')
	AddPattern('5356DFE0F6C441')
	_('ScanLoadFinished:')
	AddPattern('894DD88B4D0C8955DC8B')
	_('ScanPostMessage:')
	AddPattern('6A00680080000051FF15')
	_('ScanTargetLog:')
	AddPattern('5356578BFA894DF4E8')
	_('ScanChangeTargetFunction:')
	AddPattern('33C03BDA0F95C033')
	_('ScanMoveFunction:')
	AddPattern('558BEC83EC2056578BF98D4DF0')
	_('ScanPing:')
	AddPattern('C390908BD1B9')
	_('ScanMapID:')
	AddPattern('B07F8D55')
	_('ScanLoggedIn:')
	AddPattern('85C07411B807')
	_('ScanRegion:')
	AddPattern('83F9FD7406')
	_('ScanLanguage:')
	AddPattern('C38B75FC8B04B5')
	_('ScanUseSkillFunction:')
	AddPattern('558BEC83EC1053568BD9578BF2895DF0')
	_('ScanChangeTargetFunction:')
	AddPattern('33C03BDA0F95C033')
	_('ScanPacketSendFunction:')
	AddPattern('558BEC83EC2C5356578BF985')
	_('ScanBaseOffset:')
	AddPattern('5633F63BCE740E5633D2')
	_('ScanWriteChatFunction:')
	AddPattern('558BEC5153894DFC8B4D0856578B')
	_('ScanSkillLog:')
	AddPattern('408946105E5B5D')
	_('ScanSkillCompleteLog:')
	AddPattern('741D6A006A40')
	_('ScanSkillCancelLog:')
	AddPattern('85C0741D6A006A42')
	_('ScanChatLog:')
	AddPattern('8B45F48B138B4DEC50')
	_('ScanSellItemFunction:')
	AddPattern('8B4D2085C90F858E')
	_('ScanStringLog:')
	AddPattern('893E8B7D10895E04397E08')
	_('ScanStringFilter1:')
	AddPattern('5E8BE55DC204008B55088BCE52')
	_('ScanStringFilter2:')
	AddPattern('D85DF85F5E5BDFE0F6C441')
	_('ScanActionFunction:')
	AddPattern('8B7D0883FF098BF175116876010000')
	_('ScanActionBase:')
	AddPattern('8B4208A80175418B4A08')
	_('ScanSkillBase:')
	AddPattern('8D04B65EC1E00505')
	_('ScanUseHeroSkillFunction:')
	AddPattern('8D0C765F5E8B')
	_('ScanBuyItemFunction:')
	AddPattern('558BEC81ECC000000053568B75085783FE108BFA8BD97614')
	_('ScanRequestQuoteFunction:')
	AddPattern('81EC9C00000053568B')
	_('ScanTraderFunction:')
	AddPattern('8B45188B551085')
	_('ScanTraderHook:')
	AddPattern('8955FC6A008D55F8B9BA')
	_('ScanSleep:')
	AddPattern('5F5E5B741A6860EA0000')
	_('ScanSalvageFunction:')
	AddPattern('8BFA8BD9897DF0895DF4')
	_('ScanSalvageGlobal:')
	AddPattern('8B018B4904A3')
	_('ScanSkillTimer:')
	AddPattern('85c974158bd62bd183fa64')
	_('ScanClickToMoveFix:')
	AddPattern('568BF1578B460883F80F')
	_('ScanZoomStill:')
	AddPattern('3B448BCB')
	_('ScanZoomMoving:')
	AddPattern('50EB116800803B448BCE')
	_('ScanBuildNumber:')
	AddPattern('8D8500FCFFFF8D')
	_('ScanChangeStatusFunction:')
	AddPattern('C390909090909090909090568BF183FE04')
	_('ScanCharslots:')
	AddPattern('8B551041897E38897E3C897E34897E48897E4C890D')

	_('ScanProc:')
	_('pushad')
	_('mov ecx,401000')
	_('mov esi,ScanProc')
	_('ScanLoop:')
	_('inc ecx')
	_('mov al,byte[ecx]')
	_('mov edx,ScanBasePointer')

	_('ScanInnerLoop:')
	_('mov ebx,dword[edx]')
	_('cmp ebx,-1')
	_('jnz ScanContinue')
	_('add edx,50')
	_('cmp edx,esi')
	_('jnz ScanInnerLoop')
	_('cmp ecx,900000')
	_('jnz ScanLoop')
	_('jmp ScanExit')

	_('ScanContinue:')
	_('lea edi,dword[edx+ebx]')
	_('add edi,C')
	_('mov ah,byte[edi]')
	_('cmp al,ah')
	_('jz ScanMatched')
	_('mov dword[edx],0')
	_('add edx,50')
	_('cmp edx,esi')
	_('jnz ScanInnerLoop')
	_('cmp ecx,900000')
	_('jnz ScanLoop')
	_('jmp ScanExit')

	_('ScanMatched:')
	_('inc ebx')
	_('mov edi,dword[edx+4]')
	_('cmp ebx,edi')
	_('jz ScanFound')
	_('mov dword[edx],ebx')
	_('add edx,50')
	_('cmp edx,esi')
	_('jnz ScanInnerLoop')
	_('cmp ecx,900000')
	_('jnz ScanLoop')
	_('jmp ScanExit')

	_('ScanFound:')
	_('lea edi,dword[edx+8]')
	_('mov dword[edi],ecx')
	_('mov dword[edx],-1')
	_('add edx,50')
	_('cmp edx,esi')
	_('jnz ScanInnerLoop')
	_('cmp ecx,900000')
	_('jnz ScanLoop')

	_('ScanExit:')
	_('popad')
	_('retn')

	Local $lScanMemory = MemoryRead($mBase, 'ptr')

	If $lScanMemory = 0 Then
		$mMemory = DllCall($mKernelHandle, 'ptr', 'VirtualAllocEx', 'handle', $mGWProcHandle, 'ptr', 0, 'ulong_ptr', $mASMSize, 'dword', 0x1000, 'dword', 0x40)
		$mMemory = $mMemory[0]
		MemoryWrite($mBase, $mMemory)
	Else
		$mMemory = $lScanMemory
	EndIf

	CompleteASMCode()

	If $lScanMemory = 0 Then
		WriteBinary($mASMString, $mMemory + $mASMCodeOffset)
		Local $lThread = DllCall($mKernelHandle, 'int', 'CreateRemoteThread', 'int', $mGWProcHandle, 'ptr', 0, 'int', 0, 'int', GetLabelInfo('ScanProc'), 'ptr', 0, 'int', 0, 'int', 0)
		$lThread = $lThread[0]
		Local $lResult
		Do
			$lResult = DllCall($mKernelHandle, 'int', 'WaitForSingleObject', 'int', $lThread, 'int', 50)
		Until $lResult[0] <> 258
		DllCall($mKernelHandle, 'int', 'CloseHandle', 'int', $lThread)
	EndIf
EndFunc   ;==>Scan

;~ Description: Internal use only.
Func AddPattern($aPattern)
	Local $lSize = Int(0.5 * StringLen($aPattern))
	$mASMString &= '00000000' & SwapEndian(Hex($lSize, 8)) & '00000000' & $aPattern
	$mASMSize += $lSize + 12
	For $i = 1 To 68 - $lSize
		$mASMSize += 1
		$mASMString &= '00'
	Next
EndFunc   ;==>AddPattern

;~ Description: Internal use only.
Func GetScannedAddress($aLabel, $aOffset)
	Return MemoryRead(GetLabelInfo($aLabel) + 8) - MemoryRead(GetLabelInfo($aLabel) + 4) + $aOffset
EndFunc   ;==>GetScannedAddress

;~ Description: Internal use only.
Func ScanForCharname()
	Local $lCharNameCode = BinaryToString('0x90909066C705')
	Local $lCurrentSearchAddress = 0x00401000
	Local $lMBI[7], $lMBIBuffer = DllStructCreate('dword;dword;dword;dword;dword;dword;dword')
	Local $lSearch, $lTmpMemData, $lTmpAddress, $lTmpBuffer = DllStructCreate('ptr'), $i

	While $lCurrentSearchAddress < 0x00900000
		Local $lMBI[7]
		DllCall($mKernelHandle, 'int', 'VirtualQueryEx', 'int', $mGWProcHandle, 'int', $lCurrentSearchAddress, 'ptr', DllStructGetPtr($lMBIBuffer), 'int', DllStructGetSize($lMBIBuffer))
		For $i = 0 To 6
			$lMBI[$i] = StringStripWS(DllStructGetData($lMBIBuffer, ($i + 1)), 3)
		Next

		If $lMBI[4] = 4096 Then
			Local $lBuffer = DllStructCreate('byte[' & $lMBI[3] & ']')
			DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $lCurrentSearchAddress, 'ptr', DllStructGetPtr($lBuffer), 'int', DllStructGetSize($lBuffer), 'int', '')

			$lTmpMemData = DllStructGetData($lBuffer, 1)
			$lTmpMemData = BinaryToString($lTmpMemData)

			$lSearch = StringInStr($lTmpMemData, $lCharNameCode, 2)
			If $lSearch > 0 Then
				$lTmpAddress = $lCurrentSearchAddress + $lSearch - 1
				DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $lTmpAddress + 0x6, 'ptr', DllStructGetPtr($lTmpBuffer), 'int', DllStructGetSize($lTmpBuffer), 'int', '')
				$mCharname = DllStructGetData($lTmpBuffer, 1)
				Return GetCharname()
			EndIf

			$lCurrentSearchAddress += $lMBI[3]
		EndIf
	WEnd

	Return ''
EndFunc   ;==>ScanForCharname
#EndRegion Initialisation

#Region Commands
#Region Item
Func StartSalvage($aItem, $aSalvageKit = False) ;~ Description: Starts a salvaging session of an item.
	; If $aSalvageKit is BOOLEAN, and is TRUE, this means the user wants to start an EXPERT salvage.
	; If $aSalvageKit does NOT evaluate to FALSE, presume this is an existing kit that the user explicitly wants to use.
	Local $lItemPtr = GetItemPtr($aItem)
	If $lItemPtr = 0 Then Return False ; Item to be salvaged not found.
	Local $SalvageSessionID = MemoryRead(GetInstanceBasePtr() + 0x690)
	If IsBool($aSalvageKit) Then 
		If $aSalvageKit Then 
			$aSalvageKit = FindExpertSalvageKit()
		Else
			$aSalvageKit = FindSalvageKit()
		EndIf
	EndIf
	
	If $aSalvageKit = 0 Then Return False ; Failed to get a salvage kit
	DllStructSetData($mSalvage, 2, GetItemProperty($aItem,'ID'))
	DllStructSetData($mSalvage, 3, GetItemProperty($aSalvageKit,'ID'))
	DllStructSetData($mSalvage, 4, $SalvageSessionID)
	Enqueue($mSalvagePtr, 16)
	Return $aSalvageKit ; Return the DllStruct of the salvage kit used.
EndFunc   ;==>StartSalvage

;~ Description: Salvage the materials out of an item.
Func SalvageMaterials()
	Return SendPacket(0x4, $SalvageMaterialsHeader)
EndFunc   ;==>SalvageMaterials

;~ Description: Salvages a mod out of an item.
Func SalvageMod($aModIndex)
	Return SendPacket(0x8, $SalvageModHeader, $aModIndex)
EndFunc   ;==>SalvageMod


Func IdentifyItem($aItem,$aIDKit=0) ;~ Description: Identifies an item. Pass ID Kit to explicitly use. returns True on success, False on failure.
	Local $lItemPtr = GetItemPtr($aItem), $lItemStruct = GetItemByPtr($lItemPtr), $lIDKit = $aIDKit
	If GetIsIdentified($lItemStruct) Then Return True ; Already Identified?
	If $lIDKit = 0 Then $lIDKit = FindIDKit()
	If $lIDKit = 0 Then Return False
	Local $ping = GetPing()
	SendPacket(0xC, $IdentifyItemHeader, GetItemProperty($lIDKit,'ID'),  GetItemProperty($lItemStruct,'ID'))
	Local $lDeadlock = TimerInit(), $lTimeout = 5000 + $ping
	Do
		Sleep(20 + $ping)
		If Not GetIsIdentified($lItemPtr) Then ContinueLoop ; Not identified... yet
		If IsDllStruct($aItem) Then RefreshItemStruct($aItem,$lItemPtr) ; Refresh item struct for further scripts
		If IsDllStruct($aIDKit) Then RefreshItemStruct($aIDKit) ; Refresh ID Kit struct for further scripts
		Return True
	Until TimerDiff($lDeadlock) > $lTimeout
	Return False
EndFunc   ;==>IdentifyItem

;~ Description: Identifies all items in a bag.
Func IdentifyBag($aBag, $aWhites = False, $aGolds = True)
	$aBag = GetBag($aBag)
	Local $lItem,$lRarity
	For $i = 1 To GetBagProperty($aBag, 'Slots')
		$lItem = GetItemBySlot($aBag, $i)
		If GetItemProperty($lItem, 'ID') == 0 Then ContinueLoop
		$lRarity = GetRarity($lItem)
		If $lRarity == 2621 And $aWhites == False Then ContinueLoop
		If $lRarity == 2624 And $aGolds == False Then ContinueLoop
		IdentifyItem($lItem)
	Next
EndFunc   ;==>IdentifyBag

;~ Description: Equips an item.
Func EquipItem($aItem)
	Return SendPacket(0x8, $EquipItemHeader, GetItemProperty($aItem,'ID'))
EndFunc   ;==>EquipItem

;~ Description: Uses an item.
Func UseItem($aItem)
	Return SendPacket(0x8, $UseItemHeader, GetItemProperty($aItem,'ID'))
EndFunc   ;==>UseItem

;~ Description: Picks up an item.
Func PickUpItem($aItem)
	Local $lAgentID

	If IsDllStruct($aItem) = 0 Then
		$lAgentID = $aItem
	ElseIf DllStructGetSize($aItem) < 400 Then
		$lAgentID = GetItemProperty($aItem, 'AgentID')
	Else
		$lAgentID = GetAgentProperty($aItem, 'ID')
	EndIf

	Return SendPacket(0xC, $PickUpItemHeader, $lAgentID, 0)
EndFunc   ;==>PickUpItem


Func DropItem($aItem, $aAmount = 0) ;~ Description: Drops an item.
	If IsNumber($aItem) Then $aItem = GetItemByItemID($aItem)
	Return SendPacket(0xC, $DropItemHeader, GetItemProperty($aItem,'ID'), $aAmount ? $aAmount : GetItemProperty($aItem,'Quantity'))
EndFunc   ;==>DropItem
Func MoveItem($aItem, $aBag, $aSlot, $aAmount=0) ;~ Description: Moves an item. Waits until complete, or timeout. Returns True on success.
	Local $lItemPtr = GetItemPtr($aItem), $lItemStruct = GetItemByPtr($lItemPtr), $lQuantity = GetItemProperty($lItemStruct,'Quantity'), $lBagPtr = GetBagPtr($aBag), $lBagStruct = GetBag($lBagPtr)
	If $lItemStruct = 0 Or $lBagStruct = 0 Then Return False ; Invalid item or bag
	If $aAmount = 0 Or $aAmount > $lQuantity Then $aAmount = $lQuantity
	Local $lFromSlot = GetItemProperty($lItemStruct,'Slot'), $lFromBag = GetItemProperty($lItemStruct,'Bag')
	If $aAmount >= $lQuantity Then ; Move Item i.e. User drags whole stack/item to other slot.
		SendPacket(0x10, $MoveItemHeader, GetItemProperty($lItemStruct,'ID'), GetBagProperty($lBagStruct,'ID'), $aSlot - 1)
	Else  ; Split stack i.e. User does CTRL + drag.
		SendPacket(0x14, $MoveItemExHeader, GetItemProperty($lItemStruct,'ID'), $aAmount, GetBagProperty($lBagStruct,'ID'), $aSlot - 1)
	EndIf
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 5000 + $lPing
	Do 
		Sleep(20 + $lPing)
		If GetItemProperty($lItemPtr,'Quantity') <> $lQuantity Then Return True
		If GetItemProperty($lItemPtr,'Bag') <> $lFromBag Then Return True
		If GetItemProperty($lItemPtr,'Slot') <> $lFromSlot Then Return True
	Until TimerDiff($lDeadlock) > $lTimeout ; Wait until the move has completed.
	Return False ; Got this far, timeout reached.
EndFunc
Func AcceptAllItems() ;~ Description: Accepts unclaimed items after a mission.
	Return SendPacket(0x8, $AcceptAllItemsHeader, GetBagProperty(7, 'ID'))
EndFunc   ;==>AcceptAllItems
Func SellItem($aItem, $aQuantity = 0) ;~ Description: Sells an item. Returns True on success, False on failure or timeout.
	; Added boolean return value for success, return False for no value, sleep loop for gold change. -- 3vcloud, 2018-05-28
	$aItem = GetItemPtr($aItem) ; Ptr because we don't stale checks in the loop.
	Local $lValue = GetItemProperty($aItem, 'Value')
	If $lValue = 0 Then Return False ; No value.
	Local $lQuantity = GetItemProperty($aItem,'Quantity')
	If $aQuantity = 0 Or $aQuantity > $lQuantity Then $aQuantity = $lQuantity
	DllStructSetData($mSellItem, 2, $aQuantity * $lValue)
	DllStructSetData($mSellItem, 3, GetItemProperty($aItem, 'ID'))
	Local $lStartAmount = GetGoldCharacter()
	Enqueue($mSellItemPtr, 12)
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 3000 + $lPing, $lSuccess = False
	Do
		Sleep(20 + $lPing) ; Wait until gold has changed.
		$lSuccess = GetItemProperty($aItem,'Bag') = 0 Or GetItemProperty($aItem,'Quantity') <> $lQuantity
	Until $lSuccess Or TimerDiff($lDeadlock) > $lTimeout
	Return $lSuccess
EndFunc   ;==>SellItem
Func GetMerchantItemByModelID($aModelID, $aExtraID = -1) ;~ Description: Fetch the item that a merchant is selling, by ModelID. Used for BuyItemByModelID -- 3vcloud, 2018-05-28
	Local $lMerchantItemsBase = GetMerchantItemsBase(), $lItem, $lItemStruct = DllStructCreate($mItemStructStr)
	If $lMerchantItemsBase = 0 Then Return 0 ; No merchant
	For $lItemRowID = 1 To GetMerchantItemsSize()
		$lItem = GetItemPtr(MemoryRead($lMerchantItemsBase + 4 * ($lItemRowID-1)))
		If GetItemProperty($lItem,'ModelID') <> $aModelID  Then ContinueLoop ; Not the same ModelID
		If GetItemProperty($lItem,'Slot') <> 0 Then ContinueLoop ; -1 Sellable, 0 Buyable
		If $aExtraID > -1 And GetItemProperty($lItem,'ExtraID') <> $aExtraID Then ContinueLoop ; Wrong ExtraID e.g. Blue Dye vs Green Dye
		SetExtended($lItemRowID)
		Return GetItemByPtr($lItem)
	Next
	Return 0 ; Failed to find item by ModelID
EndFunc
Func BuyItemByModelID($aModelID,$aQuantity=1) ;~ Description: Buy an item based on its ModelID.
	Return BuyItemByItemID(GetMerchantItemByModelID($aModelID),$aQuantity)
EndFunc
Func BuyItemByItemID($aItem,$aQuantity=1) ;~ Description: Buy an item. Can pass ItemID, Item Struct or Item Ptr.
	$aItem = GetItemByItemID($aItem)
	If $aItem = 0 Then Return False ; Invalid item.
	Local $lItemPtr = GetItemPtr($aItem), $lMerchantItemsBase = GetMerchantItemsBase()
	If GetItemProperty($aItem,'Slot') <> 0 Or GetItemProperty($aItem,'AgentID') <> 0 Then Return False ; Slot -1 Sellable, Slot 0 Buyable. Can't be in a bag or belong to an Agent.
	
	Local $lPrice = $aQuantity * GetItemProperty($aItem,'Value') * 2 ; NOTE: Price of buying an item is usually 2x the Value (need to consider Faction owned towns for lockpicks etc)
	Local $lStartAmount = GetGoldCharacter()
	If $lStartAmount < $lPrice Then Return False ; Not enough gold on char.
	DllStructSetData($mBuyItem, 2, $aQuantity)
	DllStructSetData($mBuyItem, 3, GetItemProperty($aItem,'ID'))
	DllStructSetData($mBuyItem, 4, $lPrice)
	Enqueue($mBuyItemPtr, 16)
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 3000 + $lPing
	Do
		Sleep(20 + $lPing) ; Wait until gold has changed.
		If $lStartAmount <> GetGoldCharacter() Then Return True
	Until TimerDiff($lDeadlock) > $lTimeout
	Return False
EndFunc
Func BuyItem($aRowID_Or_DllStruct_Or_Ptr, $aQuantity=1, $aValue=0) ;~ Description: Buys an item by row ID, Item Struct or Item Ptr. Legacy function, use BuyItemByItemID in most cases instead. Value is ignored.
	Local $lItem = $aItem_RowID_Or_DllStruct_Or_Ptr
	If IsDllStruct($lItem) Or IsPtr($lItem) Then Return BuyItemByItemID($lItem,$aQuantity) ; Able to pass $aItemRowID as an Item Struct or Item Ptr, and will pass it on without a problem.
	If IsNumber($lItem) = 0 Or $lItem < 1 Or $lItem > GetMerchantItemsSize() Then Return 0 ; Row ID is invalid.
	Return BuyItemByItemID(MemoryRead(GetMerchantItemsBase() + 4 * ($lItem - 1)),$aQuantity) ; Otherwise, treat $aItemRowID as the row id of the item for this merchant.
EndFunc   ;==>BuyItem
Func BuyIDKit($aQuantity = 1) ;~ Description: Legacy function, use BuyIdentificationKit instead.
	Return BuyIdentificationKit($aQuantity)
EndFunc   ;==>BuyIDKit

;~ Description: Buys an ID kit.
Func BuyIdentificationKit($aQuantity = 1)
	Return BuyItem(5, $aQuantity, 100)
EndFunc   ;==>BuyIdentificationKit

;~ Description: Legacy function, use BuySuperiorIdentificationKit instead.
Func BuySuperiorIDKit($aQuantity = 1)
	Return BuySuperiorIdentificationKit($Quantity)
EndFunc   ;==>BuySuperiorIDKit

;~ Description: Buys a superior ID kit.
Func BuySuperiorIdentificationKit($aQuantity = 1)
	Return BuyItem(6, $aQuantity, 500)
EndFunc   ;==>BuySuperiorIdentificationKit

func BuySalvageKit($aQuantity = 1)
	Return buyItem(2, $aQuantity, 100)
endFunc   ;==>buySalvageKit

func BuyExpertSalvageKit($aQuantity = 1)
	Return buyItem(3, $aQuantity, 400)
endFunc   ;==>buyExpertSalvageKit

;~ Description: Request a quote to buy an item from a trader. Returns true if successful.
Func TraderRequest($aModelID, $aExtraID = -1)
	Local $lQuoteID = MemoryRead($mTraderQuoteID)
	Local $lMerchantItem = GetMerchantItemByModelID($aModelID,$aExtraID)
	If $lMerchantItem = 0 Then Return False ; No merchant, or item not available.
	DllStructSetData($mRequestQuote, 2, GetItemProperty($lMerchantItem, 'ID'))
	Enqueue($mRequestQuotePtr, 8)
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 3000 + $lPing, $lNewQuoteID
	Do
		Sleep(20 + $lPing)
		$lNewQuoteID = MemoryRead($mTraderQuoteID)
	Until $lNewQuoteID <> $lQuoteID Or TimerDiff($lDeadlock) > $lTimeout
	Return $lNewQuoteID <> $lQuoteID And GetTraderCostValue() > 0
EndFunc   ;==>TraderRequest


Func TraderBuy() ;~ Description: Buy the requested item.
	If Not GetTraderCostID() Or Not GetTraderCostValue() Then Return False
	Local $lStartAmount = GetGoldCharacter()
	Enqueue($mTraderBuyPtr, 4)
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 3000 + $lPing
	Do
		Sleep(20 + $lPing) ; Wait until gold has changed.
		If $lStartAmount <> GetGoldCharacter() Then Return True
	Until TimerDiff($lDeadlock) > $lTimeout
	Return False
EndFunc   ;==>TraderBuy
Func TraderRequestSell($aItem) ;~ Description: Request a quote to sell an item to the trader. Returns true is successful AND sale price > 0
	Local $lQuoteID = MemoryRead($mTraderQuoteID)
	DllStructSetData($mRequestQuoteSell, 2, GetItemProperty($aItem,'ID'))
	Enqueue($mRequestQuoteSellPtr, 8)
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 3000 + $lPing, $lSuccess = False
	Do
		Sleep(20 + $lPing)
		$lSuccess = $lQuoteID <> MemoryRead($mTraderQuoteID)
	Until $lSuccess Or TimerDiff($lDeadlock) > $lTimeout
	Return $lSuccess And GetTraderCostValue() > 0
EndFunc   ;==>TraderRequestSell

;~ Description: ID of the item item being sold.
Func TraderSell()
	If Not GetTraderCostID() Or Not GetTraderCostValue() Then Return False
	Local $lStartAmount = GetGoldCharacter(), $lItemPtr = GetItemPtr(GetTraderCostID()), $lQuantity = GetItemProperty($lItemPtr,'Quantity')
	Enqueue($mTraderSellPtr, 4)
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 3000 + $lPing, $lSuccess = False
	Do
		Sleep(20 + $lPing) ; Wait until gold has changed.
		$lSuccess = GetItemProperty($lItemPtr,'Bag') = 0 Or $lQuantity <> GetItemProperty($lItemPtr,'Quantity')
	Until $lSuccess Or TimerDiff($lDeadlock) > $lTimeout
	Return $lSuccess
EndFunc   ;==>TraderSell
Func DropGold($aAmount = 0) ;~ Description: Drop gold on the ground.
	Return SendPacket(0x8, $DropGoldHeader, $aAmount)
EndFunc   ;==>DropGold
Func DepositGold($aAmount = 0) ;~ Description: Deposit gold into storage.
	Local $lStorage = GetGoldStorage(), $lCharacter = GetGoldCharacter()
	If $aAmount < 1 Or $lCharacter < $aAmount Then $aAmount = $lCharacter
	If $lStorage + $aAmount > 1000000 Then $aAmount = 1000000 - $lStorage
	Return ChangeGold($lCharacter - $aAmount, $lStorage + $aAmount)
EndFunc   ;==>DepositGold
Func WithdrawGold($aAmount = 0) ;~ Description: Withdraw gold from storage.
	Local $lStorage = GetGoldStorage(), $lCharacter = GetGoldCharacter()
	If $aAmount < 1 Or $lStorage < $aAmount Then $aAmount = $lStorage
	If $lCharacter + $aAmount > 100000 Then $aAmount = 100000 - $lCharacter
	Return ChangeGold($lCharacter + $aAmount, $lStorage - $aAmount)
EndFunc   ;==>WithdrawGold
Func ChangeGold($aCharacter, $aStorage) ;~ Description: Internal use for moving gold. Added a wait mechanism.
	Local $lStartAmount = GetGoldCharacter()
	If $lStartAmount == $aCharacter Then Return True ; No gold change.
	SendPacket(0xC, $ChangeGoldHeader, $aCharacter, $aStorage)
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 3000 + $lPing
	Do
		Sleep(20 + $lPing) ; Wait until gold has changed.
		If $lStartAmount <> GetGoldCharacter() Then Return True
	Until TimerDiff($lDeadlock) > $lTimeout
	Return False
EndFunc   ;==>ChangeGold
#EndRegion Item

#Region H&H
;~ Description: Adds a hero to the party.
Func AddHero($aHeroId)
	Return SendPacket(0x8, $AddHeroHeader, $aHeroId)
EndFunc   ;==>AddHero

;~ Description: Kicks a hero from the party.
Func KickHero($aHeroId)
	Return SendPacket(0x8, $KickHeroHeader, $aHeroId)
EndFunc   ;==>KickHero

;~ Description: Kicks all heroes from the party.
Func KickAllHeroes()
	Return SendPacket(0x8, $KickHeroHeader, 0x26)
EndFunc   ;==>KickAllHeroes

;~ Description: Add a henchman to the party.
Func AddNpc($aNpcId)
	Return SendPacket(0x8, $AddNpcHeader, $aNpcId)
EndFunc   ;==>AddNpc

;~ Description: Kick a henchman from the party.
Func KickNpc($aNpcId)
	Return SendPacket(0x8, $KickNpcHeader, $aNpcId)
EndFunc   ;==>KickNpc

;~ Description: Clear the position flag from a hero.
Func CancelHero($aHeroNumber)
	Return SendPacket(0x14, $CommandHeroHeader, GetHeroID($aHeroNumber), 0x7F800000, 0x7F800000, 0)
EndFunc   ;==>CancelHero

;~ Description: Clear the position flag from all heroes.
Func CancelAll()
	Return SendPacket(0x10, $CommandAllHeader, 0x7F800000, 0x7F800000, 0)
EndFunc   ;==>CancelAll

;~ Description: Place a hero's position flag.
Func CommandHero($aHeroNumber, $aX, $aY)
	Return SendPacket(0x14, $CommandHeroHeader, GetHeroID($aHeroNumber), FloatToInt($aX), FloatToInt($aY), 0)
EndFunc   ;==>CommandHero

;~ Description: Place the full-party position flag.
Func CommandAll($aX, $aY)
	Return SendPacket(0x10, $CommandAllHeader, FloatToInt($aX), FloatToInt($aY), 0)
EndFunc   ;==>CommandAll

;~ Description: Lock a hero onto a target.
Func LockHeroTarget($aHeroNumber, $aAgentID = 0) ;$aAgentID=0 Cancels Lock
	Return SendPacket(0xC, $LockHeroTargetHeader, GetHeroID($aHeroNumber), $aAgentID)
EndFunc   ;==>LockHeroTarget

;~ Description: Change a hero's aggression level.
Func SetHeroAggression($aHeroNumber, $aAggression) ;0=Fight, 1=Guard, 2=Avoid
	Local $lHeroID = GetHeroID($aHeroNumber)
	Return SendPacket(0xC, $SetHeroAggressionHeader, $lHeroID, $aAggression)
EndFunc   ;==>SetHeroAggression

;~ Description: Disable a skill on a hero's skill bar.
Func DisableHeroSkillSlot($aHeroNumber, $aSkillSlot)
	If Not GetIsHeroSkillSlotDisabled($aHeroNumber, $aSkillSlot) Then ChangeHeroSkillSlotState($aHeroNumber, $aSkillSlot)
EndFunc   ;==>DisableHeroSkillSlot

;~ Description: Enable a skill on a hero's skill bar.
Func EnableHeroSkillSlot($aHeroNumber, $aSkillSlot)
	If GetIsHeroSkillSlotDisabled($aHeroNumber, $aSkillSlot) Then ChangeHeroSkillSlotState($aHeroNumber, $aSkillSlot)
EndFunc   ;==>EnableHeroSkillSlot

;~ Description: Internal use for enabling or disabling hero skills
Func ChangeHeroSkillSlotState($aHeroNumber, $aSkillSlot)
	Return SendPacket(0xC, $ChangeHeroSkillSlotStateHeader, GetHeroID($aHeroNumber), $aSkillSlot - 1)
EndFunc   ;==>ChangeHeroSkillSlotState

;~ Description: Order a hero to use a skill.
Func UseHeroSkill($aHero, $aSkillSlot, $aTarget = 0)
	DllStructSetData($mUseHeroSkill, 2, GetHeroID($aHero))
	DllStructSetData($mUseHeroSkill, 3, GetAgentID($aTarget))
	DllStructSetData($mUseHeroSkill, 4, $aSkillSlot - 1)
	Enqueue($mUseHeroSkillPtr, 16)
EndFunc   ;==>UseHeroSkill

Func SetDisplayedTitle($aTitle = 0)
	If $aTitle Then Return SendPacket(0x8, $SetDisplayedTitleHeader, $aTitle)
	Return SendPacket(0x4, $RemoveDisplayedTitleHeader)
EndFunc   ;==>SetDisplayedTitle
#EndRegion H&H

#Region Movement
;~ Description: Move to a location.
Func Move($aX, $aY, $aRandom = 50)
	If Not GetAgentExists(-2) Then Return False
	DllStructSetData($mMove, 2, $aX + Random(-$aRandom, $aRandom))
	DllStructSetData($mMove, 3, $aY + Random(-$aRandom, $aRandom))
	Enqueue($mMovePtr, 16)
	Return True
EndFunc   ;==>Move


Func MoveTo($aX, $aY, $aRandom = 50) ;~ Description: Move to a location and wait until you reach it.
	; EDITS: 
	;		Use Agent Ptr to avoid repeated memreads, defer to GetIsMoving. -- Jon, 2018-05-26
	Local $lBlocked = 0, $lMe, $lMePtr = GetAgentPtr(-2), $lOkDistance = 150
	Local $lMapLoading = GetMapLoading()
	Local $lDistance = DistanceTo($aX,$aY,$lMe)
	Local $lDestX,$lDestY
	While $lDistance > $lOkDistance
		Sleep(100)
		If $lMapLoading <> GetMapLoading() Then ExitLoop ; Map changed
		$lMe = GetAgentByPtr($lMePtr)
		If GetAgentProperty($lMe, 'HP') <= 0 Then ExitLoop ; Dead.
		$lDistance = DistanceTo($aX,$aY,$lMe)
		If GetIsMoving($lMe) Then 
			$lBlocked = 0
			ContinueLoop ; Still moving.
		EndIf
		$lBlocked += 1
		$lDestX = $aX + Random(-$aRandom, $aRandom)
		$lDestY = $aY + Random(-$aRandom, $aRandom)
		Move($lDestX, $lDestY, 0)
	WEnd
	Return $lDistance < $lOkDistance
EndFunc   ;==>MoveTo
Func DistanceTo($aX,$aY,$aAgent=-2) ;~ Description: Get distance between X/Y coords and an agent.	-- Jon, 2018-06-02
	Local $lAgentXY = GetAgentXY($aAgent)
	Return IsArray($lAgentXY) ? ComputeDistance($lAgentXY[0], $lAgentXY[1], $aX, $aY) : 0
EndFunc
Func MoveToAgent($aAgent) ;~ Description: Go to agent without worrying about coords. -- Jon, 2018-05-28
	Local $lAgentXY = GetAgentXY($aAgent)
	Return IsArray($lAgentXY) And MoveTo($lAgentXY[0],$lAgentXY[1])
EndFunc
Func GoPlayer($aAgent) ;~ Description: Run to or follow a player.
	Return SendPacket(0x8, $GoPlayerHeader, GetAgentProperty($aAgent,'ID'))
EndFunc   ;==>GoPlayer
Func GoNPC($aAgent) ;~ Description: Talk to an NPC
	Return SendPacket(0xC, $GoNPCHeader, GetAgentProperty($aAgent,'ID'))
EndFunc   ;==>GoNPC
Func GoToNPC($aAgent) ;~ Description: Talks to NPC and waits until you reach them.
	Return MoveToAgent($aAgent) And GoNPC($aAgent)
EndFunc
Func GoSignpost($aAgent) ;~ Description: Run to a signpost.
	Return SendPacket(0xC, $GoSignpostHeader, GetAgentProperty($aAgent,'ID'), 0)
EndFunc   ;==>GoSignpost
Func GoToSignpost($aAgent) ;~ Description: Go to signpost and waits until you reach it.
	Return MoveToAgent($aAgent) And GoSignpost($aAgent)
EndFunc   ;==>GoToSignpost
Func Attack($aAgent, $aCallTarget = False) ;~ Description: Attack an agent.
	Return SendPacket(0xC, $AttackHeader, GetAgentProperty($aAgent,'ID'), $aCallTarget)
EndFunc   ;==>Attack
Func TurnLeft($aTurn) ;~ Description: Turn character to the left.
	Return PerformAction(0xA2, $aTurn ? 0x18 : 0x1A)
EndFunc   ;==>TurnLeft
Func TurnRight($aTurn) ;~ Description: Turn character to the right.
	Return PerformAction(0xA3, $aTurn ? 0x18 : 0x1A)
EndFunc   ;==>TurnRight
Func MoveBackward($aMove) ;~ Description: Move backwards.
	Return PerformAction(0xAC, $aMove ? 0x18 : 0x1A)
EndFunc   ;==>MoveBackward
Func MoveForward($aMove) ;~ Description: Run forwards.
	Return PerformAction(0xAD, $aMove ? 0x18 : 0x1A)
EndFunc   ;==>MoveForward
Func StrafeLeft($aStrafe) ;~ Description: Strafe to the left.
	Return PerformAction(0x91, $aStrafe ? 0x18 : 0x1A)
EndFunc   ;==>StrafeLeft
Func StrafeRight($aStrafe) ;~ Description: Strafe to the right.
	Return PerformAction(0x92, $aStrafe ? 0x18 : 0x1A)
EndFunc   ;==>StrafeRight
Func ToggleAutoRun() ;~ Description: Auto-run.
	Return PerformAction(0xB7, 0x18)
EndFunc   ;==>ToggleAutoRun
Func ReverseDirection() ;~ Description: Turn around.
	Return PerformAction(0xB1, 0x18)
EndFunc   ;==>ReverseDirection
#EndRegion Movement

#Region Travel

Func TravelTo($aMapID, $aDis = 0) ;~ Description: Map travel to an outpost.
	;returns true if successful
	If GetMapID() = $aMapID And $aDis = 0 And GetMapLoading() = 0 Then Return True
	ZoneMap($aMapID, $aDis)
	Return WaitMapLoading($aMapID)
EndFunc   ;==>TravelTo
Func ZoneMap($aMapID, $aDistrict = 0) ;~ Description: Internal use for map travel.
	MoveMap($aMapID, GetRegion(), $aDistrict, GetLanguage());
EndFunc   ;==>ZoneMap
Func MoveMap($aMapID, $aRegion, $aDistrict, $aLanguage) ;~ Description: Internal use for map travel.
	Return SendPacket(0x18, $MoveMapHeader, $aMapID, $aRegion, $aDistrict, $aLanguage, False)
EndFunc   ;==>MoveMap
Func ReturnToOutpost() ;~ Description: Returns to outpost after resigning/failure.
	Return SendPacket(0x4, $ReturnToOutpostHeader)
EndFunc   ;==>ReturnToOutpost
Func EnterChallenge() ;~ Description: Enter a challenge mission/pvp.
	Return SendPacket(0x8, $EnterChallengeHeader, 1)
EndFunc   ;==>EnterChallenge
Func EnterChallengeForeign() ;~ Description: Enter a foreign challenge mission/pvp.
	Return SendPacket(0x8, $EnterChallengeHeader, 0)
EndFunc   ;==>EnterChallengeForeign
Func TravelGH() ;~ Description: Travel to your guild hall.
    Local $lOffset[3] = [0, 0x18, 0x3C]
    Local $lGH = MemoryReadPtr($mBasePointer, $lOffset)
	Local $lGHStruct = MemoryReadStruct($lGH[1] + 0x64,'dword;dword;dword;dword') ; Read into Struct - no need to do 4 separate MemoryRead() calls! -- Jon, 2018-06-04
    SendPacket(0x18, $TravelGHHeader, DllStructGetData($lGHStruct,1), DllStructGetData($lGHStruct,2), DllStructGetData($lGHStruct,3), DllStructGetData($lGHStruct,4), 1)
    Return WaitMapLoading()
EndFunc   ;==>TravelGH

;~ Description: Leave your guild hall.
Func LeaveGH()
	Return SendPacket(0x8, $LeaveGHHeader, 1) And WaitMapLoading()
EndFunc   ;==>LeaveGH
#EndRegion Travel

#Region Quest

Func AcceptQuest($aQuestID) ;~ Description: Accept a quest from an NPC.
	Return SendPacket(0x8, $DialogHeader, '0x008' & Hex($aQuestID, 3) & '01')
EndFunc   ;==>AcceptQuest
Func QuestReward($aQuestID) ;~ Description: Accept the reward for a quest.
	Return SendPacket(0x8, $DialogHeader, '0x008' & Hex($aQuestID, 3) & '07')
EndFunc   ;==>QuestReward
Func AbandonQuest($aQuestID) ;~ Description: Abandon a quest.
	Return SendPacket(0x8, $AbandonQuestHeader, $aQuestID)
EndFunc   ;==>AbandonQuest
#EndRegion Quest

#Region Windows
;~ Description: Close all in-game windows.
Func CloseAllPanels()
	Return PerformAction(0x85, 0x18)
EndFunc   ;==>CloseAllPanels

;~ Description: Toggle hero window.
Func ToggleHeroWindow()
	Return PerformAction(0x8A, 0x18)
EndFunc   ;==>ToggleHeroWindow

;~ Description: Toggle inventory window.
Func ToggleInventory()
	Return PerformAction(0x8B, 0x18)
EndFunc   ;==>ToggleInventory

;~ Description: Toggle all bags window.
Func ToggleAllBags()
	Return PerformAction(0xB8, 0x18)
EndFunc   ;==>ToggleAllBags

;~ Description: Toggle world map.
Func ToggleWorldMap()
	Return PerformAction(0x8C, 0x18)
EndFunc   ;==>ToggleWorldMap

;~ Description: Toggle options window.
Func ToggleOptions()
	Return PerformAction(0x8D, 0x18)
EndFunc   ;==>ToggleOptions

;~ Description: Toggle quest window.
Func ToggleQuestWindow()
	Return PerformAction(0x8E, 0x18)
EndFunc   ;==>ToggleQuestWindow

;~ Description: Toggle skills window.
Func ToggleSkillWindow()
	Return PerformAction(0x8F, 0x18)
EndFunc   ;==>ToggleSkillWindow

;~ Description: Toggle mission map.
Func ToggleMissionMap()
	Return PerformAction(0xB6, 0x18)
EndFunc   ;==>ToggleMissionMap

;~ Description: Toggle friends list window.
Func ToggleFriendList()
	Return PerformAction(0xB9, 0x18)
EndFunc   ;==>ToggleFriendList

;~ Description: Toggle guild window.
Func ToggleGuildWindow()
	Return PerformAction(0xBA, 0x18)
EndFunc   ;==>ToggleGuildWindow

;~ Description: Toggle party window.
Func TogglePartyWindow()
	Return PerformAction(0xBF, 0x18)
EndFunc   ;==>TogglePartyWindow

;~ Description: Toggle score chart.
Func ToggleScoreChart()
	Return PerformAction(0xBD, 0x18)
EndFunc   ;==>ToggleScoreChart

;~ Description: Toggle layout window.
Func ToggleLayoutWindow()
	Return PerformAction(0xC1, 0x18)
EndFunc   ;==>ToggleLayoutWindow

;~ Description: Toggle minions window.
Func ToggleMinionList()
	Return PerformAction(0xC2, 0x18)
EndFunc   ;==>ToggleMinionList

;~ Description: Toggle a hero panel.
Func ToggleHeroPanel($aHero)
	If $aHero < 4 Then
		Return PerformAction(0xDB + $aHero, 0x18)
	ElseIf $aHero < 8 Then
		Return PerformAction(0xFE + $aHero, 0x18)
	EndIf
EndFunc   ;==>ToggleHeroPanel

;~ Description: Toggle hero's pet panel.
Func ToggleHeroPetPanel($aHero)
	If $aHero < 4 Then
		Return PerformAction(0xDF + $aHero, 0x18)
	ElseIf $aHero < 8 Then
		Return PerformAction(0xFA + $aHero, 0x18)
	EndIf
EndFunc   ;==>ToggleHeroPetPanel

;~ Description: Toggle pet panel.
Func TogglePetPanel()
	Return PerformAction(0xDF, 0x18)
EndFunc   ;==>TogglePetPanel

;~ Description: Toggle help window.
Func ToggleHelpWindow()
	Return PerformAction(0xE4, 0x18)
EndFunc   ;==>ToggleHelpWindow
#EndRegion Windows

#Region Targeting
Func ChangeTarget($aAgent) ;~ Description: Target an agent.
	DllStructSetData($mChangeTarget, 2, GetAgentID($aAgent))
	Enqueue($mChangeTargetPtr, 8)
EndFunc   ;==>ChangeTarget
Func CallTarget($aTarget) ;~ Description: Call target.
	Return SendPacket(0xC, $CallTargetHeader, 0xA, GetAgentID($aTarget))
EndFunc   ;==>CallTarget
Func ClearTarget() ;~ Description: Clear current target.
	Return PerformAction(0xE3, 0x18)
EndFunc   ;==>ClearTarget
Func TargetNearestEnemy() ;~ Description: Target the nearest enemy.
	Return PerformAction(0x93, 0x18)
EndFunc   ;==>TargetNearestEnemy
Func TargetNextEnemy() ;~ Description: Target the next enemy.
	Return PerformAction(0x95, 0x18)
EndFunc   ;==>TargetNextEnemy
Func TargetPartyMember($aNumber) ;~ Description: Target the next party member.
	If $aNumber > 0 And $aNumber < 13 Then Return PerformAction(0x95 + $aNumber, 0x18)
EndFunc   ;==>TargetPartyMember

;~ Description: Target the previous enemy.
Func TargetPreviousEnemy()
	Return PerformAction(0x9E, 0x18)
EndFunc   ;==>TargetPreviousEnemy

;~ Description: Target the called target.
Func TargetCalledTarget()
	Return PerformAction(0x9F, 0x18)
EndFunc   ;==>TargetCalledTarget

;~ Description: Target yourself.
Func TargetSelf()
	Return PerformAction(0xA0, 0x18)
EndFunc   ;==>TargetSelf

;~ Description: Target the nearest ally.
Func TargetNearestAlly()
	Return PerformAction(0xBC, 0x18)
EndFunc   ;==>TargetNearestAlly

;~ Description: Target the nearest item.
Func TargetNearestItem()
	Return PerformAction(0xC3, 0x18)
EndFunc   ;==>TargetNearestItem

;~ Description: Target the next item.
Func TargetNextItem()
	Return PerformAction(0xC4, 0x18)
EndFunc   ;==>TargetNextItem

;~ Description: Target the previous item.
Func TargetPreviousItem()
	Return PerformAction(0xC5, 0x18)
EndFunc   ;==>TargetPreviousItem

;~ Description: Target the next party member.
Func TargetNextPartyMember()
	Return PerformAction(0xCA, 0x18)
EndFunc   ;==>TargetNextPartyMember

;~ Description: Target the previous party member.
Func TargetPreviousPartyMember()
	Return PerformAction(0xCB, 0x18)
EndFunc   ;==>TargetPreviousPartyMember
#EndRegion Targeting

#Region Display

Func EnableRendering() ;~ Description: Enable graphics rendering.
	MemoryWrite($mDisableRendering, 0)
EndFunc   ;==>EnableRendering
Func DisableRendering() ;~ Description: Disable graphics rendering.
	MemoryWrite($mDisableRendering, 1)
EndFunc   ;==>DisableRendering
Func DisplayAll($aDisplay) ;~ Description: Display all names.
	Return DisplayAllies($aDisplay) And DisplayEnemies($aDisplay)
EndFunc   ;==>DisplayAll
Func DisplayAllies($aDisplay) ;~ Description: Display the names of allies.
	Return PerformAction(0x89, $aDisplay ? 0x18 : 0x1A)
EndFunc   ;==>DisplayAllies
Func DisplayEnemies($aDisplay) ;~ Description: Display the names of enemies.
	Return PerformAction(0x94, $aDisplay ? 0x18 : 0x1A)
EndFunc   ;==>DisplayEnemies
#EndRegion Display

#Region Chat
;~ Description: Write a message in chat (can only be seen by botter).
Func WriteChat($aMessage, $aSender = 'GWA2')
	Local $lMessage, $lSender
	Local $lAddress = 256 * $mQueueCounter + $mQueueBase

	If $mQueueCounter = $mQueueSize Then
		$mQueueCounter = 0
	Else
		$mQueueCounter = $mQueueCounter + 1
	EndIf

	If StringLen($aSender) > 19 Then
		$lSender = StringLeft($aSender, 19)
	Else
		$lSender = $aSender
	EndIf

	MemoryWrite($lAddress + 4, $lSender, 'wchar[20]')

	If StringLen($aMessage) > 100 Then
		$lMessage = StringLeft($aMessage, 100)
	Else
		$lMessage = $aMessage
	EndIf

	MemoryWrite($lAddress + 44, $lMessage, 'wchar[101]')
	DllCall($mKernelHandle, 'int', 'WriteProcessMemory', 'int', $mGWProcHandle, 'int', $lAddress, 'ptr', $mWriteChatPtr, 'int', 4, 'int', '')

	If StringLen($aMessage) > 100 Then WriteChat(StringTrimLeft($aMessage, 100), $aSender)
EndFunc   ;==>WriteChat

;~ Description: Send a whisper to another player.
Func SendWhisper($aReceiver, $aMessage)
	Local $lTotal = 'whisper ' & $aReceiver & ',' & $aMessage
	Local $lMessage

	If StringLen($lTotal) > 120 Then
		$lMessage = StringLeft($lTotal, 120)
	Else
		$lMessage = $lTotal
	EndIf

	SendChat($lMessage, '/')

	If StringLen($lTotal) > 120 Then SendWhisper($aReceiver, StringTrimLeft($lTotal, 120))
EndFunc   ;==>SendWhisper

;~ Description: Send a message to chat.
Func SendChat($aMessage, $aChannel = '!')
	Local $lMessage
	Local $lAddress = 256 * $mQueueCounter + $mQueueBase

	If $mQueueCounter = $mQueueSize Then
		$mQueueCounter = 0
	Else
		$mQueueCounter = $mQueueCounter + 1
	EndIf

	If StringLen($aMessage) > 120 Then
		$lMessage = StringLeft($aMessage, 120)
	Else
		$lMessage = $aMessage
	EndIf

	MemoryWrite($lAddress + 8, $aChannel & $lMessage, 'wchar[122]')
	DllCall($mKernelHandle, 'int', 'WriteProcessMemory', 'int', $mGWProcHandle, 'int', $lAddress, 'ptr', $mSendChatPtr, 'int', 8, 'int', '')

	If StringLen($aMessage) > 120 Then SendChat(StringTrimLeft($aMessage, 120), $aChannel)
EndFunc   ;==>SendChat
#EndRegion Chat

#Region Misc
;~ Description: Change weapon sets.
Func ChangeWeaponSet($aSet)
	Return PerformAction(0x80 + $aSet, 0x18)
EndFunc   ;==>ChangeWeaponSet

;~ Description: Use a skill.
Func UseSkill($aSkillSlot, $aTarget = 0, $aCallTarget = False)
	DllStructSetData($mUseSkill, 2, $aSkillSlot)
	DllStructSetData($mUseSkill, 3, GetAgentID($aTarget))
	DllStructSetData($mUseSkill, 4, $aCallTarget)
	Enqueue($mUseSkillPtr, 16)
EndFunc   ;==>UseSkill

;~ Description: Cancel current action.
Func CancelAction()
	Return SendPacket(0x4, $CancelActionHeader)
EndFunc   ;==>CancelAction

;~ Description: Same as hitting spacebar.
Func ActionInteract()
	Return PerformAction(0x80, 0x18)
EndFunc   ;==>ActionInteract

;~ Description: Follow a player.
Func ActionFollow()
	Return PerformAction(0xCC, 0x18)
EndFunc   ;==>ActionFollow

;~ Description: Drop environment object.
Func DropBundle()
	Return PerformAction(0xCD, 0x18)
EndFunc   ;==>DropBundle

;~ Description: Clear all hero flags.
Func ClearPartyCommands()
	Return PerformAction(0xDB, 0x18)
EndFunc   ;==>ClearPartyCommands

;~ Description: Suppress action.
Func SuppressAction($aSuppress)
	Return PerformAction(0xD0, $aSuppress ? 0x18 : 0x1A)
EndFunc   ;==>SuppressAction

;~ Description: Open a chest.
Func OpenChest()
	Return SendPacket(0x8, $OpenChestHeader, 2)
EndFunc   ;==>OpenChest
Func DropBuff($aSkillID, $aAgentID, $aHeroNumber = 0) ;~ Description: Stop maintaining enchantment on target.
	Local $lBuffs = GetBuffs($aHeroNumber), $aAgentID = GetAgentID($aAgentID)
	For $i = 1 To $lBuffs[0]
		If (DllStructGetData($lBuffs[$i], 'SkillID') == $aSkillID) And (DllStructGetData($lBuffs[$i], 'TargetId') == $aAgentID) Then Return SendPacket(0x8, $DropBuffHeader, DllStructGetData($lBuffs[$i], 'BuffId'))
	Next
EndFunc   ;==>DropBuff
Func MakeScreenshot() ;~ Description: Take a screenshot.
	Return PerformAction(0xAE, 0x18)
EndFunc   ;==>MakeScreenshot
Func InvitePlayer($aPlayerName) ;~ Description: Invite a player to the party.
	SendChat('invite ' & $aPlayerName, '/')
EndFunc   ;==>InvitePlayer
Func LeaveGroup($aKickHeroes = True);~ Description: Leave your party.
	; Added party size check, and sleep loop 	-- Jon, 2018-06-02
	If $aKickHeroes Then KickAllHeroes()
	Local $lInitialPartySize = GetPartySize()
	If $lInitialPartySize < 2 Then Return True ; Already alone
	SendPacket(0x4, $LeaveGroupHeader)
	Local $lDeadlock = TimerInit(), $lPing = GetPing(), $lTimeout = 2000 + $lPing
	Do
		Sleep(50 + $lPing)
		If GetPartySize() <> $lInitialPartySize Then Return True
	Until TimerDiff($lDeadlock) > $lTimeout
	Return False
EndFunc   ;==>LeaveGroup
Func SwitchMode($aMode) ;~ Description: Switches to/from Hard Mode.
	Return SendPacket(0x8, $SwitchModeHeader, $aMode)
EndFunc   ;==>SwitchMode
Func Resign() ;~ Description: Resign.
	SendChat('resign', '/')
EndFunc   ;==>Resign
Func DonateFaction($aFaction) ;~ Description: Donate Kurzick or Luxon faction. 'k' for Kurzick, 'l' for Luxon.
	Return SendPacket(0x10, $DonateFactionHeader, 0, (StringLeft($aFaction, 1) = 'k' ? 0 : 1), 0x1388)
EndFunc   ;==>DonateFaction
Func Dialog($aDialogID) ;~ Description: Open a dialog.
	Return SendPacket(0x8, $DialogHeader, $aDialogID)
EndFunc   ;==>Dialog
Func SkipCinematic() ;~ Description: Skip a cinematic.
	Return SendPacket(0x4, $SkipCinematicHeader)
EndFunc   ;==>SkipCinematic
Func SetSkillbarSkill($aSlot, $aSkillID, $aHeroNumber = 0) ;~ Description: Change a skill on the skillbar.
	Return SendPacket(0x14, $SetSkillbarSkillHeader, GetHeroID($aHeroNumber), $aSlot - 1, $aSkillID, 0)
EndFunc   ;==>SetSkillbarSkill

;~ Description: Load all skills onto a skillbar simultaneously.
Func LoadSkillBar($aSkill1 = 0, $aSkill2 = 0, $aSkill3 = 0, $aSkill4 = 0, $aSkill5 = 0, $aSkill6 = 0, $aSkill7 = 0, $aSkill8 = 0, $aHeroNumber = 0)
	SendPacket(0x2C, $LoadSkillBarHeader, GetHeroID($aHeroNumber), 8, $aSkill1, $aSkill2, $aSkill3, $aSkill4, $aSkill5, $aSkill6, $aSkill7, $aSkill8)
EndFunc   ;==>LoadSkillBar

;~ Description: Loads skill template code.
Func LoadSkillTemplate($aTemplate, $aHeroNumber = 0)
	Local $lHeroID = GetHeroID($aHeroNumber)
	Local $lSplitTemplate = StringSplit($aTemplate, "")
	Local $lAttributeStr = ""
	Local $lAttributeLevelStr = ""
	Local $lTemplateType ; 4 Bits
	Local $lVersionNumber ; 4 Bits
	Local $lProfBits ; 2 Bits -> P
	Local $lProfPrimary ; P Bits
	Local $lProfSecondary ; P Bits
	Local $lAttributesCount ; 4 Bits
	Local $lAttributesBits ; 4 Bits -> A
	;Local $lAttributes[1][2] ; A Bits + 4 Bits (for each Attribute)
	Local $lSkillsBits ; 4 Bits -> S
	Local $lSkills[8] ; S Bits * 8
	Local $lOpTail ; 1 Bit
	$aTemplate = ""
	For $i = 1 To $lSplitTemplate[0]
		$aTemplate &= Base64ToBin64($lSplitTemplate[$i])
	Next
	$lTemplateType = Bin64ToDec(StringLeft($aTemplate, 4))
	$aTemplate = StringTrimLeft($aTemplate, 4)
	If $lTemplateType <> 14 Then Return False
	$lVersionNumber = Bin64ToDec(StringLeft($aTemplate, 4))
	$aTemplate = StringTrimLeft($aTemplate, 4)
	$lProfBits = Bin64ToDec(StringLeft($aTemplate, 2)) * 2 + 4
	$aTemplate = StringTrimLeft($aTemplate, 2)
	$lProfPrimary = Bin64ToDec(StringLeft($aTemplate, $lProfBits))
	$aTemplate = StringTrimLeft($aTemplate, $lProfBits)
	If $lProfPrimary <> GetHeroProfession($aHeroNumber) Then Return False
	$lProfSecondary = Bin64ToDec(StringLeft($aTemplate, $lProfBits))
	$aTemplate = StringTrimLeft($aTemplate, $lProfBits)
	$lAttributesCount = Bin64ToDec(StringLeft($aTemplate, 4))
	$aTemplate = StringTrimLeft($aTemplate, 4)
	$lAttributesBits = Bin64ToDec(StringLeft($aTemplate, 4)) + 4
	$aTemplate = StringTrimLeft($aTemplate, 4)
	For $i = 1 To $lAttributesCount
		;Attribute ID
		$lAttributeStr &= Bin64ToDec(StringLeft($aTemplate, $lAttributesBits))
		If $i <> $lAttributesCount Then $lAttributeStr &= "|"
		$aTemplate = StringTrimLeft($aTemplate, $lAttributesBits)
		;Attribute level of above ID
		$lAttributeLevelStr &= Bin64ToDec(StringLeft($aTemplate, 4))
		If $i <> $lAttributesCount Then $lAttributeLevelStr &= "|"
		$aTemplate = StringTrimLeft($aTemplate, 4)
	Next
	$lSkillsBits = Bin64ToDec(StringLeft($aTemplate, 4)) + 8
	$aTemplate = StringTrimLeft($aTemplate, 4)
	For $i = 0 To 7
		$lSkills[$i] = Bin64ToDec(StringLeft($aTemplate, $lSkillsBits))
		$aTemplate = StringTrimLeft($aTemplate, $lSkillsBits)
	Next
	$lOpTail = Bin64ToDec($aTemplate)
	ChangeSecondProfession($lProfSecondary, $aHeroNumber)
	SetAttributes($lAttributeStr, $lAttributeLevelStr, $aHeroNumber)
	LoadSkillBar($lSkills[0], $lSkills[1], $lSkills[2], $lSkills[3], $lSkills[4], $lSkills[5], $lSkills[6], $lSkills[7], $aHeroNumber)
EndFunc   ;==>LoadSkillTemplate

;~ Description: Set attributes to the given values
Func SetAttributes($fAttsID, $fAttsLevel, $aHeroNumber = 0)
   Local $lAttsID = StringSplit(String($fAttsID), "|")
   Local $lAttsLevel = StringSplit(String($fAttsLevel), "|")

   DllStructSetData($mSetAttributes, 4, GetHeroID($aHeroNumber))
   DllStructSetData($mSetAttributes, 5, $lAttsID[0]) ;# of attributes
   DllStructSetData($mSetAttributes, 22, $lAttsID[0]) ;# of attributes

   For $i = 1 To $lAttsID[0]
	  DllStructSetData($mSetAttributes, 5 + $i, $lAttsID[$i]) ;ID ofAttributes
   Next

   For $i = 1 To $lAttsLevel[0]
	  DllStructSetData($mSetAttributes, 22 + $i, $lAttsLevel[$i]) ;Attribute Levels
   Next

   Enqueue($mSetAttributesPtr, 152)
EndFunc   ;==>SetAttributes

;~ Description: Change your secondary profession.
Func ChangeSecondProfession($aProfession, $aHeroNumber = 0)
	Return SendPacket(0xC, $ChangeSecondProfessionHeader, GetHeroID($aHeroNumber), $aProfession)
EndFunc   ;==>ChangeSecondProfession

;~ Description: Sets value of GetMapIsLoaded() to 0.
Func InitMapLoad()
	MemoryWrite($mMapIsLoaded, 0)
EndFunc   ;==>InitMapLoad

;~ Description: Changes game language to english.
Func EnsureEnglish($aEnsure)
	If $aEnsure Then
		MemoryWrite($mEnsureEnglish, 1)
	Else
		MemoryWrite($mEnsureEnglish, 0)
	EndIf
EndFunc   ;==>EnsureEnglish

;~ Description: Change game language.
Func ToggleLanguage()
	DllStructSetData($mToggleLanguage, 2, 0x18)
	Enqueue($mToggleLanguagePtr, 8)
EndFunc   ;==>ToggleLanguage

;~ Description: Changes the maximum distance you can zoom out.
Func ChangeMaxZoom($aZoom = 750)
	MemoryWrite($mZoomStill, $aZoom, "float")
	MemoryWrite($mZoomMoving, $aZoom, "float")
EndFunc   ;==>ChangeMaxZoom

;~ Description: Emptys Guild Wars client memory
Func ClearMemory()
	DllCall($mKernelHandle, 'int', 'SetProcessWorkingSetSize', 'int', $mGWProcHandle, 'int', -1, 'int', -1)
EndFunc   ;==>ClearMemory

;~ Description: Changes the maximum memory Guild Wars can use.
Func SetMaxMemory($aMemory = 157286400)
	DllCall($mKernelHandle, 'int', 'SetProcessWorkingSetSizeEx', 'int', $mGWProcHandle, 'int', 1, 'int', $aMemory, 'int', 6)
EndFunc   ;==>SetMaxMemory
#EndRegion Misc

#Region Online Status
 ;~ Description: Change online status. 0 = Offline, 1 = Online, 2 = Do not disturb, 3 = Away
 Func SetPlayerStatus($aStatus)
    If ($aStatus >= 0 And $aStatus <= 3) And GetPlayerStatus() <> $aStatus Then
        DllStructSetData($mChangeStatus, 2, $aStatus)
        Enqueue($mChangeStatusPtr, 8)
        Return True
    Else
        Return False
    EndIf
EndFunc   ;==>SetPlayerStatus

Func GetPlayerStatus()
       Return MemoryRead($mCurrentStatus)
 EndFunc   ;==>GetPlayerStatus
#EndRegion Online Status


Func Enqueue($aPtr, $aSize) ;~ Description: Internal use only.
	DllCall($mKernelHandle, 'int', 'WriteProcessMemory', 'int', $mGWProcHandle, 'int', 256 * $mQueueCounter + $mQueueBase, 'ptr', $aPtr, 'int', $aSize, 'int', '')
	$mQueueCounter += 1
	If $mQueueCounter > $mQueueSize Then $mQueueCounter = 0
	Return True
EndFunc   ;==>Enqueue

;~ Description: Converts float to integer.
Func FloatToInt($nFloat)
	Local $tFloat = DllStructCreate("float"), $tInt = DllStructCreate("int", DllStructGetPtr($tFloat))
	DllStructSetData($tFloat, 1, $nFloat)
	Return DllStructGetData($tInt, 1)
EndFunc   ;==>FloatToInt
#EndRegion Commands

#Region Queries
#Region Titles

Func GetTitle($aOffset) ;~ Description: Used internally by GetXXXTitle functions.
	Local $lOffset[2] = [0x81C, $aOffset]
	Local $lReturn = MemoryReadPtr(GetInstanceBasePtr(), $lOffset)
	Return $lReturn[1]
EndFunc
Func GetHeroTitle() ;~ Description: Returns Hero title progress.
	Return GetTitle(0x4)
EndFunc   ;==>GetHeroTitle
Func GetGladiatorTitle() ;~ Description: Returns Gladiator title progress.
	Return GetTitle(0x7C)
EndFunc   ;==>GetGladiatorTitle
Func GetKurzickTitle() ;~ Description: Returns Kurzick title progress.
	Return GetTitle(0xCC)
EndFunc   ;==>GetKurzickTitle
Func GetLuxonTitle() ;~ Description: Returns Luxon title progress.
	Return GetTitle(0xF4)
EndFunc   ;==>GetLuxonTitle
Func GetDrunkardTitle() ;~ Description: Returns drunkard title progress.
	Return GetTitle(0x11C)
EndFunc   ;==>GetDrunkardTitle
Func GetSurvivorTitle() ;~ Description: Returns survivor title progress.
	Return GetTitle(0x16C)
EndFunc   ;==>GetSurvivorTitle
Func GetMaxTitles() ;~ Description: Returns max titles
	Return GetTitle(0x194)
EndFunc   ;==>GetMaxTitles
Func GetLuckyTitle() ;~ Description: Returns lucky title progress.
	Return GetTitle(0x25C)
EndFunc   ;==>GetLuckyTitle
Func GetUnluckyTitle() ;~ Description: Returns unlucky title progress.
	Return GetTitle(0x284)
EndFunc   ;==>GetUnluckyTitle
Func GetSunspearTitle() ;~ Description: Returns Sunspear title progress.
	Return GetTitle(0x2AC)
EndFunc   ;==>GetSunspearTitle
Func GetLightbringerTitle() ;~ Description: Returns Lightbringer title progress.
	Return GetTitle(0x324)
EndFunc   ;==>GetLightbringerTitle
Func GetCommanderTitle() ;~ Description: Returns Commander title progress.
	Return GetTitle(0x374)
EndFunc   ;==>GetCommanderTitle
Func GetGamerTitle() ;~ Description: Returns Gamer title progress.
	Return GetTitle(0x39C)
EndFunc   ;==>GetGamerTitle
Func GetLegendaryGuardianTitle() ;~ Description: Returns Legendary Guardian title progress.
	Return GetTitle(0x4DC)
EndFunc   ;==>GetLegendaryGuardianTitle
Func GetSweetTitle() ;~ Description: Returns sweets title progress.
	Return GetTitle(0x554)
EndFunc   ;==>GetSweetTitle
Func GetAsuraTitle() ;~ Description: Returns Asura title progress.
	Return GetTitle(0x5F4)
EndFunc   ;==>GetAsuraTitle
Func GetDeldrimorTitle() ;~ Description: Returns Deldrimor title progress.
	Return GetTitle(0x61C)
EndFunc   ;==>GetDeldrimorTitle
Func GetVanguardTitle() ;~ Description: Returns Vanguard title progress.
	Return GetTitle(0x644)
EndFunc   ;==>GetVanguardTitle
Func GetNornTitle() ;~ Description: Returns Norn title progress.
	Return GetTitle(0x66C)
EndFunc   ;==>GetNornTitle
Func GetNorthMasteryTitle() ;~ Description: Returns mastery of the north title progress.
	Return GetTitle(0x694)
EndFunc   ;==>GetNorthMasteryTitle
Func GetPartyTitle() ;~ Description: Returns party title progress.
	Return GetTitle(0x6BC)
EndFunc   ;==>GetPartyTitle
Func GetZaishenTitle() ;~ Description: Returns Zaishen title progress.
	Return GetTitle(0x6E4)
EndFunc   ;==>GetZaishenTitle
Func GetTreasureTitle() ;~ Description: Returns treasure hunter title progress.
	Return GetTitle(0x70C)
EndFunc   ;==>GetTreasureTitle
Func GetWisdomTitle() ;~ Description: Returns wisdom title progress.
	Return GetTitle(0x734)
EndFunc   ;==>GetWisdomTitle
Func GetCodexTitle() ;~ Description: Returns codex title progress.
	Return GetTitle(0x75C) ;0x7B8 before apr20
EndFunc   ;==>GetCodexTitle
Func GetTournamentPoints() ;~ Description: Returns current Tournament points.
	Return MemoryRead(GetInstanceBasePtr() + 0x18)
EndFunc   ;==>GetTournamentPoints
#EndRegion Titles

#Region Faction
Func GetKurzickFaction() ;~ Description: Returns current Kurzick faction.
	Return MemoryRead(GetInstanceBasePtr() + 0x748)
EndFunc   ;==>GetKurzickFaction
Func GetMaxKurzickFaction() ;~ Description: Returns max Kurzick faction.
	Return MemoryRead(GetInstanceBasePtr() + 0x7B8)
EndFunc   ;==>GetMaxKurzickFaction
Func GetLuxonFaction() ;~ Description: Returns current Luxon faction.
	Return MemoryRead(GetInstanceBasePtr() + 0x758)
EndFunc   ;==>GetLuxonFaction
Func GetMaxLuxonFaction() ;~ Description: Returns max Luxon faction.
	Return MemoryRead(GetInstanceBasePtr() + 0x7BC)
EndFunc   ;==>GetMaxLuxonFaction
Func GetBalthazarFaction() ;~ Description: Returns current Balthazar faction.
	Return MemoryRead(GetInstanceBasePtr() + 0x798)
EndFunc   ;==>GetBalthazarFaction
Func GetMaxBalthazarFaction() ;~ Description: Returns max Balthazar faction.
	Return MemoryRead(GetInstanceBasePtr() + 0x7C0)
EndFunc   ;==>GetMaxBalthazarFaction
Func GetImperialFaction() ;~ Description: Returns current Imperial faction.
	Return MemoryRead(GetInstanceBasePtr() + 0x76C)
EndFunc   ;==>GetImperialFaction
Func GetMaxImperialFaction() ;~ Description: Returns max Imperial faction.
	Return MemoryRead(GetInstanceBasePtr() + 0x7C4)
EndFunc   ;==>GetMaxImperialFaction
#EndRegion Faction

#Region Item
Func GetItemProperty($aItem,$aPropertyName, $aNoCache = False) ;~ Description: Fetch property of an item, either ptr or dllstruct. $aNoCache will force a memory read for that value.
	If IsNumber($aItem) Or $aNoCache Then $aItem = GetItemPtr($aItem) ; Pointer based - no need to load whole struct into memory for 1 value
	If IsDllStruct($aItem) Then Return DllStructGetData($aItem,$aPropertyName)
	If IsPtr($aItem) Then
		Local $aStructElementInfo = Eval('mItemStructInfo_'&$aPropertyName)
		If Not IsArray($aStructElementInfo) Then Return ; Invalid property name.
		Return MemoryRead($aItem + $aStructElementInfo[1],$aStructElementInfo[0])
	EndIf
EndFunc
Func GetBagProperty($aBag,$aPropertyName, $aNoCache = False) ;~ Description: Fetch property of an item, either ptr or dllstruct. $aNoCache will force a memory read for that value.
	If IsNumber($aBag) Or $aNoCache Then $aBag = GetBagPtr($aBag) ; Pointer based - no need to load whole struct into memory for 1 value
	If IsDllStruct($aBag) Then Return DllStructGetData($aBag,$aPropertyName)
	If IsPtr($aBag) Then
		Local $aStructElementInfo = Eval('mBagStructInfo_'&$aPropertyName)
		If Not IsArray($aStructElementInfo) Then Return ; Invalid property name.
		Return MemoryRead($aBag + $aStructElementInfo[1],$aStructElementInfo[0])
	EndIf
EndFunc
Func GetItemUses($aItem) ;~ Description: Returns uses left for ID kit or salvage kits. Any other item returns the quantity value.
	If IsNumber($aItem) Then $aItem = GetItemByItemID($aItem)
	Switch GetItemProperty($aItem,'ModelID')
		Case 2992,2993,2989
			Return Floor(GetItemProperty($aItem,'Value') / 2)
		Case 5899
			Return Floor(GetItemProperty($aItem,'Value') / 2.5)
		Case 2991
			Return Floor(GetItemProperty($aItem,'Value') / 8)
		Case 5900
			Return Floor(GetItemProperty($aItem,'Value') / 10)
	EndSwitch
	Return GetItemProperty($aItem,'Quantity')
EndFunc
Func GetRarity($aItem) ;~ Description: Returns rarity (name color) of an item.
	Local $lPtr = GetItemProperty($aItem,'NameString')
	If Not $lPtr Then Return	
	Return MemoryRead($lPtr, 'ushort')
EndFunc   ;==>GetRarity
Func GetIsRareMaterial($aItem) ;~ Description: Returns if material is Rare.
	If IsNumber($aItem) Then $aItem = GetItemByItemID($aItem)
	If GetItemProperty($aItem,'Type') <> 11 Then Return False
	Return Not GetIsCommonMaterial($aItem)
EndFunc   ;==>GetIsRareMaterial
Func GetIsCommonMaterial($aItem) ;~ Description: Returns if material is Common.
	Return BitAND(GetItemProperty($aItem,'Interaction'), 0x20) <> 0
EndFunc   ;==>GetIsCommonMaterial
Func GetIsIDed($aItem)	;~ Description: Legacy function, use GetIsIdentified instead.
	Return GetIsIdentified($aItem)
EndFunc   ;==>GetIsIDed
Func GetIsIdentified($aItem) ;~ Description: Tests if an item is identified.
	Return BitAND(GetItemProperty($aItem,'Interaction'), 1) > 0
EndFunc   ;==>GetIsIdentified
Func GetItemReq($aItem) ;~ Description: Returns a weapon or shield's minimum required attribute.
	Local $lMod = GetModByIdentifier($aItem, "9827")
	Return $lMod[0]
EndFunc   ;==>GetItemReq
Func GetItemAttribute($aItem) ;~ Description: Returns a weapon or shield's required attribute.
	Local $lMod = GetModByIdentifier($aItem, "9827")
	Return $lMod[1]
EndFunc   ;==>GetItemAttribute
Func GetModByIdentifier($aItem, $aIdentifier) ;~ Description: Returns an array of a the requested mod.
	Local $lReturn[2]
	Local $lString = StringTrimLeft(GetModStruct($aItem), 2)
	For $i = 0 To StringLen($lString) / 8 - 2
		If StringMid($lString, 8 * $i + 5, 4) <> $aIdentifier Then ContinueLoop
		$lReturn[0] = Int("0x" & StringMid($lString, 8 * $i + 1, 2))
		$lReturn[1] = Int("0x" & StringMid($lString, 8 * $i + 3, 2))
		ExitLoop
	Next
	Return $lReturn
EndFunc   ;==>GetModByIdentifier
Func GetModStruct($aItem) ;~ Description: Returns modstruct of an item.
	Local $lModstruct, $lModSize
	If IsNumber($aItem) Then $aItem = GetItemPtr($aItem)
	If IsPtr($aItem) Then $aItem = MemoryReadStruct($aItem + $mItemStructInfo_ModStruct[1], 'ptr ModStruct;long ModStructSize')
	If IsDllStruct($aItem) Then
		$lModstruct = DllStructGetData($aItem, 'modstruct')
		$lModSize = DllStructGetData($aItem, 'modstructsize')
	EndIf
	If $lModstruct = 0 Then Return ''
	Return MemoryRead($lModstruct, 'Byte[' & $lModSize * 4 & ']')
EndFunc   ;==>GetModStruct
Func GetAssignedToMe($aAgent) ;~ Description: Tests if an item is assigned to you.
	Return GetAgentProperty($aAgent,'Owner') = GetMyID()
EndFunc   ;==>GetAssignedToMe
Func GetCanPickUp($aAgent) ;~ Description: Tests if you can pick up an item.
	Local $lOwner = GetAgentProperty($aAgent,'Owner')
	Return $lOwner == 0 Or $lOwner == GetMyID()
EndFunc   ;==>GetCanPickUp
Func GetBagPtr($aBag) ;~ Description: Returns ptr of an inventory bag.
	If IsPtr($aBag) Then Return $aBag
	If IsDllStruct($aBag) Then $aBag = GetBagProperty($aBag,'Index')
	Local $lOffset[5] = [0, 0x18, 0x40, 0xF8, 0x4 * $aBag]
	Local $lBagPtr = MemoryReadPtr($mBasePointer, $lOffset,'ptr')
	Return $lBagPtr[1]
EndFunc
Func GetBag($aBag,$aExistingStructToUse=0) ;~ Description: Returns struct of an inventory bag. Pass $aExistingStructToUse to load the data into the given struct.
	If IsDllStruct($aBag) Then Return $aBag
	Local $lBagPtr = GetBagPtr($aBag)
	If Not $lBagPtr Then Return
	Return MemoryReadStruct($lBagPtr,IsDllStruct($aExistingStructToUse) ? $aExistingStructToUse : $mBagStructStr)
EndFunc   ;==>GetBag
Func GetItemBySlot($aBag, $aSlot) ;~ Description: Returns item by slot.
	Local $lItemArrayPtr = GetBagProperty($aBag,'ItemArray')
	Return GetItemByPtr(MemoryRead($lItemArrayPtr + 4 * ($aSlot - 1),'ptr'))
EndFunc   ;==>GetItemBySlot
Func RefreshItemStruct($aItemStruct,$aItemPtr=0) ;~ Description: Recycles an existing DllStruct to re-fetch item details from memory. Good for avoiding stale Structs. Pass pointer to avoid having to grab it again.
	If Not IsDllStruct($aItemStruct) Then Return True ; Ignore if not already DllStruct, return True
	Return MemoryReadStruct($aItemPtr ? $aItemPtr : GetItemPtr($aItemStruct),$aItemStruct) <> 0 ; Returns boolean
EndFunc
Func GetItemPtr($aItem) ;~ Description: Returns item ptr - used internally
	If IsPtr($aItem) Then Return $aItem
	If IsDllStruct($aItem) Then $aItem = GetItemProperty($aItem,'ID')
	If $aItem = 0 Then Return 0
	Return MemoryRead(GetItemsBasePtr() + (0x4 * $aItem),'ptr')
EndFunc
Func GetItemHasUpgrades($aItemID)
	Return GetRarity($aItemID) > 2621 And StringRegExp(GetModStruct($aItemID),"32[2A]5|3025")
EndFunc
Func GetItemBy($aPropertyName,$aPropertyValue) ; Returns item by property value - used internally.
	If $aPropertyValue = 0 Then Return 0
	Local $lItem = DllStructCreate($mItemStructStr)
	For $lItemID=1 To GetItemArraySize()
		If GetItemByItemID($lItemID,$lItem) <> 0 And GetItemProperty($lItem,$aPropertyName) == $aPropertyValue Then Return $lItem
	Next
EndFunc
Func GetItemByItemID($aItemID,$aExistingStructToUse=0) ;~ Description: Returns item struct. Pass $aExistingStructToUse to load the data into the given struct.
	If IsDllStruct($aItemID) And (Not IsDllStruct($aExistingStructToUse)) Then Return $aItemID ; Already a struct, presume item struct.
	Return GetItemByPtr(GetItemPtr($aItemID),$aExistingStructToUse)
EndFunc   ;==>GetItemByItemID
Func GetItemByAgentID($aAgentID) ;~ Description: Returns item by agent ID. Legacy function, use GetItemBy() instead
	Return GetItemBy('AgentID',$aAgentID)
EndFunc   ;==>GetItemByAgentID
Func GetItemByModelID($aModelID) ;~ Description: Returns item by model ID. Legacy function, use GetItemBy() instead
	Return GetItemBy('ModelID',$aModelID)
EndFunc   ;==>GetItemByModelID
Func GetItemArraySize() ; Returns array of items as DllStructs - used internally
	Local $aOffset[4] = [0, 0x18, 0x40, 0xC0] ; Default offset - get all item IDs.
	Local $lItemArraySize = MemoryReadPtr($mBasePointer, $aOffset)
	Return $lItemArraySize[1]
EndFunc
Func GetItemByPtr($aItemPtr,$aItemStruct=0) ; Converts Ptr of an Item into DllStruct - used internally. OPTIONAL: Include the struct to be used.
	If $aItemPtr = 0 Then Return 0
	Return MemoryReadStruct($aItemPtr,IsDllStruct($aItemStruct) ? $aItemStruct : $mItemStructStr)
EndFunc
Func GetGoldStorage() ;~ Description: Returns amount of gold in storage.
	Local $lOffset[5] = [0, 0x18, 0x40, 0xF8, 0x80]
	Local $lReturn = MemoryReadPtr($mBasePointer, $lOffset)
	Return $lReturn[1]
EndFunc   ;==>GetGoldStorage
Func GetGoldCharacter() ;~ Description: Returns amount of gold being carried.
	Local $lOffset[5] = [0, 0x18, 0x40, 0xF8, 0x7C]
	Local $lReturn = MemoryReadPtr($mBasePointer, $lOffset)
	Return $lReturn[1]
EndFunc   ;==>GetGoldCharacter
Func FindSalvageKit() ;~ Description: Returns item ID of salvage kit in inventory.
	Local $lModelIDs[2] = [2992,2993]
	Return FindItemWithLeastUses($lModelIDs)
EndFunc   ;==>FindSalvageKit
Func FindExpertSalvageKit() ;~ Description: Returns item ID of expert salvage kit in inventory.
	Local $lModelIDs[2] = [2991,5900]
	Return FindItemWithLeastUses($lModelIDs)
EndFunc   ;==>FindExpertSalvageKit
Func FindIDKit() ;~ Description: Legacy function, use FindIdentificationKit instead.
	Return FindIdentificationKit()
EndFunc   ;==>FindIDKit
Func FindIdentificationKit() ;~ Description: Returns item ID of ID kit in inventory.
	Local $lModelIDs[2] = [2989,5899]
	Return FindItemWithLeastUses($lModelIDs)
EndFunc   ;==>FindIdentificationKit
Func FindItemWithLeastUses($aModelIDs=0) ; Used internally by FindSalvageKit() etc. Pass a single model ID or an array of Model IDs to search for.
	If $aModelIDs = 0 Then Return
	Local $iUses = 0, $lReturnItem = 0, $lUses = 250, $lBag, $lItemArrayPtr, $lSlots, $lItem, $lModelID
	If Not IsArray($aModelIDs) Then Local $aModelIDs[1] = [$aModelIDs]
	For $lBagIndex = 1 To 4	
		$lBag = GetBag($lBagIndex)
		If $lBag = 0 Then ContinueLoop ; No bag.
		$lItemArrayPtr = GetBagProperty($lBag,'ItemArray')
		$lSlots = GetBagProperty($lBag,'Slots')
		For $slot = 0 To $lSlots-1
			$lItem = GetItemByPtr(MemoryRead($lItemArrayPtr + 4 * ($slot), 'ptr')) ; Fetch DllStruct of item from pointer.
			If $lItem = 0 Then ContinueLoop ; Empty slot
			$lModelID = GetItemProperty($lItem,'ModelID')
			For $j=0 To UBound($aModelIDs)-1
				If $aModelIDs[$j] <> $lModelID Then ContinueLoop
				$iUses = GetItemUses($lItem)
				If $iUses > $lUses Then ContinueLoop ; This kit has more uses than previous selected kit.
				$lReturnItem = GetItemProperty($lItem,'ID')
				If $iUses == 1 Then Return $lReturnItem ; Shortcut if selected kit has only 1 use left
				$lUses = $iUses
				ExitLoop
			Next
		Next
	Next
	Return $lReturnItem
EndFunc
Func GetTraderCostID() ;~ Description: Returns the item ID of the quoted item.
	Return MemoryRead($mTraderCostID)
EndFunc   ;==>GetTraderCostID
Func GetTraderCostValue() ;~ Description: Returns the cost of the requested item.
	Return MemoryRead($mTraderCostValue)
EndFunc   ;==>GetTraderCostValue
Func GetMerchantItemsBase() ;~ Description: Internal use for BuyItem()
	Return MemoryRead(GetInstanceBasePtr() + 0x24)
EndFunc   ;==>GetMerchantItemsBase
Func GetMerchantItemsSize() ;~ Description: Internal use for BuyItem()
	Return MemoryRead(GetInstanceBasePtr() + 0x28)
EndFunc   ;==>GetMerchantItemsSize
#EndRegion Item

#Region H&H
;~ Description: Returns number of heroes you control.
Func GetHeroCount()
	Return MemoryRead(GetPartyBasePtr() + 0x2C)
EndFunc   ;==>GetHeroCount
Func GetHerosArrayPtr() ;~ Description: Returns ptr to hero array. Used internally for GetHeroID etc
	Return MemoryRead(GetPartyBasePtr() + 0x24,'ptr')
EndFunc
Func GetHeroID($aHeroNumber=0) ;~ Description: Returns agent ID of a hero.
	If $aHeroNumber == 0 Then Return GetMyID()
	Return MemoryRead(GetHerosArrayPtr() + (0x18 * ($aHeroNumber - 1)),'long')
EndFunc   ;==>GetHeroID
Func GetHeroNumberByAgentID($aAgentID) ;~ Description: Returns hero number by agent ID.
	$aAgentID = GetAgentID($aAgentID)
	For $i = 1 To GetHeroCount()
		If GetHeroID($i) == $aAgentID Then Return $i
	Next
	Return 0
EndFunc   ;==>GetHeroNumberByAgentID
Func GetHeroNumberByHeroID($aHeroId) ;~ Description: Returns hero number by hero ID i.e. The PlayerID (ModelID) used to identify the character, NOT the AgentID
	$aHeroId = ConvertID($aHeroId)
	Local $lHerosArrayPtr = GetHerosArrayPtr()
	For $i = 1 To GetHeroCount()
		If MemoryRead($lHerosArrayPtr + 8 + (0x18 * ($aHeroNumber - 1))) == $aHeroId Then Return $i
	Next
	Return 0
EndFunc   ;==>GetHeroNumberByHeroID
Func GetHeroProfession($aHeroNumber, $aSecondary = False) ;~ Description: Returns hero's profession ID (when it can't be found by other means)
	$aHeroNumber = GetHeroID($aHeroNumber)
	Local $lProfessionBasePtr = MemoryRead(GetInstanceBasePtr() + 0x6BC,'ptr')
	For $i = 0 To GetHeroCount()
		If MemoryRead($lProfessionBasePtr + ($i * 0x14)) <> $aHeroNumber Then ContinueLoop ; AgentID doesn't match this hero
		Return MemoryRead($lProfessionBasePtr + ($i * 0x14) + ($aSecondary ? 8 : 4)) ; Offset 4 = Primary, 8 = Secondary
	Next
EndFunc   ;==>GetHeroProfession

;~ Description: Tests if a hero's skill slot is disabled.
Func GetIsHeroSkillSlotDisabled($aHeroNumber, $aSkillSlot)
	Return BitAND(2 ^ ($aSkillSlot - 1), DllStructGetData(GetSkillbar($aHeroNumber), 'Disabled')) > 0
EndFunc   ;==>GetIsHeroSkillSlotDisabled
#EndRegion H&H

#Region Agent
Func GetAgentProperty($aAgent,$aPropertyName, $aNoCache = False) ;~ Description: Fetch property of an agent, either ptr or dllstruct. $aNoCache will force a memory read for that value.
	If IsNumber($aAgent) Or $aNoCache Then $aAgent = GetAgentPtr($aAgent) ; Pointer based - no need to load whole struct into memory for 1 value
	If IsDllStruct($aAgent) Then Return DllStructGetData($aAgent,$aPropertyName)
	If IsPtr($aAgent) Then
		Local $aStructElementInfo = Eval('mAgentStructInfo_'&$aPropertyName)
		If Not IsArray($aStructElementInfo) Then Return ; Invalid property name.
		Return MemoryRead($aAgent + $aStructElementInfo[1],$aStructElementInfo[0])
	EndIf
EndFunc
Func GetAgentByID($aAgentID = -2,$aExistingStructToUse=0) ;~ Description: Returns an agent struct. Pass $aExistingStructToUse to load the data into the given struct.
	If IsDllStruct($aAgentID) Then Return $aAgentID ; Already a DllStruct
	Return GetAgentByPtr(GetAgentPtr($aAgentID),$aExistingStructToUse)
EndFunc   ;==>GetAgentByID
Func GetAgentBy($aPropertyName,$aPropertyValue,$aAgentType=0) ; Returns agent by property value - used internally. Pass agenttype (i.e. 0xDB) for speed
	Local $lAgentArray = GetAgentArray($aAgentType)
	For $i=1 To $lAgentArray[0]
		If GetAgentProperty($lAgentArray[$i],$aPropertyName) == $aPropertyValue Then Return $lAgentArray[$i]
	Next
EndFunc
Func GetAgentByPtr($aAgentPtr,$aAgentStruct=0) ; Converts Ptr of an Item into DllStruct - used internally. OPTIONAL: Include the struct to be used.
	If Not $aAgentPtr Then Return 0
	Return MemoryReadStruct($aAgentPtr,$aAgentStruct ? $aAgentStruct : $mAgentStructStr)
EndFunc
Func GetAgentPtr($aAgentID) ;~ Description: Internal use for GetAgentByID() and other Agent functions
	If IsPtr($aAgentID) Then Return $aAgentID ; Already a pointer, presume Agent Ptr.
	Local $lOffset[3] = [0, 4 * GetAgentID($aAgentID), 0]
	Local $lAgentStructAddress = MemoryReadPtr($mAgentBase, $lOffset)
	Return $lAgentStructAddress[0]
EndFunc   ;==>GetAgentPtr
Func GetAgentExists($aAgentID = -2) ;~ Description: Test if an agent exists.
	Return (GetAgentPtr($aAgentID) > 0 And GetAgentID($aAgentID) < GetMaxAgents())
EndFunc   ;==>GetAgentExists
Func GetTarget($aAgent = -2) ;~ Description: Returns the target of an agent.
	$aAgent = GetAgentID($aAgent)
	If Not $aAgent Then Return 0
	Return MemoryRead(GetValue('TargetLogBase') + 4 * $aAgent)
EndFunc   ;==>GetTarget
Func GetAgentByPlayerName($aPlayerName) ;~ Description: Returns agent by player name.
	For $i = 1 To GetMaxAgents()
		If GetPlayerName($i) = $aPlayerName Then Return GetAgentByID($i)
	Next
EndFunc   ;==>GetAgentByPlayerName
Func GetAgentByName($aName,$aIsRetry=0) ;~ Description: Returns agent by name.
	Local $lName, $lAddress

	For $i = 1 To GetMaxAgents()
		$lAddress = $mStringLogBase + 256 * $i
		$lName = MemoryRead($lAddress, 'wchar [128]')
		$lName = StringRegExpReplace($lName, '[<]{1}([^>]+)[>]{1}', '')
		If StringInStr($lName, $aName) > 0 Then Return GetAgentByID($i)
	Next
	If $aIsRetry Then Return ; Already tried DisplayAll
	DisplayAll(True)
	Sleep(100)
	DisplayAll(False)
	DisplayAll(True)
	Sleep(100)
	DisplayAll(False)
	Return GetAgentByName($aName,1)
EndFunc   ;==>GetAgentByName
Func GetNearestEnemyToAgent($aAgent = -2,$lAgentArray=0) ;~ Description: Returns the nearest enemy to an agent.
	Local $lAgentCoords = GetAgentXY($aAgent)
	Return GetNearestEnemyToCoords($lAgentCoords[0],$lAgentCoords[1],$lAgentArray,GetAgentID($aAgent))
EndFunc   ;==>GetNearestEnemyToAgent
Func GetNearestEnemyToCoords($aX, $aY, $lAgentArray=0, $aExcludeAgentID=0) ;~ Description: Returns the nearest enemy to a set of coordinates. Add aExcludeAgentID to exclude another enemy.
	Local $lNearestAgent, $lNearestDistance = 100000000
	Local $lDistance
	If $lAgentArray = 0 Then $lAgentArray = GetAgentArray(0xDB)

	For $i = 1 To $lAgentArray[0]
		If $aExcludeAgentID And GetAgentID($lAgentArray[$i]) == $aExcludeAgentID Then ContinueLoop
		If Not GetIsEnemy($lAgentArray[$i]) Then ContinueLoop ; Not an enemy
		If Not GetIsAlive($lAgentArray[$i]) Then ContinueLoop ; Is not alive
		Local $lAgentCoords= GetAgentXY($lAgentArray[$i])
		$lDistance = ComputePseudoDistance($aX,$aY,$lAgentCoords[0],$lAgentCoords[1])
		If $lDistance > $lNearestDistance Then ContinueLoop
		$lNearestAgent = $lAgentArray[$i]
		$lNearestDistance = $lDistance
	Next
	SetExtended(Sqrt($lNearestDistance))
	Return $lNearestAgent
EndFunc
Func GetNearestAgentToAgent($aAgent = -2,$lAgentArray=0) ;~ Description: Returns the nearest agent to an agent.
	Local $lAgentCoords = GetAgentXY($aAgent)
	Return GetNearestAgentToCoords($lAgentCoords[0],$lAgentCoords[1],$lAgentArray,GetAgentID($aAgent))
EndFunc   ;==>GetNearestAgentToAgent
Func GetNearestAgentToCoords($aX, $aY, $lAgentArray=0, $aExcludeAgentID=0) ;~ Description: Returns the nearest agent to a set of coordinates. Add aExcludeAgentID to exclude current player.
	Local $lNearestAgent, $lNearestDistance = 100000000
	Local $lDistance
	If $lAgentArray = 0 Then $lAgentArray = GetAgentArray()

	For $i = 1 To $lAgentArray[0]
		If $aExcludeAgentID And GetAgentID($lAgentArray[$i]) == $aExcludeAgentID Then ContinueLoop
		Local $lAgentCoords= GetAgentXY($lAgentArray[$i])
		$lDistance = ComputePseudoDistance($aX,$aY,$lAgentCoords[0],$lAgentCoords[1])
		If $lDistance > $lNearestDistance Then ContinueLoop
		$lNearestAgent = $lAgentArray[$i]
		$lNearestDistance = $lDistance
	Next
	SetExtended(Sqrt($lNearestDistance))
	Return $lNearestAgent
EndFunc   ;==>GetNearestAgentToCoords
Func GetNearestSignpostToAgent($aAgent = -2) ;~ Description: Returns the nearest signpost to an agent.
	Local $lAgentCoords = GetAgentXY($aAgent)
	Return GetNearestSignpostToCoords($lAgentCoords[0],$lAgentCoords[1])
EndFunc   ;==>GetNearestSignpostToAgent
Func GetNearestSignpostToCoords($aX, $aY);~ Description: Returns the nearest signpost to a set of coordinates.
	Local $lNearestAgent, $lNearestDistance = 100000000
	Local $lDistance
	Local $lAgentArray = GetAgentArray(0x200)

	For $i = 1 To $lAgentArray[0]
		Local $lAgentCoords= GetAgentXY($lAgentArray[$i])
		$lDistance = ComputePseudoDistance($aX,$aY,$lAgentCoords[0],$lAgentCoords[1])
		If $lDistance > $lNearestDistance Then ContinueLoop
		$lNearestAgent = $lAgentArray[$i]
		$lNearestDistance = $lDistance
	Next
	SetExtended(Sqrt($lNearestDistance))
	Return $lNearestAgent
EndFunc   ;==>GetNearestSignpostToCoords
Func GetNearestNPCToAgent($aAgent = -2) ;~ Description: Returns the nearest NPC to an agent.
	Local $lAgentCoords = GetAgentXY($aAgent)
	Return GetNearestNPCToCoords($lAgentCoords[0],$lAgentCoords[1],GetAgentArray(0xDB),GetAgentID($aAgent))
EndFunc   ;==>GetNearestNPCToAgent
Func GetNearestNPCToCoords($aX, $aY, $lAgentArray=0, $aExcludeAgentID=0) ;~ Description: Returns the nearest NPC to a set of coordinates. Add aExcludeAgentID to exclude another NPC.
	Local $lNearestAgent, $lNearestDistance = 100000000
	Local $lDistance
	If $lAgentArray = 0 Then $lAgentArray = GetAgentArray(0xDB)

	For $i = 1 To $lAgentArray[0]
		If GetAgentProperty($lAgentArray[$i],'Allegiance') <> 6 Then ContinueLoop
		If Not GetIsAlive($lAgentArray[$i]) Then ContinueLoop
		If $aExcludeAgentID And $aExcludeAgentID = GetAgentID($lAgentArray[$i]) Then ContinueLoop
		Local $lAgentCoords= GetAgentXY($lAgentArray[$i])
		$lDistance = ComputePseudoDistance($aX,$aY,$lAgentCoords[0],$lAgentCoords[1])
		If $lDistance > $lNearestDistance Then ContinueLoop
		$lNearestAgent = $lAgentArray[$i]
		$lNearestDistance = $lDistance
	Next
	SetExtended(Sqrt($lNearestDistance))
	Return $lNearestAgent
EndFunc   ;==>GetNearestNPCToCoords
Func GetNearestItemToAgent($aAgent = -2, $aCanPickUp = True) ;~ Description: Returns the nearest item to an agent.
	Local $lAgentCoords = GetAgentXY($aAgent)
	Return GetNearestNPCToCoords($lAgentCoords[0],$lAgentCoords[1],$aCanPickUp,GetAgentArray(0x400),GetAgentID($aAgent))
EndFunc   ;==>GetNearestItemToAgent
Func GetNearestItemToCoords($aX, $aY, $aCanPickUp = True, $lAgentArray=0, $aExcludeAgentID=0) ;~ Description: Returns the nearest Item to a set of coordinates. Add aExcludeAgentID to exclude another item.
	Local $lNearestAgent, $lNearestDistance = 100000000
	Local $lDistance
	If $lAgentArray = 0 Then $lAgentArray = GetAgentArray(0x400)

	For $i = 1 To $lAgentArray[0]
		If $aCanPickUp And Not GetCanPickUp($lAgentArray[$i]) Then ContinueLoop ; Can't pick up.
		If $aExcludeAgentID And $aExcludeAgentID = GetAgentID($lAgentArray[$i]) Then ContinueLoop
		Local $lAgentCoords= GetAgentXY($lAgentArray[$i])
		$lDistance = ComputePseudoDistance($aX,$aY,$lAgentCoords[0],$lAgentCoords[1])
		If $lDistance > $lNearestDistance Then ContinueLoop
		$lNearestAgent = $lAgentArray[$i]
		$lNearestDistance = $lDistance
	Next
	SetExtended(Sqrt($lNearestDistance))
	Return $lNearestAgent
EndFunc   ;==>GetNearestItemToCoords
Func GetParty($aAgentArray = 0) ;~ Description: Returns array of party members
	Local $lReturnArray[17]
	$lReturnArray[0] = 0
	If $aAgentArray==0 Then $aAgentArray = GetAgentArray(0xDB)
	For $i = 1 To $aAgentArray[0]
		If GetAgentProperty($aAgentArray[$i],'Allegiance') <> 1 Then ContinueLoop
		If Not BitAND(GetAgentProperty($aAgentArray[$i],'TypeMap'), 131072) Then ContinueLoop
		$lReturnArray[0] += 1
		$lReturnArray[$lReturnArray[0]] = $aAgentArray[$i]
	Next
	ReDim $lReturnArray[$lReturnArray[0] + 1]
	Return $lReturnArray
EndFunc   ;==>GetParty
Func GetAgentArray($aType = 0) ;~ Description: Quickly creates an array of agents of a given type
	Local $lStruct
	Local $lCount
	Local $lBuffer = ''
	DllStructSetData($mMakeAgentArray, 2, $aType)
	MemoryWrite($mAgentCopyCount, -1, 'long')
	Enqueue($mMakeAgentArrayPtr, 8)
	Local $lDeadlock = TimerInit()
	Do
		Sleep(1)
		$lCount = MemoryRead($mAgentCopyCount, 'long')
	Until $lCount >= 0 Or TimerDiff($lDeadlock) > 5000
	If $lCount < 0 Then $lCount = 0
	For $i = 1 To $lCount
		$lBuffer &= 'Byte['&$mAgentStructSize&'];'
	Next
	$lBuffer = DllStructCreate($lBuffer)
	DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $mAgentCopyBase, 'ptr', DllStructGetPtr($lBuffer), 'int', DllStructGetSize($lBuffer), 'int', '')
	Local $lReturnArray[$lCount + 1] = [$lCount]
	For $i = 1 To $lCount
		$lReturnArray[$i] = DllStructCreate($mAgentStructStr)
		$lStruct = DllStructCreate('byte['&$mAgentStructSize&']', DllStructGetPtr($lReturnArray[$i]))
		DllStructSetData($lStruct, 1, DllStructGetData($lBuffer, $i))
	Next
	Return $lReturnArray
EndFunc   ;==>GetAgentArray
Func GetPartySize()
    Local $lSize = 0
    For $i=0 To 2
		$lSize += MemoryRead(GetPartyBasePtr() + ($i * 0x10) + 0xC)
    Next
    Return $lSize
EndFunc
Func GetPartyDanger($aAgentArray = 0, $aParty = 0) ;~ Description Returns the "danger level" of each party member
	;~ Param1: an array returned by GetAgentArray(). This is totally optional, but can greatly improve script speed.
	;~ Param2: an array returned by GetParty() This is totally optional, but can greatly improve script speed.
	If $aAgentArray == 0 Then $aAgentArray = GetAgentArray(0xDB)
	If $aParty == 0 Then $aParty = GetParty($aAgentArray)
	
	Local $lReturnArray[$aParty[0]+1]
	$lReturnArray[0] = $aParty[0]
	For $j=1 To $aParty[0]
		$lReturnArray[$i] = GetAgentDanger($aParty[$i],$aAgentArray)
	Next
	Return $lReturnArray
EndFunc
Func GetAgentDanger($aAgent = -2, $aAgentArray = 0) ;~ Description: Return the number of enemy agents targeting the given agent.
	$aAgent = GetAgentByID($aAgent)
	Local $lCount = 0, $iAllegiance, $iAgentID
	Local $lAgentID = GetAgentID($aAgent), $lTeam = GetAgentProperty($aAgent,'Team'),$lAllegiance = GetAgentProperty($aAgent,'Allegiance')
	If $aAgentArray == 0 Then $aAgentArray = GetAgentArray(0xDB) ; Get all living agents
	For $i=1 To $aAgentArray[0]
		If Not GetIsAlive($aAgentArray[$i]) Then ContinueLoop ; Not alive
		$iAllegiance = GetAgentProperty($aAgentArray[$i],'Allegiance')
		If $iAllegiance > 3 Then ContinueLoop						; ignore NPCs, spirits, minions, pets
		$iAgentID = GetAgentID($aAgentArray[$i])
		If GetTarget($iAgentID) <> $lAgentID Then ContinueLoop 		; Not targeted.
		If GetDistance($aAgentArray[$i], $aAgent) > 4999 Then ContinueLoop ; Too far away to be dangerous
		If $lTeam Then
			If GetAgentProperty($aAgentArray[$i],'Team') <> $lTeam Then $lCount += 1
		ElseIf $lAllegiance <> $iAllegiance Then
			$lCount += 1
		EndIf
	Next
	Return $lCount
EndFunc
#EndRegion Agent

#Region AgentInfo
Func GetAgentXY($aAgent = -2) ;~ Description: Get Agent X and Y value as Array
	If IsNumber($aAgent) Then $aAgent = GetAgentPtr($aAgent)
	If IsPtr($aAgent) Then $aAgent = MemoryReadStruct($aAgent + $mAgentStructInfo_X[1],'float X;float Y')
	Local $xy[2] = [0,0]
	If IsDllStruct($aAgent) Then
		$xy[0] = DllStructGetData($aAgent, 'X')
		$xy[1] = DllStructGetData($aAgent, 'Y')
	EndIf
	Return $xy
EndFunc
Func GetAgentMoveXY($aAgent = -2) ;~ Description: Get Agent MoveX and MoveY value as Array
	If IsNumber($aAgent) Then $aAgent = GetAgentPtr($aAgent)
	If IsPtr($aAgent) Then $aAgent = MemoryReadStruct($aAgent + $mAgentStructInfo_MoveX[1],'float MoveX;float MoveY')
	Local $xy[2] = [0,0]
	If IsDllStruct($aAgent) Then
		$xy[0] = DllStructGetData($aAgent, 'MoveX')
		$xy[1] = DllStructGetData($aAgent, 'MoveY')
	EndIf
	Return $xy
EndFunc
Func GetAgentID($aAgent) ;~ Description: Returns the ID of an agent.
	If IsNumber($aAgent) Then Return ConvertID($aAgent)
	Return GetAgentProperty($aAgent,'ID')
EndFunc
Func GetIsLiving($aAgent = -2) ;~ Description: Tests if an agent is living.
	Return GetAgentProperty($aAgent,'Type') = 0xDB
EndFunc   ;==>GetIsLiving
Func GetIsStatic($aAgent) ;~ Description: Tests if an agent is a signpost/chest/etc.
	Return GetAgentProperty($aAgent,'Type') = 0x200
EndFunc   ;==>GetIsStatic
Func GetIsMovable($aAgent) ;~ Description: Tests if an agent is an item.
	Return GetAgentProperty($aAgent,'Type') = 0x400
EndFunc   ;==>GetIsMovable
Func GetEnergy($aAgent = -2) ;~ Description: Returns energy of an agent. (Only self/heroes)
	If IsNumber($aAgent) Then $aAgent = GetAgentPtr($aAgent)
	If IsPtr($aAgent) Then $aAgent = MemoryReadStruct($aAgent + $mAgentStructInfo_EnergyPercent[1], 'float EnergyPercent;long MaxEnergy')
	If IsDllStruct($aAgent) Then Return DllStructGetData($aAgent, 'EnergyPercent') * DllStructGetData($aAgent, 'MaxEnergy')
EndFunc   ;==>GetEnergy
Func GetHealth($aAgent = -2) ;~ Description: Returns health of an agent. (Must have caused numerical change in health)
	If IsNumber($aAgent) Then $aAgent = GetAgentPtr($aAgent)
	If IsPtr($aAgent) Then $aAgent = MemoryReadStruct($aAgent + $mAgentStructInfo_HP[1], 'float HP;long MaxHP')
	If IsDllStruct($aAgent) Then Return DllStructGetData($aAgent, 'HP') * DllStructGetData($aAgent, 'MaxHP')
EndFunc   ;==>GetHealth
Func GetIsMoving($aAgent = -2) ;~ Description: Tests if an agent is moving.
	Local $xy = GetAgentMoveXY($aAgent)
	Return $xy[0] <> 0 Or $xy[1] <> 0
EndFunc   ;==>GetIsMoving
Func GetIsKnocked($aAgent = -2) ;~ Description: Tests if an agent is knocked down.
	Return GetModelState($aAgent) = 0x450
EndFunc   ;==>GetIsKnocked
Func GetIsAttacking($aAgent = -2) ;~ Description: Tests if an agent is attacking.
	Switch GetModelState($aAgent)
		Case 0x60 ; Is Attacking
			Return True
		Case 0x440 ; Is Attacking
			Return True
		Case 0x460 ; Is Attacking
			Return True
	EndSwitch
	Return False
EndFunc   ;==>GetIsAttacking
Func GetIsCasting($aAgent = -2) ;~ Description: Tests if an agent is casting.
	Return GetAgentProperty($aAgent, 'Skill') <> 0
EndFunc   ;==>GetIsCasting
Func GetIsBleeding($aAgent = -2) ;~ Description: Tests if an agent is bleeding.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x0001) > 0
EndFunc   ;==>GetIsBleeding
Func GetHasCondition($aAgent = -2) ;~ Description: Tests if an agent has a condition.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x0002) > 0
EndFunc   ;==>GetHasCondition
Func GetIsEnemy($aAgent = -1) ;~ Description: Tests if an agent is an enemy to the player
	Return GetAgentProperty($aAgent,'Allegiance') == 3
EndFunc
Func GetIsAlive($aAgent = -2) ;~ Description: Tests if an agent is alive i.e. NOT dead, has at least 1 HP, and is able to "live"
	$aAgent = GetAgentByID($aAgent)
	Return Not GetIsDead($aAgent) And GetAgentProperty($aAgent,'HP') > 0 And GetIsLiving($aAgent)
EndFunc
Func GetIsDead($aAgent = -2) ;~ Description: Tests if an agent is dead.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x0010) > 0
EndFunc   ;==>GetIsDead
Func GetHasDeepWound($aAgent = -2) ;~ Description: Tests if an agent has a deep wound.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x0020) > 0
EndFunc   ;==>GetHasDeepWound
Func GetIsPoisoned($aAgent = -2) ;~ Description: Tests if an agent is poisoned.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x0040) > 0
EndFunc   ;==>GetIsPoisoned
Func GetIsEnchanted($aAgent = -2) ;~ Description: Tests if an agent is enchanted.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x0080) > 0
EndFunc   ;==>GetIsEnchanted
Func GetHasDegenHex($aAgent = -2) ;~ Description: Tests if an agent has a degen hex.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x0400) > 0
EndFunc   ;==>GetHasDegenHex
Func GetHasHex($aAgent = -2) ;~ Description: Tests if an agent is hexed.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x0800) > 0
EndFunc   ;==>GetHasHex
Func GetHasWeaponSpell($aAgent = -2) ;~ Description: Tests if an agent has a weapon spell.
	Return BitAND(GetAgentProperty($aAgent,'Effects'), 0x8000) > 0
EndFunc   ;==>GetHasWeaponSpell
Func GetIsBoss($aAgent) ;~ Description: Tests if an agent is a boss.
	Return BitAND(GetAgentProperty($aAgent,'TypeMap'), 1024) > 0
EndFunc   ;==>GetIsBoss
Func GetPlayerName($aAgent = -2) ;~ Description: Returns a player's name.
	Local $lLogin = GetAgentProperty($aAgent,'LoginNumber')
	If Not $lLogin Then Return ''
	Local $lOffset[6] = [0, 76 * $lLogin + 0x28, 0]
	Local $lReturn = MemoryReadPtr(GetInstanceBasePtr() + 0x80C, $lOffset, 'wchar[30]')
	Return $lReturn[1]
EndFunc   ;==>GetPlayerName
Func GetAgentName($aAgent = -2) ;~ Description: Returns the name of an agent.
	Local $lAgentID = GetAgentID($aAgent)
	If $lAgentID = 0 Then Return ''
	Local $lAddress = $mStringLogBase + 256 * $lAgentID
	Local $lName = MemoryRead($lAddress, 'wchar [128]')

	If $lName = '' Then
		DisplayAll(True)
		Sleep(100)
		DisplayAll(False)
	EndIf

	Local $lName = MemoryRead($lAddress, 'wchar [128]')
	$lName = StringRegExpReplace($lName, '[<]{1}([^>]+)[>]{1}', '')
	Return $lName
EndFunc   ;==>GetAgentName
#EndRegion AgentInfo

#Region Buffs and Effects (e.g. Ongoing enchantments, Disease, Crippled, Environment Effects)

Func GetStatusArraySize() ;~ Description: Returns current number of status arrays available (i.e. one status array per hero)
	Return MemoryRead(GetInstanceBasePtr() + 0x510)
EndFunc
Func GetStatusArrayPtr($aHeroNumber = 0) ;~ Description: Returns ptr to a status (buff/condition/effect etc) array. Each array belongs to 1 person.
	If IsPtr($aHeroNumber) Then Return $aHeroNumber ; If $aHeroNumber is a Pointer, presume it is already The status array ptr for this hero.
	Local $lStatusArrayPtr = MemoryRead(GetInstanceBasePtr() + 0x508,'ptr'), $lHeroID = GetHeroID($aHeroNumber)
	For $i = 0 To GetStatusArraySize() - 1
		$lStatusArrayPtr += 0x24 * $i
		If MemoryRead($lStatusArrayPtr) == $lHeroID Then Return $lStatusArrayPtr
	Next
	Return 0 ; Status array for this hero not found.
EndFunc
Func GetBuffs($aHeroNumber = 0) ;~ Description: Returns array of Buffs on player. Index 0 is array size.
	Local $lStatusArrayPtr = GetStatusArrayPtr($aHeroNumber), $lStatuses[1] = [0], $lCount
	If $lStatusArrayPtr = 0 Then Return $lStatuses
	$lCount = GetBuffCount($lStatusArrayPtr)
	ReDim $lStatuses[$lCount+1]
	$lStatuses[0] = $lCount
	For $i = 0 To $lCount - 1
		$lStatuses[$i+1] = GetBuffByIndex($i, $lStatusArrayPtr)
	Next
	Return $lStatuses
EndFunc
Func GetEffects($aHeroNumber = 0) ;~ Description: Returns array of Effects on player. Index 0 is array size.
	Local $lStatusArrayPtr = GetStatusArrayPtr($aHeroNumber), $lStatuses[1] = [0], $lCount
	If $lStatusArrayPtr = 0 Then Return $lStatuses
	$lCount = GetEffectCount($lStatusArrayPtr)
	ReDim $lStatuses[$lCount+1]
	$lStatuses[0] = $lCount
	For $i = 0 To $lCount - 1
		$lStatuses[$i+1] = GetEffectByIndex($i, $lStatusArrayPtr)
	Next
	Return $lStatuses
EndFunc
Func GetEffectByIndex($aIndex, $aHeroNumber = 0) ;~ Description: Returns buff struct.
	Local $lStatusArrayPtr = GetStatusArrayPtr($aHeroNumber), $lStruct = DllStructCreate('long SkillId;long EffectType;long EffectId;long AgentId;float Duration;long TimeStamp')
	If $lStatusArrayPtr = 0 Then Return 0
	Local $lEffectsPtr = MemoryRead($lStatusArrayPtr + 0x14,'ptr')
	If $lEffectsPtr = 0 Then Return 0
	DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $lEffectsPtr + (24 * $aIndex), 'ptr', DllStructGetPtr($lStruct), 'int', DllStructGetSize($lStruct), 'int', '')
	Return $lStruct
EndFunc
Func GetBuffByIndex($aIndex, $aHeroNumber = 0) ;~ Description: Returns buff struct.
	Local $lStatusArrayPtr = GetStatusArrayPtr($aHeroNumber), $lStruct = DllStructCreate('long SkillId;byte unknown1[4];long BuffId;long TargetId')
	If $lStatusArrayPtr = 0 Then Return 0
	DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', MemoryRead($lStatusArrayPtr + 4 + (16 * $aIndex)), 'ptr', DllStructGetPtr($lStruct), 'int', DllStructGetSize($lStruct), 'int', '')
	Return $lStruct
EndFunc
Func GetEffectCount($aHeroNumber = 0)
	Local $lStatusArrayPtr = GetStatusArrayPtr($aHeroNumber)
	Return ($lStatusArrayPtr = 0 ? 0 : MemoryRead($lStatusArrayPtr + 0x1C))
EndFunc
Func GetEffect($aSkillID = 0, $aHeroNumber = 0) ;~ Description: Returns effect struct or array of effects.
	Local $lEffects = GetEffects($aHeroNumber)
	If $aSkillID = 0 Then Return $lEffects ; Is no skill ID, return whole array.
	For $i = 1 To $lEffects[0]
		If DllStructGetData($lEffects[$i], 'SkillID') = $aSkillID Then Return $lEffects[$i]
	Next
	Return $lEffects ; Bug - shouldn't this return value be 0 ? Kept it as is for legacy code...
EndFunc   ;==>GetEffect
Func GetEffectTimeRemaining($aEffect) ;~ Description: Returns time remaining before an effect expires, in milliseconds.
	If Not IsDllStruct($aEffect) Then $aEffect = GetEffect($aEffect)
	If IsArray($aEffect) Then Return 0
	Return DllStructGetData($aEffect, 'Duration') * 1000 - (GetSkillTimer() - DllStructGetData($aEffect, 'TimeStamp'))
EndFunc   ;==>GetEffectTimeRemaining
Func GetBuffCount($aHeroNumber = 0)
	Local $lStatusArrayPtr = GetStatusArrayPtr($aHeroNumber)
	Return ($lStatusArrayPtr = 0 ? 0 : MemoryRead($lStatusArrayPtr + 0xC))
EndFunc   ;==>GetBuffCount
Func GetIsTargetBuffed($aSkillID, $aAgentID, $aHeroNumber = 0) ;~ Description: Tests if you are currently maintaining buff on target.
	Local $lBuffs = GetBuffs($aHeroNumber)
	$aAgentID = GetAgentID($aAgentID)
	For $i=1 To $lBuffs[0]
		If (DllStructGetData($lBuffs[$i], 'SkillID') == $aSkillID) And (DllStructGetData($lBuffs[$i], 'TargetId') == $aAgentID) Then Return $i
	Next
	Return 0
EndFunc   ;==>GetIsTargetBuffed
#EndRegion Buffs and Effects

#Region Misc
Func GetSkillbarProperty($aSkillBarOrHeroNumber=0,$aPropertyName=0, $aNoCache = False) ;~ Description: Fetch property of a hero (or skill bar), either ptr or dllstruct. $aNoCache will force a memory read for that value.
	If IsNumber($aSkillBarOrHeroNumber) Or $aNoCache Then $aSkillBarOrHeroNumber = GetSkillbarPtr($aSkillBarOrHeroNumber) ; Pointer based - no need to load whole struct into memory for 1 value
	If IsDllStruct($aSkillBarOrHeroNumber) Then Return DllStructGetData($aSkillBarOrHeroNumber,$aPropertyName)
	If IsPtr($aSkillBarOrHeroNumber) Then
		Local $aStructElementInfo = Eval('mSkillBarStructInfo_'&$aPropertyName)
		If Not IsArray($aStructElementInfo) Then Return ; Invalid property name.
		Return MemoryRead($aSkillBarOrHeroNumber + $aStructElementInfo[1],$aStructElementInfo[0])
	EndIf
EndFunc
Func GetSkillbarPtr($aHeroNumber = 0) ;~ Description: Returns skillbar struct. Used internally.
	Local $lAgentID = GetHeroID($aHeroNumber), $lSkillBarPtr = MemoryRead(GetInstanceBasePtr() + 0x6F0,'ptr')
	For $i = 0 To GetHeroCount()
		$lSkillBarPtr += $i * 0xBC
		If MemoryRead($lSkillBarPtr) == $lAgentID Then Return $lSkillBarPtr
	Next
	Return 0
EndFunc
Func GetSkillbar($aHeroNumber = 0) ;~ Description: Returns skillbar struct.
	Local $lSkillBarPtr = GetSkillbarPtr($aHeroNumber)
	If Not $lSkillBarPtr Then Return 0 ;  Not found.
	Return MemoryReadStruct($lSkillBarPtr,$mSkillBarStructStr)
EndFunc   ;==>GetSkillbar
Func GetSkillbarSkillID($aSkillSlot, $aSkillBarOrHeroNumber = 0) ;~ Description: Returns the skill ID of an equipped skill.
	Return GetSkillbarProperty($aSkillBarOrHeroNumber, 'ID' & $aSkillSlot)
EndFunc   ;==>GetSkillbarSkillID
Func GetSkillbarSkillAdrenaline($aSkillSlot, $aSkillBarOrHeroNumber = 0) ;~ Description: Returns the adrenaline charge of an equipped skill.
	Return GetSkillbarProperty($aSkillBarOrHeroNumber, 'AdrenalineA' & $aSkillSlot)
EndFunc   ;==>GetSkillbarSkillAdrenaline
Func GetSkillbarSkillRecharge($aSkillSlot, $aSkillBarOrHeroNumber = 0) ;~ Description: Returns the recharge time remaining of an equipped skill in milliseconds.
	Local $lTimestamp = GetSkillbarProperty($aSkillBarOrHeroNumber, 'Recharge' & $aSkillSlot)
	If $lTimestamp == 0 Then Return 0
	Return $lTimestamp - GetSkillTimer()
EndFunc   ;==>GetSkillbarSkillRecharge
Func GetSkillByID($aSkillID) ;~ Description: Returns skill struct.
	If IsDllStruct($aSkillID) Then Return $aSkillID
	Local $lSkillStruct = DllStructCreate($mSkillStructStr)
	Local $lSkillStructAddress = $mSkillBase + 160 * $aSkillID
	DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $lSkillStructAddress, 'ptr', DllStructGetPtr($lSkillStruct), 'int', DllStructGetSize($lSkillStruct), 'int', '')
	Return $lSkillStruct
EndFunc   ;==>GetSkillByID

;~ Description: Returns energy cost of a skill.
Func GetEnergyCost($aSkillId)
   Local $lInitCost = DllStructGetData(GetSkillByID($aSkillId), 'energy')
   Switch $lInitCost
         Case 11
            Return 15
         Case 12
            Return 25
         Case Else
            Return $lInitCost
    EndSwitch
EndFunc   ;==>GetEnergyCost

;~ Description: Returns current morale.
Func GetMorale($aHeroNumber = 0)
	Local $lAgentID = GetHeroID($aHeroNumber)
	Local $lIndex = MemoryRead(GetInstanceBasePtr() + 0x638)
	Local $lOffset[3] = [0,8 + 0xC * BitAND($lAgentID, $lIndex),0x18]
	Local $lReturn = MemoryReadPtr(GetInstanceBasePtr() + 0x62C, $lOffset)
	Return $lReturn[1] - 100
EndFunc   ;==>GetMorale

;~ Description: Returns the timestamp used for effects and skills (milliseconds).
Func GetSkillTimer()
	Return MemoryRead($mSkillTimer, "long")
EndFunc   ;==>GetSkillTimer

;~ Description: Returns level of an attribute.
Func GetAttributeByID($aAttributeID, $aWithRunes = False, $aHeroNumber = 0)
	Local $lAgentID = GetHeroID($aHeroNumber), $lAttributePtr = MemoryRead(GetInstanceBasePtr() + 0xAC,'ptr')
	For $i = 0 To GetHeroCount()
		$lAttributePtr += 0x3D8 * $i
		If MemoryRead($lAttributePtr) <> $lAgentID Then ContinueLoop
		Return MemoryRead($lAttributePtr + 0x14 * $aAttributeID + ($aWithRunes ? 0xC : 0x8))
	Next
EndFunc   ;==>GetAttributeByID

;~ Description: Returns amount of experience.
Func GetExperience()
	Return MemoryRead(GetInstanceBasePtr() + 0x740)
EndFunc   ;==>GetExperience

;~ Description: Tests if an area has been vanquished.
Func GetAreaVanquished()
	Return GetFoesToKill() == 0
EndFunc   ;==>GetAreaVanquished

;~ Description: Returns number of foes that have been killed so far.
Func GetFoesKilled()
	Return MemoryRead(GetInstanceBasePtr() + 0x84C)
EndFunc   ;==>GetFoesKilled

;~ Description: Returns number of enemies left to kill for vanquish.
Func GetFoesToKill()
	Return MemoryRead(GetInstanceBasePtr() + 0x850)
EndFunc   ;==>GetFoesToKill

;~ Description: Returns number of agents currently loaded.
Func GetMaxAgents()
	Return MemoryRead($mMaxAgents)
EndFunc   ;==>GetMaxAgents

;~ Description: Returns your agent ID.
Func GetMyID()
	Return MemoryRead($mMyID)
EndFunc   ;==>GetMyID

;~ Description: Returns current target.
Func GetCurrentTarget()
	Return GetAgentByID(GetCurrentTargetID())
EndFunc   ;==>GetCurrentTarget

;~ Description: Returns current target ID.
Func GetCurrentTargetID()
	Return MemoryRead($mCurrentTarget)
EndFunc   ;==>GetCurrentTargetID

;~ Description: Returns current ping.
Func GetPing()
	Return MemoryRead($mPing)
EndFunc   ;==>GetPing

;~ Description: Returns current map ID.
Func GetMapID()
	Return MemoryRead($mMapID)
EndFunc   ;==>GetMapID

;~ Description: Returns current load-state.
Func GetMapLoading()
	Return MemoryRead($mMapLoading)
EndFunc   ;==>GetMapLoading

;~ Description: Returns if map has been loaded. Reset with InitMapLoad().
Func GetMapIsLoaded()
	Return MemoryRead($mMapIsLoaded) And GetAgentExists(-2) And GetCharname()
EndFunc   ;==>GetMapIsLoaded
Func GetDistrict() ;~ Description: Returns current district
	Local $lOffset[4] = [0, 0x18, 0x44, 0x1B4]
	Local $lResult = MemoryReadPtr($mBasePointer, $lOffset)
	Return $lResult[1]
EndFunc   ;==>GetDistrict
Func GetRegion() ;~ Description: Internal use for travel functions.
	Return MemoryRead($mRegion)
EndFunc   ;==>GetRegion
Func GetLanguage() ;~ Description: Internal use for travel functions.
	Return MemoryRead($mLanguage)
EndFunc   ;==>GetLanguage
;~ Description: Wait for map to load. Returns true if successful.
Func WaitMapLoading($aMapID = 0, $aDeadlock = 15000)
;~ 	Waits $aDeadlock for load to start, and $aDeadLock for agent to load after map is loaded.
	Local $lMapLoading, $lDeadlock = TimerInit()
	InitMapLoad()
	Do
		Sleep(100)
		$lMapLoading = GetMapLoading()
		If $lMapLoading == 2 Then $lDeadlock = TimerInit()
		If TimerDiff($lDeadlock) > $aDeadlock And $aDeadlock > 0 Then Return False
	Until $lMapLoading <> 2 And GetMapIsLoaded() And (GetMapID() = $aMapID Or $aMapID = 0)
	RndSleep(500)
	Return True
EndFunc   ;==>WaitMapLoading
Func GetQuestByID($aQuestID = 0) ;~ Description: Returns quest struct.
	Local $lQuestStruct = DllStructCreate('long id;long LogState;byte unknown1[12];long MapFrom;float X;float Y;byte unknown2[8];long MapTo')
	Local $lQuestPtr = MemoryRead(GetInstanceBasePtr() + 0x52C,'ptr'), $lQuestLogSize = MemoryRead(GetInstanceBasePtr() + 0x534)
	If $aQuestID = 0 Then $aQuestID = MemoryRead(GetInstanceBasePtr() + 0x528) ; Default to current quest.
	For $i = 0 To $lQuestLogSize
		$lQuestStruct = MemoryReadStruct($lQuestPtr + (0x34 * $i),$lQuestStruct)
		If DllStructGetData($lQuestStruct, 'ID') = $lQuestID Then Return $lQuestStruct
	Next
EndFunc   ;==>GetQuestByID
Func GetCharname() ;~ Description: Returns your characters name.
	Return MemoryRead($mCharname, 'wchar[30]')
EndFunc   ;==>GetCharname
Func GetLoggedIn() ;~ Description: Returns if you're logged in.
	Return MemoryRead($mLoggedIn)
EndFunc   ;==>GetLoggedIn
Func GetCharacterSlots() ;~ Description: Returns the number of character slots you have. Only works on character select.
	Return MemoryRead($mCharslots)
EndFunc   ;==>GetLoggedIn
Func GetDisplayLanguage() ;~ Description: Returns language currently being used.
	Local $lOffset[6] = [0, 0x18, 0x18, 0x194, 0x4C, 0x40]
	Local $lResult = MemoryReadPtr($mBasePointer, $lOffset)
	Return $lResult[1]
EndFunc   ;==>GetDisplayLanguage
Func GetInstanceUpTime() ;~ Returns how long the current instance has been active, in milliseconds.
	Local $lOffset[4] = [0,0x18,0x8,0x1AC]
	Local $lTimer = MemoryReadPtr($mBasePointer, $lOffset)
	Return $lTimer[1]
EndFunc   ;==>GetInstanceUpTime
Func GetBuildNumber() ;~ Returns the game client's build number
	Return $mBuildNumber
EndFunc   ;==>GetBuildNumber
Func GetProfPrimaryAttribute($aProfession)
	Switch $aProfession
		Case 1
			Return 17
		Case 2
			Return 23
		Case 3
			Return 16
		Case 4
			Return 6
		Case 5
			Return 0
		Case 6
			Return 12
		Case 7
			Return 35
		Case 8
			Return 36
		Case 9
			Return 40
		Case 10
			Return 44
	EndSwitch
EndFunc   ;==>GetProfPrimaryAttribute
#EndRegion Misc
#EndRegion Queries

#Region Other Functions
#Region Misc

Func RndSleep($aAmount, $aRandom = 0.05) ;~ Description: Sleep a random amount of time.
	Local $lRandom = $aAmount * $aRandom
	Sleep(Random($aAmount - $lRandom, $aAmount + $lRandom))
EndFunc   ;==>RndSleep
Func TolSleep($aAmount = 150, $aTolerance = 50) ;~ Description: Sleep a period of time, plus or minus a tolerance
	Sleep(Random($aAmount - $aTolerance, $aAmount + $aTolerance))
EndFunc   ;==>TolSleep
Func GetWindowHandle() ;~ Description: Returns window handle of Guild Wars.
	Return $mGWWindowHandle
EndFunc   ;==>GetWindowHandle
Func ComputeDistance($aX1, $aY1, $aX2, $aY2) ;~ Description: Returns the distance between two coordinate pairs.
	Return Sqrt(ComputePseudoDistance($aX1, $aY1, $aX2, $aY2))
EndFunc   ;==>ComputeDistance
Func ComputePseudoDistance($aX1, $aY1, $aX2, $aY2) ;~ Description: Returns the distance between two coordinate pairs, without sqrt for speed in comparisons.
	Return ($aX1 - $aX2) ^ 2 + ($aY1 - $aY2) ^ 2
EndFunc   ;==>ComputeDistance
Func GetDistance($aAgent1 = -1, $aAgent2 = -2) ;~ Description: Returns the distance between two agents.
	Local $lAgent1XY = GetAgentXY($aAgent1), $lAgent2XY = GetAgentXY($aAgent2)
	Return ComputeDistance($lAgent1XY[0],$lAgent1XY[1],$lAgent2XY[0],$lAgent2XY[1])
EndFunc   ;==>GetDistance
Func GetPseudoDistance($aAgent1 = -1, $aAgent2 = -2) ;~ Description: Return the distance between two agents, without sqrt for speed in comparisons.
	Local $lAgent1XY = GetAgentXY($aAgent1), $lAgent2XY = GetAgentXY($aAgent2)
	Return ComputePseudoDistance($lAgent1XY[0],$lAgent1XY[1],$lAgent2XY[0],$lAgent2XY[1])
EndFunc   ;==>GetPseudoDistance
Func GetIsPointInPolygon($aAreaCoords, $aPosX = 0, $aPosY = 0) ;~ Description: Checks if a point is within a polygon defined by an array
	Local $lPosition
	Local $lEdges = UBound($aAreaCoords)
	Local $lOddNodes = False
	If $lEdges < 3 Then Return False
	If $aPosX = 0 Then
		Local $lAgent = GetAgentByID(-2)
		$aPosX = DllStructGetData($lAgent, 'X')
		$aPosY = DllStructGetData($lAgent, 'Y')
	EndIf
	$j = $lEdges - 1
	For $i = 0 To $lEdges - 1
		If (($aAreaCoords[$i][1] < $aPosY And $aAreaCoords[$j][1] >= $aPosY) _
				Or ($aAreaCoords[$j][1] < $aPosY And $aAreaCoords[$i][1] >= $aPosY)) _
				And ($aAreaCoords[$i][0] <= $aPosX Or $aAreaCoords[$j][0] <= $aPosX) Then
			If ($aAreaCoords[$i][0] + ($aPosY - $aAreaCoords[$i][1]) / ($aAreaCoords[$j][1] - $aAreaCoords[$i][1]) * ($aAreaCoords[$j][0] - $aAreaCoords[$i][0]) < $aPosX) Then
				$lOddNodes = Not $lOddNodes
			EndIf
		EndIf
		$j = $i
	Next
	Return $lOddNodes
EndFunc   ;==>GetIsPointInPolygon
Func ConvertID($aID) ;~ Description: Internal use for handing -1 and -2 agent IDs.
	If $aID = -2 Then Return GetMyID()
	If $aID = -1 Then Return GetCurrentTargetID()
	Return $aID
EndFunc   ;==>ConvertID
Func SendPacket($aSize, $aHeader, $aParam1 = 0, $aParam2 = 0, $aParam3 = 0, $aParam4 = 0, $aParam5 = 0, $aParam6 = 0, $aParam7 = 0, $aParam8 = 0, $aParam9 = 0, $aParam10 = 0) ;~ Description: Internal use only.
	If Not GetAgentExists(-2) Then Return False
	DllStructSetData($mPacket, 2, $aSize)
	DllStructSetData($mPacket, 3, $aHeader)
	For $i = 1 To 10
		DllStructSetData($mPacket, $i+3, Eval('aParam'&$i))
	Next
	Return Enqueue($mPacketPtr, 52)
EndFunc   ;==>SendPacket
Func PerformAction($aAction, $aFlag) ;~ Description: Internal use only.
	If Not GetAgentExists(-2) Then Return False
	DllStructSetData($mAction, 2, $aAction)
	DllStructSetData($mAction, 3, $aFlag)
	Return Enqueue($mActionPtr, 12)
EndFunc   ;==>PerformAction
Func Bin64ToDec($aBinary) ;~ Description: Internal use only.
	Local $lReturn = 0
	For $i = 1 To StringLen($aBinary)
		If StringMid($aBinary, $i, 1) == 1 Then $lReturn += 2 ^ ($i - 1)
	Next
	Return $lReturn
EndFunc   ;==>Bin64ToDec
Func Base64ToBin64($aCharacter) ;~ Description: Internal use only.
	Select
		Case $aCharacter == "A"
			Return "000000"
		Case $aCharacter == "B"
			Return "100000"
		Case $aCharacter == "C"
			Return "010000"
		Case $aCharacter == "D"
			Return "110000"
		Case $aCharacter == "E"
			Return "001000"
		Case $aCharacter == "F"
			Return "101000"
		Case $aCharacter == "G"
			Return "011000"
		Case $aCharacter == "H"
			Return "111000"
		Case $aCharacter == "I"
			Return "000100"
		Case $aCharacter == "J"
			Return "100100"
		Case $aCharacter == "K"
			Return "010100"
		Case $aCharacter == "L"
			Return "110100"
		Case $aCharacter == "M"
			Return "001100"
		Case $aCharacter == "N"
			Return "101100"
		Case $aCharacter == "O"
			Return "011100"
		Case $aCharacter == "P"
			Return "111100"
		Case $aCharacter == "Q"
			Return "000010"
		Case $aCharacter == "R"
			Return "100010"
		Case $aCharacter == "S"
			Return "010010"
		Case $aCharacter == "T"
			Return "110010"
		Case $aCharacter == "U"
			Return "001010"
		Case $aCharacter == "V"
			Return "101010"
		Case $aCharacter == "W"
			Return "011010"
		Case $aCharacter == "X"
			Return "111010"
		Case $aCharacter == "Y"
			Return "000110"
		Case $aCharacter == "Z"
			Return "100110"
		Case $aCharacter == "a"
			Return "010110"
		Case $aCharacter == "b"
			Return "110110"
		Case $aCharacter == "c"
			Return "001110"
		Case $aCharacter == "d"
			Return "101110"
		Case $aCharacter == "e"
			Return "011110"
		Case $aCharacter == "f"
			Return "111110"
		Case $aCharacter == "g"
			Return "000001"
		Case $aCharacter == "h"
			Return "100001"
		Case $aCharacter == "i"
			Return "010001"
		Case $aCharacter == "j"
			Return "110001"
		Case $aCharacter == "k"
			Return "001001"
		Case $aCharacter == "l"
			Return "101001"
		Case $aCharacter == "m"
			Return "011001"
		Case $aCharacter == "n"
			Return "111001"
		Case $aCharacter == "o"
			Return "000101"
		Case $aCharacter == "p"
			Return "100101"
		Case $aCharacter == "q"
			Return "010101"
		Case $aCharacter == "r"
			Return "110101"
		Case $aCharacter == "s"
			Return "001101"
		Case $aCharacter == "t"
			Return "101101"
		Case $aCharacter == "u"
			Return "011101"
		Case $aCharacter == "v"
			Return "111101"
		Case $aCharacter == "w"
			Return "000011"
		Case $aCharacter == "x"
			Return "100011"
		Case $aCharacter == "y"
			Return "010011"
		Case $aCharacter == "z"
			Return "110011"
		Case $aCharacter == "0"
			Return "001011"
		Case $aCharacter == "1"
			Return "101011"
		Case $aCharacter == "2"
			Return "011011"
		Case $aCharacter == "3"
			Return "111011"
		Case $aCharacter == "4"
			Return "000111"
		Case $aCharacter == "5"
			Return "100111"
		Case $aCharacter == "6"
			Return "010111"
		Case $aCharacter == "7"
			Return "110111"
		Case $aCharacter == "8"
			Return "001111"
		Case $aCharacter == "9"
			Return "101111"
		Case $aCharacter == "+"
			Return "011111"
		Case $aCharacter == "/"
			Return "111111"
	EndSelect
EndFunc   ;==>Base64ToBin64
#EndRegion Misc

#Region Callback
;~ Description: Controls Event System.
Func SetEvent($aSkillActivate = '', $aSkillCancel = '', $aSkillComplete = '', $aChatReceive = '', $aLoadFinished = '')
	If $aSkillActivate <> '' Then
		WriteDetour('SkillLogStart', 'SkillLogProc')
	Else
		$mASMString = ''
		_('inc eax')
		_('mov dword[esi+10],eax')
		_('pop esi')
		WriteBinary($mASMString, GetValue('SkillLogStart'))
	EndIf

	If $aSkillCancel <> '' Then
		WriteDetour('SkillCancelLogStart', 'SkillCancelLogProc')
	Else
		$mASMString = ''
		_('push 0')
		_('push 42')
		_('mov ecx,esi')
		WriteBinary($mASMString, GetValue('SkillCancelLogStart'))
	EndIf

	If $aSkillComplete <> '' Then
		WriteDetour('SkillCompleteLogStart', 'SkillCompleteLogProc')
	Else
		$mASMString = ''
		_('mov eax,dword[edi+4]')
		_('test eax,eax')
		WriteBinary($mASMString, GetValue('SkillCompleteLogStart'))
	EndIf

	If $aChatReceive <> '' Then
		WriteDetour('ChatLogStart', 'ChatLogProc')
	Else
		$mASMString = ''
		_('add edi,E')
		_('cmp eax,B')
		WriteBinary($mASMString, GetValue('ChatLogStart'))
	EndIf

	$mSkillActivate = $aSkillActivate
	$mSkillCancel = $aSkillCancel
	$mSkillComplete = $aSkillComplete
	$mChatReceive = $aChatReceive
	$mLoadFinished = $aLoadFinished
EndFunc   ;==>SetEvent

;~ Description: Internal use for event system.
;~ modified by gigi, avoid getagentbyid, just pass agent id to callback
Func Event($hwnd, $msg, $wparam, $lparam)
	Switch $lparam
		Case 0x1
			DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $wparam, 'ptr', $mSkillLogStructPtr, 'int', 16, 'int', '')
			Call($mSkillActivate, DllStructGetData($mSkillLogStruct, 1), DllStructGetData($mSkillLogStruct, 2), DllStructGetData($mSkillLogStruct, 3), DllStructGetData($mSkillLogStruct, 4))
		Case 0x2
			DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $wparam, 'ptr', $mSkillLogStructPtr, 'int', 16, 'int', '')
			Call($mSkillCancel, DllStructGetData($mSkillLogStruct, 1), DllStructGetData($mSkillLogStruct, 2), DllStructGetData($mSkillLogStruct, 3))
		Case 0x3
			DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $wparam, 'ptr', $mSkillLogStructPtr, 'int', 16, 'int', '')
			Call($mSkillComplete, DllStructGetData($mSkillLogStruct, 1), DllStructGetData($mSkillLogStruct, 2), DllStructGetData($mSkillLogStruct, 3))
		Case 0x4
			DllCall($mKernelHandle, 'int', 'ReadProcessMemory', 'int', $mGWProcHandle, 'int', $wparam, 'ptr', $mChatLogStructPtr, 'int', 512, 'int', '')
			Local $lMessage = DllStructGetData($mChatLogStruct, 2)
			Local $lChannel
			Local $lSender
			Switch DllStructGetData($mChatLogStruct, 1)
				Case 0
					$lChannel = "Alliance"
					$lSender = StringMid($lMessage, 6, StringInStr($lMessage, "</a>") - 6)
					$lMessage = StringTrimLeft($lMessage, StringInStr($lMessage, "<quote>") + 6)
				Case 3
					$lChannel = "All"
					$lSender = StringMid($lMessage, 6, StringInStr($lMessage, "</a>") - 6)
					$lMessage = StringTrimLeft($lMessage, StringInStr($lMessage, "<quote>") + 6)
				Case 9
					$lChannel = "Guild"
					$lSender = StringMid($lMessage, 6, StringInStr($lMessage, "</a>") - 6)
					$lMessage = StringTrimLeft($lMessage, StringInStr($lMessage, "<quote>") + 6)
				Case 11
					$lChannel = "Team"
					$lSender = StringMid($lMessage, 6, StringInStr($lMessage, "</a>") - 6)
					$lMessage = StringTrimLeft($lMessage, StringInStr($lMessage, "<quote>") + 6)
				Case 12
					$lChannel = "Trade"
					$lSender = StringMid($lMessage, 6, StringInStr($lMessage, "</a>") - 6)
					$lMessage = StringTrimLeft($lMessage, StringInStr($lMessage, "<quote>") + 6)
				Case 10
					If StringLeft($lMessage, 3) == "-> " Then
						$lChannel = "Sent"
						$lSender = StringMid($lMessage, 10, StringInStr($lMessage, "</a>") - 10)
						$lMessage = StringTrimLeft($lMessage, StringInStr($lMessage, "<quote>") + 6)
					Else
						$lChannel = "Global"
						$lSender = "Guild Wars"
					EndIf
				Case 13
					$lChannel = "Advisory"
					$lSender = "Guild Wars"
					$lMessage = StringTrimLeft($lMessage, StringInStr($lMessage, "<quote>") + 6)
				Case 14
					$lChannel = "Whisper"
					$lSender = StringMid($lMessage, 7, StringInStr($lMessage, "</a>") - 7)
					$lMessage = StringTrimLeft($lMessage, StringInStr($lMessage, "<quote>") + 6)
				Case Else
					$lChannel = "Other"
					$lSender = "Other"
			EndSwitch
			Call($mChatReceive, $lChannel, $lSender, $lMessage)
		Case 0x5
			Call($mLoadFinished)
	EndSwitch
EndFunc   ;==>Event
#EndRegion Callback

#Region Modification
;~ Description: Internal use only.
Func ModifyMemory()
	$mASMSize = 0
	$mASMCodeOffset = 0
	$mASMString = ''

	CreateData()
	CreateMain()
	CreateTargetLog()
	CreateSkillLog()
	CreateSkillCancelLog()
	CreateSkillCompleteLog()
	CreateChatLog()
	CreateTraderHook()
	CreateLoadFinished()
	CreateStringLog()
	CreateStringFilter1()
	CreateStringFilter2()
	CreateRenderingMod()
	CreateCommands()

	Local $lModMemory = MemoryRead(MemoryRead($mBase), 'ptr')

	If $lModMemory = 0 Then
		$mMemory = DllCall($mKernelHandle, 'ptr', 'VirtualAllocEx', 'handle', $mGWProcHandle, 'ptr', 0, 'ulong_ptr', $mASMSize, 'dword', 0x1000, 'dword', 0x40)
		$mMemory = $mMemory[0]
		MemoryWrite(MemoryRead($mBase), $mMemory)
	Else
		$mMemory = $lModMemory
	EndIf

	CompleteASMCode()

	If $lModMemory = 0 Then
		WriteBinary($mASMString, $mMemory + $mASMCodeOffset)

		WriteBinary("83F8009090", GetValue('ClickToMoveFix'))
		MemoryWrite(GetValue('QueuePtr'), GetValue('QueueBase'))
		MemoryWrite(GetValue('SkillLogPtr'), GetValue('SkillLogBase'))
		MemoryWrite(GetValue('ChatLogPtr'), GetValue('ChatLogBase'))
		MemoryWrite(GetValue('StringLogPtr'), GetValue('StringLogBase'))
	EndIf

	WriteDetour('MainStart', 'MainProc')
	WriteDetour('TargetLogStart', 'TargetLogProc')
	WriteDetour('TraderHookStart', 'TraderHookProc')
	WriteDetour('LoadFinishedStart', 'LoadFinishedProc')
	WriteDetour('RenderingMod', 'RenderingModProc')
	WriteDetour('StringLogStart', 'StringLogProc')
	WriteDetour('StringFilter1Start', 'StringFilter1Proc')
	WriteDetour('StringFilter2Start', 'StringFilter2Proc')
EndFunc   ;==>ModifyMemory

;~ Description: Internal use only.
Func WriteDetour($aFrom, $aTo)
	WriteBinary('E9' & SwapEndian(Hex(GetLabelInfo($aTo) - GetLabelInfo($aFrom) - 5)), GetLabelInfo($aFrom))
EndFunc   ;==>WriteDetour

;~ Description: Internal use only.
Func CreateData()
	_('CallbackHandle/4')
	_('QueueCounter/4')
	_('SkillLogCounter/4')
	_('ChatLogCounter/4')
	_('ChatLogLastMsg/4')
	_('MapIsLoaded/4')
	_('NextStringType/4')
	_('EnsureEnglish/4')
	_('TraderQuoteID/4')
	_('TraderCostID/4')
	_('TraderCostValue/4')
	_('DisableRendering/4')
	_('QueueBase/' & 256 * GetValue('QueueSize'))
	_('TargetLogBase/' & 4 * GetValue('TargetLogSize'))
	_('SkillLogBase/' & 16 * GetValue('SkillLogSize'))
	_('StringLogBase/' & 256 * GetValue('StringLogSize'))
	_('ChatLogBase/' & 512 * GetValue('ChatLogSize'))
	_('AgentCopyCount/4')
	_('AgentCopyBase/' & 0x1C0 * 256)
EndFunc   ;==>CreateData

;~ Description: Internal use only.
Func CreateMain()
	_('MainProc:')
	_('pushad')
	_('mov eax,dword[EnsureEnglish]')
	_('test eax,eax')
	_('jz MainMain')

	_('mov ecx,dword[BasePointer]')
	_('mov ecx,dword[ecx+18]')
	_('mov ecx,dword[ecx+18]')
	_('mov ecx,dword[ecx+194]')
	_('mov al,byte[ecx+4f]')
	_('cmp al,f')
	_('ja MainMain')
	_('mov ecx,dword[ecx+4c]')
	_('mov al,byte[ecx+3f]')
	_('cmp al,f')
	_('ja MainMain')
	_('mov eax,dword[ecx+40]')
	_('test eax,eax')
	_('jz MainMain')

	_('mov ecx,dword[ActionBase]')
	_('mov ecx,dword[ecx+170]')
	_('mov ecx,dword[ecx+20]')
	_('mov ecx,dword[ecx]')
	_('push 0')
	_('push 0')
	_('push bb')
	_('mov edx,esp')
	_('push 0')
	_('push edx')
	_('push 18')
	_('call ActionFunction')
	_('pop eax')
	_('pop ebx')
	_('pop ecx')

	_('MainMain:')
	_('mov eax,dword[QueueCounter]')
	_('mov ecx,eax')
	_('shl eax,8')
	_('add eax,QueueBase')
	_('mov ebx,dword[eax]')
	_('test ebx,ebx')
	_('jz MainExit')

	_('push ecx')
	_('mov dword[eax],0')
	_('jmp ebx')

	_('CommandReturn:')
	_('pop eax')
	_('inc eax')
	_('cmp eax,QueueSize')
	_('jnz MainSkipReset')
	_('xor eax,eax')
	_('MainSkipReset:')
	_('mov dword[QueueCounter],eax')

	_('MainExit:')
	_('popad')
	_('mov ebp,esp')
	_('sub esp,14')
	_('ljmp MainReturn')
EndFunc   ;==>CreateMain

;~ Description: Internal use only.
Func CreateTargetLog()
	_('TargetLogProc:')
	_('cmp ecx,4')
	_('jz TargetLogMain')
	_('cmp ecx,32')
	_('jz TargetLogMain')
	_('cmp ecx,3C')
	_('jz TargetLogMain')
	_('jmp TargetLogExit')

	_('TargetLogMain:')
	_('pushad')
	_('mov ecx,dword[ebp+8]')
	_('test ecx,ecx')
	_('jnz TargetLogStore')
	_('mov ecx,edx')

	_('TargetLogStore:')
	_('lea eax,dword[edx*4+TargetLogBase]')
	_('mov dword[eax],ecx')
	_('popad')

	_('TargetLogExit:')
	_('push ebx')
	_('push esi')
	_('push edi')
	_('mov edi,edx')
	_('ljmp TargetLogReturn')
EndFunc   ;==>CreateTargetLog

;~ Description: Internal use only.
Func CreateSkillLog()
	_('SkillLogProc:')
	_('pushad')

	_('mov eax,dword[SkillLogCounter]')
	_('push eax')
	_('shl eax,4')
	_('add eax,SkillLogBase')

	_('mov ecx,dword[edi]')
	_('mov dword[eax],ecx')
	_('mov ecx,dword[ecx*4+TargetLogBase]')
	_('mov dword[eax+4],ecx')
	_('mov ecx,dword[edi+4]')
	_('mov dword[eax+8],ecx')
	_('mov ecx,dword[edi+8]')
	_('mov dword[eax+c],ecx')

	_('push 1')
	_('push eax')
	_('push CallbackEvent')
	_('push dword[CallbackHandle]')
	_('call dword[PostMessage]')

	_('pop eax')
	_('inc eax')
	_('cmp eax,SkillLogSize')
	_('jnz SkillLogSkipReset')
	_('xor eax,eax')
	_('SkillLogSkipReset:')
	_('mov dword[SkillLogCounter],eax')

	_('popad')
	_('inc eax')
	_('mov dword[esi+10],eax')
	_('pop esi')
	_('ljmp SkillLogReturn')
EndFunc   ;==>CreateSkillLog

;~ Description: Internal use only.
Func CreateSkillCancelLog()
	_('SkillCancelLogProc:')
	_('pushad')

	_('mov eax,dword[SkillLogCounter]')
	_('push eax')
	_('shl eax,4')
	_('add eax,SkillLogBase')

	_('mov ecx,dword[edi]')
	_('mov dword[eax],ecx')
	_('mov ecx,dword[ecx*4+TargetLogBase]')
	_('mov dword[eax+4],ecx')
	_('mov ecx,dword[edi+4]')
	_('mov dword[eax+8],ecx')

	_('push 2')
	_('push eax')
	_('push CallbackEvent')
	_('push dword[CallbackHandle]')
	_('call dword[PostMessage]')

	_('pop eax')
	_('inc eax')
	_('cmp eax,SkillLogSize')
	_('jnz SkillCancelLogSkipReset')
	_('xor eax,eax')
	_('SkillCancelLogSkipReset:')
	_('mov dword[SkillLogCounter],eax')

	_('popad')
	_('push 0')
	_('push 42')
	_('mov ecx,esi')
	_('ljmp SkillCancelLogReturn')
EndFunc   ;==>CreateSkillCancelLog

;~ Description: Internal use only.
Func CreateSkillCompleteLog()
	_('SkillCompleteLogProc:')
	_('pushad')

	_('mov eax,dword[SkillLogCounter]')
	_('push eax')
	_('shl eax,4')
	_('add eax,SkillLogBase')

	_('mov ecx,dword[edi]')
	_('mov dword[eax],ecx')
	_('mov ecx,dword[ecx*4+TargetLogBase]')
	_('mov dword[eax+4],ecx')
	_('mov ecx,dword[edi+4]')
	_('mov dword[eax+8],ecx')

	_('push 3')
	_('push eax')
	_('push CallbackEvent')
	_('push dword[CallbackHandle]')
	_('call dword[PostMessage]')

	_('pop eax')
	_('inc eax')
	_('cmp eax,SkillLogSize')
	_('jnz SkillCompleteLogSkipReset')
	_('xor eax,eax')
	_('SkillCompleteLogSkipReset:')
	_('mov dword[SkillLogCounter],eax')

	_('popad')
	_('mov eax,dword[edi+4]')
	_('test eax,eax')
	_('ljmp SkillCompleteLogReturn')
EndFunc   ;==>CreateSkillCompleteLog

;~ Description: Internal use only.
Func CreateChatLog()
	_('ChatLogProc:')

	_('pushad')
	_('mov ecx,dword[ebx]')
	_('mov ebx,eax')
	_('mov eax,dword[ChatLogCounter]')
	_('push eax')
	_('shl eax,9')
	_('add eax,ChatLogBase')
	_('mov dword[eax],ebx')

	_('mov edi,eax')
	_('add eax,4')
	_('xor ebx,ebx')

	_('ChatLogCopyLoop:')
	_('mov dx,word[ecx]')
	_('mov word[eax],dx')
	_('add ecx,2')
	_('add eax,2')
	_('inc ebx')
	_('cmp ebx,FF')
	_('jz ChatLogCopyExit')
	_('test dx,dx')
	_('jnz ChatLogCopyLoop')

	_('ChatLogCopyExit:')
	_('push 4')
	_('push edi')
	_('push CallbackEvent')
	_('push dword[CallbackHandle]')
	_('call dword[PostMessage]')

	_('pop eax')
	_('inc eax')
	_('cmp eax,ChatLogSize')
	_('jnz ChatLogSkipReset')
	_('xor eax,eax')
	_('ChatLogSkipReset:')
	_('mov dword[ChatLogCounter],eax')
	_('popad')

	_('ChatLogExit:')
	_('add edi,E')
	_('cmp eax,B')
	_('ljmp ChatLogReturn')
EndFunc   ;==>CreateChatLog

;~ Description: Internal use only.
Func CreateTraderHook()
	_('TraderHookProc:')
	_('mov dword[TraderCostID],ecx')
	_('mov dword[TraderCostValue],edx')
	_('push eax')
	_('mov eax,dword[TraderQuoteID]')
	_('inc eax')
	_('cmp eax,200')
	_('jnz TraderSkipReset')
	_('xor eax,eax')
	_('TraderSkipReset:')
	_('mov dword[TraderQuoteID],eax')
	_('pop eax')
	_('mov ebp,esp')
	_('sub esp,8')
	_('ljmp TraderHookReturn')
EndFunc   ;==>CreateTraderHook

;~ Description: Internal use only.
Func CreateLoadFinished()
	_('LoadFinishedProc:')
	_('pushad')

	_('mov eax,1')
	_('mov dword[MapIsLoaded],eax')

	_('xor ebx,ebx')
	_('mov eax,StringLogBase')
	_('LoadClearStringsLoop:')
	_('mov dword[eax],0')
	_('inc ebx')
	_('add eax,80')
	_('cmp ebx,200')
	_('jnz LoadClearStringsLoop')

	_('xor ebx,ebx')
	_('mov eax,TargetLogBase')
	_('LoadClearTargetsLoop:')
	_('mov dword[eax],0')
	_('inc ebx')
	_('add eax,4')
	_('cmp ebx,200')
	_('jnz LoadClearTargetsLoop')

	_('push 5')
	_('push 0')
	_('push CallbackEvent')
	_('push dword[CallbackHandle]')
	_('call dword[PostMessage]')

	_('popad')
	_('mov esp,ebp')
	_('pop ebp')
	_('retn 10')
EndFunc   ;==>CreateLoadFinished

;~ Description: Internal use only.
Func CreateStringLog()
	_('StringLogProc:')
	_('pushad')
	_('mov eax,dword[NextStringType]')
	_('test eax,eax')
	_('jz StringLogExit')

	_('cmp eax,1')
	_('jnz StringLogFilter2')
	_('mov eax,dword[ebp+37c]')
	_('jmp StringLogRangeCheck')

	_('StringLogFilter2:')
	_('cmp eax,2')
	_('jnz StringLogExit')
	_('mov eax,dword[ebp+338]')

	_('StringLogRangeCheck:')
	_('mov dword[NextStringType],0')
	_('cmp eax,0')
	_('jbe StringLogExit')
	_('cmp eax,StringLogSize')
	_('jae StringLogExit')

	_('shl eax,8')
	_('add eax,StringLogBase')

	_('xor ebx,ebx')
	_('StringLogCopyLoop:')
	_('mov dx,word[ecx]')
	_('mov word[eax],dx')
	_('add ecx,2')
	_('add eax,2')
	_('inc ebx')
	_('cmp ebx,80')
	_('jz StringLogExit')
	_('test dx,dx')
	_('jnz StringLogCopyLoop')

	_('StringLogExit:')
	_('popad')
	_('mov esp,ebp')
	_('pop ebp')
	_('retn 10')
EndFunc   ;==>CreateStringLog

;~ Description: Internal use only.
Func CreateStringFilter1()
	_('StringFilter1Proc:')
	_('mov dword[NextStringType],1')

	_('push ebp')
	_('mov ebp,esp')
	_('push ecx')
	_('push esi')
	_('ljmp StringFilter1Return')
EndFunc   ;==>CreateStringFilter1

;~ Description: Internal use only.
Func CreateStringFilter2()
	_('StringFilter2Proc:')
	_('mov dword[NextStringType],2')

	_('push ebp')
	_('mov ebp,esp')
	_('push ecx')
	_('push esi')
	_('ljmp StringFilter2Return')
EndFunc   ;==>CreateStringFilter2

;~ Description: Internal use only.
Func CreateRenderingMod()
	_('RenderingModProc:')
	_('cmp dword[DisableRendering],1')
	_('jz RenderingModSkipCompare')
	_('cmp eax,ebx')
	_('ljne RenderingModReturn')
	_('RenderingModSkipCompare:')
	$mASMSize += 17
	$mASMString &= StringTrimLeft(MemoryRead(getvalue("RenderingMod") + 4, "byte[17]"), 2)

	_('cmp dword[DisableRendering],1')
	_('jz DisableRenderingProc')
	_('retn')

	_('DisableRenderingProc:')
	_('push 1')
	_('call dword[Sleep]')
	_('retn')
EndFunc   ;==>CreateRenderingMod

;~ Description: Internal use only.
Func CreateCommands()
	_('CommandUseSkill:')
	_('mov ecx,dword[MyID]')
	_('mov edx,dword[eax+C]')
	_('push edx')
	_('mov edx,dword[eax+4]')
	_('dec edx')
	_('push dword[eax+8]')
	_('call UseSkillFunction')
	_('ljmp CommandReturn')

	_('CommandMove:')
	_('lea ecx,dword[eax+4]')
	_('call MoveFunction')
	_('ljmp CommandReturn')

	_('CommandChangeTarget:')
	_('mov ecx,dword[eax+4]')
	_('xor edx,edx')
	_('call ChangeTargetFunction')
	_('ljmp CommandReturn')

	_('CommandPacketSend:')
	_('mov ecx,dword[PacketLocation]')
	_('lea edx,dword[eax+8]')
	_('push edx')
	_('mov edx,dword[eax+4]')
	_('mov eax,ecx')
	_('call PacketSendFunction')
	_('ljmp CommandReturn')

	_('CommandWriteChat:')
	_('add eax,4')
	_('mov edx,eax')
	_('xor ecx,ecx')
	_('add eax,28')
	_('push eax')
	_('call WriteChatFunction')
	_('ljmp CommandReturn')

	_('CommandSellItem:')
	_('push 0')
	_('push 0')
	_('push 0')
	_('push dword[eax+4]')
	_('push 0')
	_('add eax,8')
	_('push eax')
	_('push 1')
	_('mov ecx,b')
	_('xor edx,edx')
	_('call SellItemFunction')
	_('ljmp CommandReturn')

	_('CommandBuyItem:')
	_('add eax,4')
	_('push eax')
	_('add eax,4')
	_('push eax')
	_('push 1')
	_('push 0')
	_('push 0')
	_('push 0')
	_('push 0')
	_('mov ecx,1')
	_('mov edx,dword[eax+4]')
	_('call BuyItemFunction')
	_('ljmp CommandReturn')

	_('CommandAction:')
	_('mov ecx,dword[ActionBase]')
	_('mov ecx,dword[ecx+250]')
	_('mov ecx,dword[ecx+10]')
	_('mov ecx,dword[ecx]')
	_('push 0')
	_('push 0')
	_('push dword[eax+4]')
	_('mov edx,esp')
	_('push 0')
	_('push edx')
	_('push dword[eax+8]')
	_('call ActionFunction')
	_('pop eax')
	_('pop ebx')
	_('pop ecx')
	_('ljmp CommandReturn')

	_('CommandToggleLanguage:')
	_('mov ecx,dword[ActionBase]')
	_('mov ecx,dword[ecx+170]')
	_('mov ecx,dword[ecx+20]')
	_('mov ecx,dword[ecx]')
	_('push 0')
	_('push 0')
	_('push bb')
	_('mov edx,esp')
	_('push 0')
	_('push edx')
	_('push dword[eax+4]')
	_('call ActionFunction')
	_('pop eax')
	_('pop ebx')
	_('pop ecx')
	_('ljmp CommandReturn')

	_('CommandUseHeroSkill:')
	_('mov ecx,dword[eax+4]')
	_('mov edx,dword[eax+c]')
	_('mov eax,dword[eax+8]')
	_('push eax')
	_('call UseHeroSkillFunction')
	_('ljmp CommandReturn')

	_('CommandSendChat:')
	_('mov ecx,dword[PacketLocation]')
	_('add eax,4')
	_('push eax')
	_('mov edx,11c')
	_('mov eax,ecx')
	_('call PacketSendFunction')
	_('ljmp CommandReturn')

	_('CommandRequestQuote:')
	_('mov dword[TraderCostID],0')
	_('mov dword[TraderCostValue],0')
	_('add eax,4')
	_('push eax')
	_('push 1')
	_('push 0')
	_('push 0')
	_('push 0')
	_('push 0')
	_('mov ecx,c')
	_('xor edx,edx')
	_('call RequestQuoteFunction')
	_('ljmp CommandReturn')

	_('CommandRequestQuoteSell:')
	_('mov dword[TraderCostID],0')
	_('mov dword[TraderCostValue],0')
	_('push 0')
	_('push 0')
	_('push 0')
	_('add eax,4')
	_('push eax')
	_('push 1')
	_('push 0')
	_('mov ecx,d')
	_('xor edx,edx')
	_('call RequestQuoteFunction')
	_('ljmp CommandReturn')

	_('CommandTraderBuy:')
	_('push 0')
	_('push TraderCostID')
	_('push 1')
	_('push 0')
	_('push 0')
	_('push 0')
	_('push 0')
	_('mov ecx,c')
	_('mov edx,dword[TraderCostValue]')
	_('call TraderFunction')
	_('mov dword[TraderCostID],0')
	_('mov dword[TraderCostValue],0')
	_('ljmp CommandReturn')

	_('CommandTraderSell:')
	_('push 0')
	_('push 0')
	_('push 0')
	_('push dword[TraderCostValue]')
	_('push 0')
	_('push TraderCostID')
	_('push 1')
	_('mov ecx,d')
	_('xor edx,edx')
	_('call TraderFunction')
	_('mov dword[TraderCostID],0')
	_('mov dword[TraderCostValue],0')
	_('ljmp CommandReturn')

	_('CommandSalvage:')
	_('mov ebx,SalvageGlobal')
	_('mov ecx,dword[eax+4]')
	_('mov dword[ebx],ecx')
	_('push ecx')
	_('mov ecx,dword[eax+8]')
	_('add ebx,4')
	_('mov dword[ebx],ecx')
	_('mov edx,dword[eax+c]')
	_('mov dword[ebx],ecx')
	_('call SalvageFunction')
	_('ljmp CommandReturn')

	_('CommandMakeAgentArray:')
	_('mov eax,dword[eax+4]')
	_('xor ebx,ebx')
	_('xor edx,edx')
	_('mov edi,AgentCopyBase')

	_('AgentCopyLoopStart:')
	_('inc ebx')
	_('cmp ebx,dword[MaxAgents]')
	_('jge AgentCopyLoopExit')

	_('mov esi,dword[AgentBase]')
	_('lea esi,dword[esi+ebx*4]')
	_('mov esi,dword[esi]')
	_('test esi,esi')
	_('jz AgentCopyLoopStart')

	_('cmp eax,0')
	_('jz CopyAgent')
	_('cmp eax,dword[esi+9C]')
	_('jnz AgentCopyLoopStart')

	_('CopyAgent:')
	_('mov ecx,1C0')
	_('clc')
	_('repe movsb')
	_('inc edx')
	_('jmp AgentCopyLoopStart')

	_('AgentCopyLoopExit:')
	_('mov dword[AgentCopyCount],edx')
	_('ljmp CommandReturn')

	_('CommandChangeStatus:')
	_('mov ecx,dword[eax+4]')
	_('call ChangeStatusFunction')
	_('ljmp CommandReturn')
EndFunc   ;==>CreateCommands
#EndRegion Modification

#Region Assembler
;~ Description: Internal use only.
Func _($aASM)
	;quick and dirty x86assembler unit:
	;relative values stringregexp
	;static values hardcoded
	Local $lBuffer
	Select
		Case StringRight($aASM, 1) = ':'
			SetValue('Label_' & StringLeft($aASM, StringLen($aASM) - 1), $mASMSize)
		Case StringInStr($aASM, '/') > 0
			SetValue('Label_' & StringLeft($aASM, StringInStr($aASM, '/') - 1), $mASMSize)
			Local $lOffset = StringRight($aASM, StringLen($aASM) - StringInStr($aASM, '/'))
			$mASMSize += $lOffset
			$mASMCodeOffset += $lOffset
		Case StringLeft($aASM, 5) = 'nop x'
			$lBuffer = Int(Number(StringTrimLeft($aASM, 5)))
			$mASMSize += $lBuffer
			For $i = 1 To $lBuffer
				$mASMString &= '90'
			Next
		Case StringLeft($aASM, 5) = 'ljmp '
			$mASMSize += 5
			$mASMString &= 'E9{' & StringRight($aASM, StringLen($aASM) - 5) & '}'
		Case StringLeft($aASM, 5) = 'ljne '
			$mASMSize += 6
			$mASMString &= '0F85{' & StringRight($aASM, StringLen($aASM) - 5) & '}'
		Case StringLeft($aASM, 4) = 'jmp ' And StringLen($aASM) > 7
			$mASMSize += 2
			$mASMString &= 'EB(' & StringRight($aASM, StringLen($aASM) - 4) & ')'
		Case StringLeft($aASM, 4) = 'jae '
			$mASMSize += 2
			$mASMString &= '73(' & StringRight($aASM, StringLen($aASM) - 4) & ')'
		Case StringLeft($aASM, 3) = 'jz '
			$mASMSize += 2
			$mASMString &= '74(' & StringRight($aASM, StringLen($aASM) - 3) & ')'
		Case StringLeft($aASM, 4) = 'jnz '
			$mASMSize += 2
			$mASMString &= '75(' & StringRight($aASM, StringLen($aASM) - 4) & ')'
		Case StringLeft($aASM, 4) = 'jbe '
			$mASMSize += 2
			$mASMString &= '76(' & StringRight($aASM, StringLen($aASM) - 4) & ')'
		Case StringLeft($aASM, 3) = 'ja '
			$mASMSize += 2
			$mASMString &= '77(' & StringRight($aASM, StringLen($aASM) - 3) & ')'
		Case StringLeft($aASM, 3) = 'jl '
			$mASMSize += 2
			$mASMString &= '7C(' & StringRight($aASM, StringLen($aASM) - 3) & ')'
		Case StringLeft($aASM, 4) = 'jge '
			$mASMSize += 2
			$mASMString &= '7D(' & StringRight($aASM, StringLen($aASM) - 4) & ')'
		Case StringLeft($aASM, 4) = 'jle '
			$mASMSize += 2
			$mASMString &= '7E(' & StringRight($aASM, StringLen($aASM) - 4) & ')'
		Case StringRegExp($aASM, 'mov eax,dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 5
			$mASMString &= 'A1[' & StringMid($aASM, 15, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'mov ebx,dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 6
			$mASMString &= '8B1D[' & StringMid($aASM, 15, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'mov ecx,dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 6
			$mASMString &= '8B0D[' & StringMid($aASM, 15, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'mov edx,dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 6
			$mASMString &= '8B15[' & StringMid($aASM, 15, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'mov esi,dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 6
			$mASMString &= '8B35[' & StringMid($aASM, 15, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'mov edi,dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 6
			$mASMString &= '8B3D[' & StringMid($aASM, 15, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'cmp ebx,dword\[[a-z,A-Z]{4,}\]')
			$mASMSize += 6
			$mASMString &= '3B1D[' & StringMid($aASM, 15, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'lea eax,dword[[]ecx[*]8[+][a-z,A-Z]{4,}[]]')
			$mASMSize += 7
			$mASMString &= '8D04CD[' & StringMid($aASM, 21, StringLen($aASM) - 21) & ']'
		Case StringRegExp($aASM, 'lea edi,dword\[edx\+[a-z,A-Z]{4,}\]')
			$mASMSize += 7
			$mASMString &= '8D3C15[' & StringMid($aASM, 19, StringLen($aASM) - 19) & ']'
		Case StringRegExp($aASM, 'cmp dword[[][a-z,A-Z]{4,}[]],[-[:xdigit:]]')
			$lBuffer = StringInStr($aASM, ",")
			$lBuffer = ASMNumber(StringMid($aASM, $lBuffer + 1), True)
			If @extended Then
				$mASMSize += 7
				$mASMString &= '833D[' & StringMid($aASM, 11, StringInStr($aASM, ",") - 12) & ']' & $lBuffer
			Else
				$mASMSize += 10
				$mASMString &= '813D[' & StringMid($aASM, 11, StringInStr($aASM, ",") - 12) & ']' & $lBuffer
			EndIf
		Case StringRegExp($aASM, 'cmp ecx,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 6
			$mASMString &= '81F9[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'cmp ebx,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 6
			$mASMString &= '81FB[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'cmp eax,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 5
			$mASMString &= '3D[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'add eax,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 5
			$mASMString &= '05[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'mov eax,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 5
			$mASMString &= 'B8[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'mov ebx,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 5
			$mASMString &= 'BB[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'mov esi,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 5
			$mASMString &= 'BE[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'mov edi,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 5
			$mASMString &= 'BF[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'mov edx,[a-z,A-Z]{4,}') And StringInStr($aASM, ',dword') = 0
			$mASMSize += 5
			$mASMString &= 'BA[' & StringRight($aASM, StringLen($aASM) - 8) & ']'
		Case StringRegExp($aASM, 'mov dword[[][a-z,A-Z]{4,}[]],ecx')
			$mASMSize += 6
			$mASMString &= '890D[' & StringMid($aASM, 11, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'fstp dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 6
			$mASMString &= 'D91D[' & StringMid($aASM, 12, StringLen($aASM) - 12) & ']'
		Case StringRegExp($aASM, 'mov dword[[][a-z,A-Z]{4,}[]],edx')
			$mASMSize += 6
			$mASMString &= '8915[' & StringMid($aASM, 11, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'mov dword[[][a-z,A-Z]{4,}[]],eax')
			$mASMSize += 5
			$mASMString &= 'A3[' & StringMid($aASM, 11, StringLen($aASM) - 15) & ']'
		Case StringRegExp($aASM, 'lea eax,dword[[]edx[*]4[+][a-z,A-Z]{4,}[]]')
			$mASMSize += 7
			$mASMString &= '8D0495[' & StringMid($aASM, 21, StringLen($aASM) - 21) & ']'
		Case StringRegExp($aASM, 'mov eax,dword[[]ecx[*]4[+][a-z,A-Z]{4,}[]]')
			$mASMSize += 7
			$mASMString &= '8B048D[' & StringMid($aASM, 21, StringLen($aASM) - 21) & ']'
		Case StringRegExp($aASM, 'mov ecx,dword[[]ecx[*]4[+][a-z,A-Z]{4,}[]]')
			$mASMSize += 7
			$mASMString &= '8B0C8D[' & StringMid($aASM, 21, StringLen($aASM) - 21) & ']'
		Case StringRegExp($aASM, 'push dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 6
			$mASMString &= 'FF35[' & StringMid($aASM, 12, StringLen($aASM) - 12) & ']'
		Case StringRegExp($aASM, 'push [a-z,A-Z]{4,}\z')
			$mASMSize += 5
			$mASMString &= '68[' & StringMid($aASM, 6, StringLen($aASM) - 5) & ']'
		Case StringRegExp($aASM, 'call dword[[][a-z,A-Z]{4,}[]]')
			$mASMSize += 6
			$mASMString &= 'FF15[' & StringMid($aASM, 12, StringLen($aASM) - 12) & ']'
		Case StringLeft($aASM, 5) = 'call ' And StringLen($aASM) > 8
			$mASMSize += 5
			$mASMString &= 'E8{' & StringMid($aASM, 6, StringLen($aASM) - 5) & '}'
		Case StringRegExp($aASM, 'mov dword\[[a-z,A-Z]{4,}\],[-[:xdigit:]]{1,8}\z')
			$lBuffer = StringInStr($aASM, ",")
			$mASMSize += 10
			$mASMString &= 'C705[' & StringMid($aASM, 11, $lBuffer - 12) & ']' & ASMNumber(StringMid($aASM, $lBuffer + 1))
		Case StringRegExp($aASM, 'push [-[:xdigit:]]{1,8}\z')
			$lBuffer = ASMNumber(StringMid($aASM, 6), True)
			If @extended Then
				$mASMSize += 2
				$mASMString &= '6A' & $lBuffer
			Else
				$mASMSize += 5
				$mASMString &= '68' & $lBuffer
			EndIf
		Case StringRegExp($aASM, 'mov eax,[-[:xdigit:]]{1,8}\z')
			$mASMSize += 5
			$mASMString &= 'B8' & ASMNumber(StringMid($aASM, 9))
		Case StringRegExp($aASM, 'mov ebx,[-[:xdigit:]]{1,8}\z')
			$mASMSize += 5
			$mASMString &= 'BB' & ASMNumber(StringMid($aASM, 9))
		Case StringRegExp($aASM, 'mov ecx,[-[:xdigit:]]{1,8}\z')
			$mASMSize += 5
			$mASMString &= 'B9' & ASMNumber(StringMid($aASM, 9))
		Case StringRegExp($aASM, 'mov edx,[-[:xdigit:]]{1,8}\z')
			$mASMSize += 5
			$mASMString &= 'BA' & ASMNumber(StringMid($aASM, 9))
		Case StringRegExp($aASM, 'add eax,[-[:xdigit:]]{1,8}\z')
			$lBuffer = ASMNumber(StringMid($aASM, 9), True)
			If @extended Then
				$mASMSize += 3
				$mASMString &= '83C0' & $lBuffer
			Else
				$mASMSize += 5
				$mASMString &= '05' & $lBuffer
			EndIf
		Case StringRegExp($aASM, 'add ebx,[-[:xdigit:]]{1,8}\z')
			$lBuffer = ASMNumber(StringMid($aASM, 9), True)
			If @extended Then
				$mASMSize += 3
				$mASMString &= '83C3' & $lBuffer
			Else
				$mASMSize += 6
				$mASMString &= '81C3' & $lBuffer
			EndIf
		Case StringRegExp($aASM, 'add ecx,[-[:xdigit:]]{1,8}\z')
			$lBuffer = ASMNumber(StringMid($aASM, 9), True)
			If @extended Then
				$mASMSize += 3
				$mASMString &= '83C1' & $lBuffer
			Else
				$mASMSize += 6
				$mASMString &= '81C1' & $lBuffer
			EndIf
		Case StringRegExp($aASM, 'add edx,[-[:xdigit:]]{1,8}\z')
			$lBuffer = ASMNumber(StringMid($aASM, 9), True)
			If @extended Then
				$mASMSize += 3
				$mASMString &= '83C2' & $lBuffer
			Else
				$mASMSize += 6
				$mASMString &= '81C2' & $lBuffer
			EndIf
		Case StringRegExp($aASM, 'add edi,[-[:xdigit:]]{1,8}\z')
			$lBuffer = ASMNumber(StringMid($aASM, 9), True)
			If @extended Then
				$mASMSize += 3
				$mASMString &= '83C7' & $lBuffer
			Else
				$mASMSize += 6
				$mASMString &= '81C7' & $lBuffer
			EndIf
		Case StringRegExp($aASM, 'cmp ebx,[-[:xdigit:]]{1,8}\z')
			$lBuffer = ASMNumber(StringMid($aASM, 9), True)
			If @extended Then
				$mASMSize += 3
				$mASMString &= '83FB' & $lBuffer
			Else
				$mASMSize += 6
				$mASMString &= '81FB' & $lBuffer
			EndIf
		Case Else
			Local $lOpCode
			Switch $aASM
				Case 'nop'
					$lOpCode = '90'
				Case 'pushad'
					$lOpCode = '60'
				Case 'popad'
					$lOpCode = '61'
				Case 'mov ebx,dword[eax]'
					$lOpCode = '8B18'
				Case 'test eax,eax'
					$lOpCode = '85C0'
				Case 'test ebx,ebx'
					$lOpCode = '85DB'
				Case 'test ecx,ecx'
					$lOpCode = '85C9'
				Case 'mov dword[eax],0'
					$lOpCode = 'C70000000000'
				Case 'push eax'
					$lOpCode = '50'
				Case 'push ebx'
					$lOpCode = '53'
				Case 'push ecx'
					$lOpCode = '51'
				Case 'push edx'
					$lOpCode = '52'
				Case 'push ebp'
					$lOpCode = '55'
				Case 'push esi'
					$lOpCode = '56'
				Case 'push edi'
					$lOpCode = '57'
				Case 'jmp ebx'
					$lOpCode = 'FFE3'
				Case 'pop eax'
					$lOpCode = '58'
				Case 'pop ebx'
					$lOpCode = '5B'
				Case 'pop edx'
					$lOpCode = '5A'
				Case 'pop ecx'
					$lOpCode = '59'
				Case 'pop esi'
					$lOpCode = '5E'
				Case 'inc eax'
					$lOpCode = '40'
				Case 'inc ecx'
					$lOpCode = '41'
				Case 'inc ebx'
					$lOpCode = '43'
				Case 'dec edx'
					$lOpCode = '4A'
				Case 'mov edi,edx'
					$lOpCode = '8BFA'
				Case 'mov ecx,esi'
					$lOpCode = '8BCE'
				Case 'mov ecx,edi'
					$lOpCode = '8BCF'
				Case 'xor eax,eax'
					$lOpCode = '33C0'
				Case 'xor ecx,ecx'
					$lOpCode = '33C9'
				Case 'xor edx,edx'
					$lOpCode = '33D2'
				Case 'xor ebx,ebx'
					$lOpCode = '33DB'
				Case 'mov edx,eax'
					$lOpCode = '8BD0'
				Case 'mov ebp,esp'
					$lOpCode = '8BEC'
				Case 'sub esp,8'
					$lOpCode = '83EC08'
				Case 'sub esp,14'
					$lOpCode = '83EC14'
				Case 'cmp ecx,4'
					$lOpCode = '83F904'
				Case 'cmp ecx,32'
					$lOpCode = '83F932'
				Case 'cmp ecx,3C'
					$lOpCode = '83F93C'
				Case 'mov ecx,edx'
					$lOpCode = '8BCA'
				Case 'mov eax,ecx'
					$lOpCode = '8BC1'
				Case 'mov ecx,dword[ebp+8]'
					$lOpCode = '8B4D08'
				Case 'mov ecx,dword[esp+1F4]'
					$lOpCode = '8B8C24F4010000'
				Case 'mov ecx,dword[edi+4]'
					$lOpCode = '8B4F04'
				Case 'mov ecx,dword[edi+8]'
					$lOpCode = '8B4F08'
				Case 'mov eax,dword[edi+4]'
					$lOpCode = '8B4704'
				Case 'mov dword[eax+4],ecx'
					$lOpCode = '894804'
				Case 'mov dword[eax+8],ecx'
					$lOpCode = '894808'
				Case 'mov dword[eax+C],ecx'
					$lOpCode = '89480C'
				Case 'mov dword[esi+10],eax'
					$lOpCode = '894610'
				Case 'mov ecx,dword[edi]'
					$lOpCode = '8B0F'
				Case 'mov dword[eax],ecx'
					$lOpCode = '8908'
				Case 'mov dword[eax],ebx'
					$lOpCode = '8918'
				Case 'mov edx,dword[eax+4]'
					$lOpCode = '8B5004'
				Case 'mov edx,dword[eax+c]'
					$lOpCode = '8B500C'
				Case 'mov edx,dword[esi+1c]'
					$lOpCode = '8B561C'
				Case 'push dword[eax+8]'
					$lOpCode = 'FF7008'
				Case 'lea eax,dword[eax+18]'
					$lOpCode = '8D4018'
				Case 'lea ecx,dword[eax+4]'
					$lOpCode = '8D4804'
				Case 'lea edx,dword[eax+4]'
					$lOpCode = '8D5004'
				Case 'lea edx,dword[eax+8]'
					$lOpCode = '8D5008'
				Case 'mov ecx,dword[eax+4]'
					$lOpCode = '8B4804'
				Case 'mov ecx,dword[eax+8]'
					$lOpCode = '8B4808'
				Case 'mov eax,dword[eax+8]'
					$lOpCode = '8B4008'
				Case 'mov eax,dword[eax+4]'
					$lOpCode = '8B4004'
				Case 'push dword[eax+4]'
					$lOpCode = 'FF7004'
				Case 'push dword[eax+c]'
					$lOpCode = 'FF700C'
				Case 'mov esp,ebp'
					$lOpCode = '8BE5'
				Case 'mov esp,ebp'
					$lOpCode = '8BE5'
				Case 'pop ebp'
					$lOpCode = '5D'
				Case 'retn 10'
					$lOpCode = 'C21000'
				Case 'cmp eax,2'
					$lOpCode = '83F802'
				Case 'cmp eax,0'
					$lOpCode = '83F800'
				Case 'cmp eax,B'
					$lOpCode = '83F80B'
				Case 'cmp eax,200'
					$lOpCode = '3D00020000'
				Case 'shl eax,4'
					$lOpCode = 'C1E004'
				Case 'shl eax,8'
					$lOpCode = 'C1E008'
				Case 'shl eax,6'
					$lOpCode = 'C1E006'
				Case 'shl eax,7'
					$lOpCode = 'C1E007'
				Case 'shl eax,8'
					$lOpCode = 'C1E008'
				Case 'shl eax,9'
					$lOpCode = 'C1E009'
				Case 'mov edi,eax'
					$lOpCode = '8BF8'
				Case 'mov dx,word[ecx]'
					$lOpCode = '668B11'
				Case 'mov dx,word[edx]'
					$lOpCode = '668B12'
				Case 'mov word[eax],dx'
					$lOpCode = '668910'
				Case 'test dx,dx'
					$lOpCode = '6685D2'
				Case 'cmp word[edx],0'
					$lOpCode = '66833A00'
				Case 'cmp eax,ebx'
					$lOpCode = '3BC3'
				Case 'cmp eax,ecx'
					$lOpCode = '3BC1'
				Case 'mov eax,dword[esi+8]'
					$lOpCode = '8B4608'
				Case 'mov ecx,dword[eax]'
					$lOpCode = '8B08'
				Case 'mov ebx,edi'
					$lOpCode = '8BDF'
				Case 'mov ebx,eax'
					$lOpCode = '8BD8'
				Case 'mov eax,edi'
					$lOpCode = '8BC7'
				Case 'mov al,byte[ebx]'
					$lOpCode = '8A03'
				Case 'test al,al'
					$lOpCode = '84C0'
				Case 'mov eax,dword[ecx]'
					$lOpCode = '8B01'
				Case 'lea ecx,dword[eax+180]'
					$lOpCode = '8D8880010000'
				Case 'mov ebx,dword[ecx+14]'
					$lOpCode = '8B5914'
				Case 'mov eax,dword[ebx+c]'
					$lOpCode = '8B430C'
				Case 'mov ecx,eax'
					$lOpCode = '8BC8'
				Case 'cmp eax,-1'
					$lOpCode = '83F8FF'
				Case 'mov al,byte[ecx]'
					$lOpCode = '8A01'
				Case 'mov ebx,dword[edx]'
					$lOpCode = '8B1A'
				Case 'lea edi,dword[edx+ebx]'
					$lOpCode = '8D3C1A'
				Case 'mov ah,byte[edi]'
					$lOpCode = '8A27'
				Case 'cmp al,ah'
					$lOpCode = '3AC4'
				Case 'mov dword[edx],0'
					$lOpCode = 'C70200000000'
				Case 'mov dword[ebx],ecx'
					$lOpCode = '890B'
				Case 'cmp edx,esi'
					$lOpCode = '3BD6'
				Case 'cmp ecx,900000'
					$lOpCode = '81F900009000'
				Case 'mov edi,dword[edx+4]'
					$lOpCode = '8B7A04'
				Case 'cmp ebx,edi'
					$lOpCode = '3BDF'
				Case 'mov dword[edx],ebx'
					$lOpCode = '891A'
				Case 'lea edi,dword[edx+8]'
					$lOpCode = '8D7A08'
				Case 'mov dword[edi],ecx'
					$lOpCode = '890F'
				Case 'retn'
					$lOpCode = 'C3'
				Case 'mov dword[edx],-1'
					$lOpCode = 'C702FFFFFFFF'
				Case 'cmp eax,1'
					$lOpCode = '83F801'
				Case 'mov eax,dword[ebp+37c]'
					$lOpCode = '8B857C030000'
				Case 'mov eax,dword[ebp+338]'
					$lOpCode = '8B8538030000'
				Case 'mov ecx,dword[ebx+250]'
					$lOpCode = '8B8B50020000'
				Case 'mov ecx,dword[ebx+194]'
					$lOpCode = '8B8B94010000'
				Case 'mov ecx,dword[ebx+18]'
					$lOpCode = '8B5918'
				Case 'mov ecx,dword[ebx+40]'
					$lOpCode = '8B5940'
				Case 'mov ebx,dword[ecx+10]'
					$lOpCode = '8B5910'
				Case 'mov ebx,dword[ecx+18]'
					$lOpCode = '8B5918'
				Case 'mov ebx,dword[ecx+4c]'
					$lOpCode = '8B594C'
				Case 'mov ecx,dword[ebx]'
					$lOpCode = '8B0B'
				Case 'mov edx,esp'
					$lOpCode = '8BD4'
				Case 'mov ecx,dword[ebx+170]'
					$lOpCode = '8B8B70010000'
				Case 'cmp eax,dword[esi+9C]'
					$lOpCode = '3B869C000000'
				Case 'mov ebx,dword[ecx+20]'
					$lOpCode = '8B5920'
				Case 'mov ecx,dword[ecx]'
					$lOpCode = '8B09'
				Case 'mov eax,dword[ecx+40]'
					$lOpCode = '8B4140'
				Case 'mov ecx,dword[ecx+10]'
					$lOpCode = '8B4910'
				Case 'mov ecx,dword[ecx+18]'
					$lOpCode = '8B4918'
				Case 'mov ecx,dword[ecx+20]'
					$lOpCode = '8B4920'
				Case 'mov ecx,dword[ecx+4c]'
					$lOpCode = '8B494C'
				Case 'mov ecx,dword[ecx+170]'
					$lOpCode = '8B8970010000'
				Case 'mov ecx,dword[ecx+194]'
					$lOpCode = '8B8994010000'
				Case 'mov ecx,dword[ecx+250]'
					$lOpCode = '8B8950020000'
				Case 'mov al,byte[ecx+4f]'
					$lOpCode = '8A414F'
				Case 'mov al,byte[ecx+3f]'
					$lOpCode = '8A413F'
				Case 'cmp al,f'
					$lOpCode = '3C0F'
				Case 'lea esi,dword[esi+ebx*4]'
					$lOpCode = '8D349E'
				Case 'mov esi,dword[esi]'
					$lOpCode = '8B36'
				Case 'test esi,esi'
					$lOpCode = '85F6'
				Case 'clc'
					$lOpCode = 'F8'
				Case 'repe movsb'
					$lOpCode = 'F3A4'
				Case 'inc edx'
					$lOpCode = '42'
				Case Else
					MsgBox(0, 'ASM', 'Could not assemble: ' & $aASM)
					Exit
			EndSwitch
			$mASMSize += 0.5 * StringLen($lOpCode)
			$mASMString &= $lOpCode
	EndSelect
EndFunc   ;==>_

;~ Description: Internal use only.
Func CompleteASMCode()
	Local $lInExpression = False
	Local $lExpression
	Local $lTempASM = $mASMString
	Local $lCurrentOffset = Dec(Hex($mMemory)) + $mASMCodeOffset
	Local $lToken

	For $i = 1 To $mLabels[0][0]
		If StringLeft($mLabels[$i][0], 6) = 'Label_' Then
			$mLabels[$i][0] = StringTrimLeft($mLabels[$i][0], 6)
			$mLabels[$i][1] = $mMemory + $mLabels[$i][1]
		EndIf
	Next

	$mASMString = ''
	For $i = 1 To StringLen($lTempASM)
		$lToken = StringMid($lTempASM, $i, 1)
		Switch $lToken
			Case '(', '[', '{'
				$lInExpression = True
			Case ')'
				$mASMString &= Hex(GetLabelInfo($lExpression) - Int($lCurrentOffset) - 1, 2)
				$lCurrentOffset += 1
				$lInExpression = False
				$lExpression = ''
			Case ']'
				$mASMString &= SwapEndian(Hex(GetLabelInfo($lExpression), 8))
				$lCurrentOffset += 4
				$lInExpression = False
				$lExpression = ''
			Case '}'
				$mASMString &= SwapEndian(Hex(GetLabelInfo($lExpression) - Int($lCurrentOffset) - 4, 8))
				$lCurrentOffset += 4
				$lInExpression = False
				$lExpression = ''
			Case Else
				If $lInExpression Then
					$lExpression &= $lToken
				Else
					$mASMString &= $lToken
					$lCurrentOffset += 0.5
				EndIf
		EndSwitch
	Next
EndFunc   ;==>CompleteASMCode

;~ Description: Internal use only.
Func GetLabelInfo($aLabel)
	Local $lValue = GetValue($aLabel)
	If $lValue = -1 Then Exit MsgBox(0, 'Label', 'Label: ' & $aLabel & ' not provided')
	Return $lValue ;Dec(StringRight($lValue, 8))
EndFunc   ;==>GetLabelInfo

;~ Description: Internal use only.
Func ASMNumber($aNumber, $aSmall = False)
	If $aNumber >= 0 Then
		$aNumber = Dec($aNumber)
	EndIf
	If $aSmall And $aNumber <= 127 And $aNumber >= -128 Then
		Return SetExtended(1, Hex($aNumber, 2))
	Else
		Return SetExtended(0, SwapEndian(Hex($aNumber, 8)))
	EndIf
EndFunc   ;==>ASMNumber
#EndRegion Assembler
#EndRegion Other Functions