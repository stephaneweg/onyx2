#include once "in_out.bi"
#include once "system.bas"
#include once "console.bas"
#include once "devman.bas"
#include once "ne2000.bi"
#include once "ne2000.bas"



declare function Create_ETH_IPC_Handler() as unsigned integer
declare sub ETH_IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)


sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
	ConsoleWriteLine(@"NE2000 - Driver starting")
	ETH_IRQ_THREAD	 = 0
	
	ConsoleWriteLine(@"Probing for NE2000 card")
	dim iobase as unsigned integer
	dim ok as unsigned integer = 0
	for iobase = &h200 to &h390 step &h10
		ok=ne_setup(iobase,&h29,eth_page_start,4096)
		if (ok<>0) then exit for
	next
	if (ok=0) then
		ConsoleWriteLine(@"NE2000 - Device not found")
		Process_Exit()
        do:loop
	end if
	
	
    DEVMAN_BIND()
 
	if (Create_ETH_IPC_Handler() = 0) then
        Process_Exit()
        do:loop
    end if
	
	DEVMAN_REGISTER(2,@"NE2000",ETH_IPC,1)
	
	
	
	
	ConsoleWriteLine(@"NE2000 - Driver ready")
    Thread_Wait_For_Event()
end sub


function Create_ETH_IPC_Handler() as unsigned integer
    dim result as unsigned integer = 0
    ETH_IPC = IPC_Create_Handler_Anonymous(@ETH_IPC_Handler,1)
    if (ETH_IPC<>0) then 
		'ConsoleWrite(@"NE2000 - IPCBOX Number : ")
		'ConsoleWriteNumber(ETH_IPC,10)
		'ConsoleNewLine()
		return 1
	else
		ConsoleSetForeground(12)
		ConsoleWriteLine(@"Cannot create IPC Handler for NE2000")
		ConsoleSetForeground(7)
		return 0
    end if
end function

sub ETH_IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
	
	dim doReply as boolean = true
	dim _buffer as unsigned byte ptr
	dim cpt as integer
	select case _eax
		case 1 'transmit
			ConsoleWriteLine(@"NE2000 IPC : Transmit")
			if (_ecx>0) then
				_buffer = MapBufferFromCaller(cptr(any ptr,_ESI),_ECX)
				_eax	= ne_transmit(_buffer,_ecx)
				UnmapBuffer(_buffer,_ECX)
			else
				_eax = 0
			end if
			COnsoleWriteLIne(@"End of transmit")
		case 2 'Poll
			ConsoleWriteLine(@"NE2000 IPC : Poll")
			_buffer = MapBufferFromCaller(cptr(any ptr,_EDI),4096)
			_eax = ne_poll(_buffer)
			UnmapBuffer(_buffer,4096)
		case 3'get Mac Addr
			_eax = *cptr(unsigned integer ptr,@ne.hwaddr(0))
			_ebx = *cptr(unsigned integer ptr,@ne.hwaddr(4)) and &hFFFF
			
			
		case else
			ConsoleWriteLine(@"NE2000 - invalid command")
	end select
	
	if (doReply) then
		IPC_Handler_End_With_Reply()
	else
		IPC_Handler_End_No_Reply()
	end if
end sub




