#include once "stdlib.bi"
#include once "stdlib.bas"
#include once "system.bas"
#include once "console.bas"

#include once "slab.bi"
#include once "slab.bas"

#include once "devman.bas"
#include once "block_device.bas"
#include once "vfs.bas"
#include once "fatfs.bi"
#include once "fatfs_file.bi"
#include once "fatfs.bas"
#include once "fatfs_file.bas"

declare sub FATFS_IPC_HANDLER(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
declare function Create_FATFS_IPC_Handler() as unsigned integer

dim shared TMPString(0 to 2047) as unsigned byte
dim shared FATFS_IPC as unsigned integer
Sub main(argc As Unsigned Integer, argv As Unsigned byte ptr ptr)
    if (argc<2) then
        ConsoleWriteLine(@"Usage FATFS <DISK> <MOUNTPOINT>")
        Process_Exit()
    end if
    SlabInit()
        
    var devname = argv[0]' @"HDA1"
    
    ConsoleWrite(@"Mounting "):COnsoleWrite(devname):ConsoleWrite(@" as FatFS ... ") 
    DEVMAN_BIND()
    if (DEVICE.OPEN(devname)=0) then
        ConsoleWrite(@"Cannot Open ")
        ConsoleWriteLine(devname)
        Process_Exit()
    end if
    
    'consoleWrite(@"HD IPC Number : 0x")
    'ConsoleWriteNumber(DEVICE.IPC_NUM,16)
    'ConsoleNewLIne()
    'consoleWrite(@"HD HANDLE : 0x")
    'ConsoleWriteNumber(DEVICE.HANDLE,16)
    'ConsoleNewLine()
    
    if (FAT_DETECT() = 0) then
        ConsoleWriteLine(@"FAT Detect failed")
        Process_Exit()
    end if
    
    ConsoleWrite(@"FAT SUCCEEDED DETECTED")
    ConsolePrintOK()
    ConsoleNewLIne()
	
    'define IPC handler
    if (Create_FATFS_IPC_Handler()=0) then
        Process_Exit()
    end if
    
    if (VFS_MOUNT(argv[1],FATFS_IPC)=0) then
    
        ConsoleSetForeground(12)
        ConsoleWrite(@"Cannot mount ")
        ConsoleWrite(argv[0])
        ConsoleWrite(@" to ")
        ConsoleWriteLine(argv[1])
        ConsoleSetForeground(7)
        Process_Exit()
    end if
        
    'Make node in VFS
    Thread_Wait_For_Event()
end sub

function Create_FATFS_IPC_Handler() as unsigned integer
    
    
    dim result as unsigned integer = 0
    
    FATFS_IPC = IPC_Create_Handler_Anonymous(@FATFS_IPC_HANDLER,1)
    if (FATFS_IPC<>0) then return 1
    
    ConsoleSetForeground(12)
    ConsoleWriteLine(@"Cannot create IPC Handler for FATFS")
    ConsoleSetForeground(7)
    
    return result
end function

sub FATFS_IPC_HANDLER(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
    
    dim doReply as boolean = true
    
    select case _eax
        case 1 'open
            GetStringFromCaller(@TMPString(0),_esi)
            _eax = FATFS_OPEN(@TMPString(0),_ebx)
         case 2 'close
            _eax = 0
            var handle = cptr(FATFS_FILE ptr,_ebx)
            if (handle<>0) then
                if (handle->MAGIC = FATFS_MAGIC) then
                    handle->Close()
                    Free(handle)
                    _eax = 0
                end if
            end if
         case 3 'read
            _eax = 0
            var handle = cptr(FATFS_FILE ptr,_ebx)
            if (handle<>0) then
                if (handle->MAGIC = FATFS_MAGIC) then
                    dim  buffx as unsigned byte ptr = MapBufferFromCaller(cptr(unsigned byte ptr,_edi),_ecx)
                    if (buffx<>0) then
                        _eax = handle->READ(_ecx,buffx)
                        UnmapBuffer(Buffx,_ecx)
                    end if
                end if
            end if
           
        case 4 'write
            _eax = 0
            var handle = cptr(FATFS_FILE ptr,_ebx)
            if (handle<>0) then
                if (handle->MAGIC = FATFS_MAGIC) then
                    dim  buffx as unsigned byte ptr = MapBufferFromCaller(cptr(unsigned byte ptr,_esi),_ecx)
                    if (buffx<>0) then
                        _eax = handle->WRITE(_ecx,buffx)
                        UnmapBuffer(Buffx,_ecx)
                    end if
                end if
            end if
        'case 5 'seek
        
        case &hA 'fsize
            _eax = 0
            var handle = cptr(FATFS_FILE ptr,_ebx)
            if (handle<>0) then
                if (handle->MAGIC = FATFS_MAGIC) then
                    _eax = handle->FSIZE
                end if
            end if
        case &hB 'END_OF_FILE
            _eax = 1
            var handle = cptr(FATFS_FILE ptr,_ebx)
            if (handle<>0) then
                if (handle->MAGIC = FATFS_MAGIC) then
                    if (handle->FPOS>=handle->FSIZE) then 
                        _eax = 1
                    else
                        _eax = handle->END_OF_FILE
                    end if
                end if
            end if
            
        case &hC 'FILE POS
            _eax = 0
            var handle = cptr(FATFS_FILE ptr,_ebx)
            if (handle<>0) then
                if (handle->MAGIC = FATFS_MAGIC) then
                    _eax = handle->FPOS
                end if
            end if
        case &hF 'list dir
            _EAX = 0
            var path = @TmpString(0)
            GetStringFromCaller(path,_ESI)
            var cpt = _ECX
            var dst = MapBufferFromCaller(cptr(any ptr,_EDI),sizeof(VFSDirectoryEntry)*cpt)
            var skip = _EDX
            var attrib = _EBX
            _EAX = FATFS_ListDir(path,attrib,dst,skip,cpt )
            UnMapBuffer(dst,sizeof(VFSDirectoryEntry)*cpt)
        case else
			 ConsoleWriteLine(@"FATFS WRONG COMMAND")
            _eax = 0
    end select
		
	
	if (doReply) then
		IPC_Handler_End_With_Reply()
	else
		IPC_Handler_End_No_Reply()
	end if
end sub

