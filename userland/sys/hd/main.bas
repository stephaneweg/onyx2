#include once "stdlib.bi"
#include once "stdlib.bas"
#include once "system.bas"
#include once "console.bas"

#include once "devman.bas"
#include once "hd.bas"


Sub main(argc As Unsigned Integer, argv As Unsigned Integer)
    ConsoleWriteLine(@"Hard disk starting ...")
    for i as unsigned integer = lbound(HD_RESSOURCES) to ubound(HD_RESSOURCES)
        HD_RESSOURCES(i).IS_FREE = 1
    next
    
    DEVMAN_BIND()
    if (Create_HD_IPC_Handler() = 0) then
        Process_Exit()
        do:loop
    end if
    HD_Detect()
    Thread_Wait_For_Event()
end sub

function Create_HD_IPC_Handler() as unsigned integer
    
    
    dim result as unsigned integer = 0
    HD_IPC = IPC_Create_Handler_Anonymous(@HD_IPC_Handler,1)
    if (HD_IPC<>0) then return 1
    
    ConsoleSetForeground(12)
    ConsoleWriteLine(@"Cannot create IPC Handler for Hard disk")
    ConsoleSetForeground(7)
    
    return result
end function



sub HD_IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
	
	dim doReply as boolean = true
    
    select case _eax
        case 1 'read
            _EAX = 0
            if (HD_RES_Validate(_EBX)) then
                var handle =@HD_RESSOURCES(_EBX)
                var buffX = MapBufferFromCaller(cptr(any ptr,_EDI),_ECX shl 9)
                
                _EAX = handle->READ(_EDX+handle->BEGIN,_ECX,buffx)
                UnmapBuffer(Buffx,_ECX shl 9)
            end if
            
        case 2 'write
            _EAX = 0
            if (HD_RES_Validate(_EBX)) then
                var handle =@HD_RESSOURCES(_EBX)
                var buffX = MapBufferFromCaller(cptr(any ptr,_ESI),_ECX shl 9)
                
                _EAX = handle->Write(_EDX+handle->BEGIN,_ECX,buffx)
                UnmapBuffer(Buffx,_ECX shl 9)
            end if
        case else
            _EAX = 0
    end select
            
	if (doReply) then
		IPC_Handler_End_With_Reply()
	else
		IPC_Handler_End_No_Reply()
	end if
end sub
