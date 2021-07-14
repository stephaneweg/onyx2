#include once "stdlib.bi"
#include once "stdlib.bas"
#include once "system.bas"
#include once "console.bas"

enum DEVICE_TYPE
    BLOCK_DEVICE = 1
end enum

Type DEVICE_DESCRIPTOR field = 1
	NAME(0 to 255) as unsigned byte
	IPC_END_POINT_NUM   as unsigned integer
    HANDLE              as unsigned integer
    DEV_TYPE            as unsigned integer
    
	IS_FREE             as unsigned integer
	PREV_DEV            as DEVICE_DESCRIPTOR ptr
	NEXT_DEV            as DEVICE_DESCRIPTOR ptr
end type



declare sub IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
dim shared FIRST_DEV 	as DEVICE_DESCRIPTOR ptr
dim shared LAST_DEV		as DEVICE_DESCRIPTOR ptr
dim shared Devices(0 to 255) as DEVICE_DESCRIPTOR

dim shared TMPName(0 to 2047) as unsigned byte

declare function AllocDevice() as DEVICE_DESCRIPTOR ptr
declare function FindDevice(_name as unsigned byte ptr,devtype as unsigned integer) as DEVICE_DESCRIPTOR ptr
declare function CreateDevice(_name as unsigned byte ptr,_ipc_end_point as unsigned integer,handle as unsigned integer,devtype as unsigned integer) as DEVICE_DESCRIPTOR ptr
declare function RemoveDevice(handle as DEVICE_DESCRIPTOR ptr) as unsigned integer

Sub main(argc As Unsigned Integer, argv As Unsigned Integer)
    Thread_Enter_Critical()
    ConsoleWrite(@"Devices manager starting ...")
	FIRST_DEV 	= 0
	LAST_DEV	= 0
	for i as unsigned integer = 0 to 255
		Devices(i).Name(0) = 0
		Devices(i).IPC_END_POINT_NUM = 0
		Devices(i).IS_FREE = 1
	next
    var h = IPC_Create_Handler_Name(@"DEVMAN",@IPC_Handler,1)
    if (h=0) then
        ConsoleSetForeground(12)
        ConsoleWrite(@" Unable to register ipc service")
        ConsoleSetForeground(7)
    else
        ConsoleWrite(@" ready")
        ConsolePrintOK()
    end if
    ConsolenewLine()
    Thread_Exit_Critical()
    
    Thread_Wait_For_Event()
End Sub

function AllocDevice() as DEVICE_DESCRIPTOR ptr
	for i as unsigned integer = 0 to 255
		if (Devices(i).IS_FREE = 1) then return @devices(i)
	next i
	return 0
end function

function FindDevice(_name as unsigned byte ptr,devtype as unsigned integer) as DEVICE_DESCRIPTOR ptr
	var dev = FIRST_DEV
	while dev<>0
		if (dev->IS_FREE = 0) then
            if (dev->DEV_TYPE = devtype) then
                if (strcmpignorecase(_name,@dev->NAME(0))=0) then return dev
            end if
		end if
		dev=dev->NEXT_DEV
	wend
	return 0
end function

function CreateDevice(_name as unsigned byte ptr,_ipc_end_point as unsigned integer,handle as unsigned integer,devtype as unsigned integer) as DEVICE_DESCRIPTOR ptr
	ConsoleWrite(@"Creating device (type : ")
    ConsoleWriteNumber(devtype,10)
    ConsoleWrite(@") - [")
	ConsoleWrite(_name)
	ConsoleWrite(@"] ... ")
	
	var existing = FindDevice(_name,devtype)
	if (existing<>0) then 
		ConsoleWriteLine(@" already exists")
	else
		var newDev = AllocDevice()
		if (newDev<>0) then
			'parameters
			newDev->IS_FREE		= 0
			strcpy(@newDev->Name(0),_name)
            strToUpperFix(@newDev->Name(0))
			newDev->IPC_END_POINT_NUM	= _ipc_end_point
            newDev->Handle              = handle
            newDev->DEV_TYPE            = devtype
			
			'add to the list
			newDev->NEXT_DEV 			= 0
			newDev->PREV_DEV 			= LAST_DEV
			if (LAST_DEV<>0) then 
				LAST_DEV->NEXT_DEV = newDev
			else
				FIRST_DEV = newDev
			end if
			LAST_DEV = newDev
			
			
			ConsoleWrite(@"Created")
			ConsolePrintOK()
			ConsoleNewLine()
			return newDev
		else
			ConsoleWriteLine(@"Cannot allocate block device")
		end if
	end if
	return 0
end function

function RemoveDevice(handle as DEVICE_DESCRIPTOR ptr) as unsigned integer
	ConsoleWrite(@"Removing device ... ")
	if (handle>= @devices(lbound(devices))) and (handle>= @devices(ubound(devices))) then
		if (handle->PREV_DEV<>0) then
			handle->PREV_DEV->NEXT_DEV = handle->NEXT_DEV
		else
			FIRST_DEV = handle->NEXT_DEV
		end if
		if (handle->NEXT_DEV<>0) then
			handle->NEXT_DEV->PREV_DEV = handle->PREV_DEV
		else
			LAST_DEV = handle->PREV_DEV
		end if
		ConsoleWrite(@handle->NAME(0))
		handle->Name(0)             = 0
		handle->IPC_END_POINT_NUM   = 0
        handle->HANDLE              = 0
        handle->DEV_TYPE            = 0
		handle->IS_FREE             = 1
		ConsoleWrite(@" removed")
		ConsolePrintOK()
		ConsoleNewLine()
		return 1
	else
		ConsoleWriteLine(@"Invalid handle")
	end if
	return 0
end function

sub IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
	
	dim doReply as boolean = true
	
	select case _eax
		case &h0 'is alive
			_eax = &hFF
		case &h1 'create
            var devType     = _ebx
            var ipc_num     = _ecx
            var handle      = _edx
            GetStringFromCaller(@TMPName(0),_esi)
            var dev = CreateDevice(@TMPName(0),ipc_num,handle,devType)
            if (dev<>0) then
                _eax = cuint(dev)
            else
                _eax = 0
            end if
		case &h2 'find
            GetStringFromCaller(@TMPName(0),_esi)
            var dev = FindDevice(@TMPName(0),_ebx)
            if (dev<>0) then
                _eax = dev->HANDLE
                _ebx = dev->IPC_END_POINT_NUM
            else
                _eax = 0
            end if
	end select
		
	
	if (doReply) then
		IPC_Handler_End_With_Reply()
	else
		IPC_Handler_End_No_Reply()
	end if
end sub
