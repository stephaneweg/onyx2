#include once "stdlib.bi"
#include once "stdlib.bas"

#include once "system.bas"
#include once "console.bas"
#include once "slab.bi"
#include once "slab.bas"

#define STDIN_IDX   1
#define STDOUT_IDX  2
#define STDCWD_IDX  3

TYPE PIPE_TYPE field=1
    MAGIC           as unsigned integer
    FPOS            as unsigned integer
    FSIZE           as unsigned integer
    END_OF_FILE     as unsigned integer
    
    NEXT_PIPE       as PIPE_TYPE PTR
    PREV_PIPE       as PIPE_TYPE PTR
    
    BUFFER          as unsigned byte ptr
    BUFFER_SIZE     as unsigned integer
    BUFFER_PAGES    as unsigned integer
    ID              as unsigned integer

    declare constructor()
    declare destructor()
    
    declare function READ(count as unsigned integer,dest as unsigned byte ptr) as unsigned integer
    declare function WRITE(count as unsigned integer,src as unsigned byte ptr) as unsigned integer
    declare sub CreateBuffer(newsize as unsigned integer)
end type
dim shared FIRST_PIPE as PIPE_TYPE ptr
dim shared LAST_PIPE  as PIPE_TYPE ptr
dim shared PIPE_IDS   as unsigned integer
#define PIPE_NODE_MAGIC &h11111111
declare sub PIPES_INIT()
declare function PIPE_CREATE() as PIPE_TYPE ptr

declare sub IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)


sub Main(argc as unsigned integer,argv as unsigned byte ptr ptr)
    ConsoleWrite(@"STDIO starting ...")
    SlabInit()
    var h = IPC_Create_Handler_Name(@"STDIO",@IPC_Handler,1)
    
    if (h=0) then
        ConsoleSetForeground(12)
        ConsoleWrite(@" Unable to register ipc service")
        ConsoleSetForeground(7)
    else
        ConsoleWrite(@" ready")
        ConsolePrintOK()
    end if
    PIPES_INIT()
    ConsolenewLine()
    Thread_Wait_for_event()
end sub

sub PIPES_INIT()
    FIRST_PIPE    = 0
    LAST_PIPE     = 0
    PIPE_IDS      = 1
end sub

constructor PIPE_TYPE()
    PIPE_IDS+=1
    MAGIC           = PIPE_NODE_MAGIC
    FPOS            = 0
    FSIZE           = 0
    END_OF_FILE     = 0
    ID              = PIPE_IDS
    
    BUFFER_SIZE     = 4096 
    BUFFER_PAGES    = 1
    BUFFER          = PAlloc(1)
    
    NEXT_PIPE    = 0
    PREV_PIPE    = LAST_PIPE
    if (LAST_PIPE<>0) then 
        LAST_PIPE->NEXT_PIPE =@this
    else
        FIRST_PIPE = @this
    end if
    LAST_PIPE = @this
end constructor


destructor PIPE_TYPE()
    if (PREV_PIPE<>0) then 
        PREV_PIPE->NEXT_PIPE = NEXT_PIPE
    else
        FIRST_PIPE = NEXT_PIPE
    end if
    
    if (NEXT_PIPE<>0) then
        NEXT_PIPE->PREV_PIPE = PREV_PIPE
    else
        LAST_PIPE = PREV_PIPE
    end if
    
    if (BUFFER<>0) then
        PFree(BUFFER)
        BUFFER = 0
        BUFFER_SIZE = 0
        BUFFER_PAGES = 0
    end if
end destructor


sub PIPE_TYPE.CreateBuffer(newsize as unsigned integer)
    if (newsize>BUFFER_SIZE) then
        var bsize     = newsize
        var bpages    = bsize shr 12
        if (bpages shl 12) < bsize then 
            bpages+=1
            bsize=bpages SHL 12
        end if
        
        dim newbuff as unsigned byte ptr = PAlloc(bpages)
        if (BUFFER<>0) then
            if (newbuff<>0) then
                memcpy(newbuff,BUFFER,BUFFER_SIZE)
            end if
            PFree(BUFFER)
            BUFFER = 0
            BUFFER_SIZE = 0
            BUFFER_PAGES = 0
        end if
        BUFFER          = newbuff
        BUFFER_SIZE     = bsize
        BUFFER_PAGES    = bpages
    end if
end sub


function PIPE_TYPE.WRITE(count as unsigned integer,src as unsigned byte ptr) as unsigned integer
    dim newSize as unsigned integer = FSIZE + count
    CreateBuffer(newSize)
    memcpy(BUFFER+FSIZE,src,count)
    FSIZE+=count
    END_OF_FILE = iif(FSIZE>0,0,1)
    return count
end function

function PIPE_TYPE.READ(count as unsigned integer,dst as unsigned byte ptr) as unsigned integer
    dim cpt as unsigned integer = count
    if (cpt>FSIZE) then cpt=fsize
    memcpy(dst,BUFFER,cpt)
    
    if (fsize-cpt>0) then
        memcpy(BUFFER,BUFFER+cpt,FSIZE-CPT)
    end if
    FSIZE-=cpt
    END_OF_FILE = iif(FSIZE>0,0,1)
    return cpt
end function

function PIPE_CREATE() as PIPE_TYPE ptr
    dim pip as PIPE_TYPE ptr = MAlloc(sizeof(PIPE_TYPE))
    pip->constructor()
    return pip
end function

function PIPE_CLOSE(pip as PIPE_TYPE ptr) as unsigned integer
    if (pip = 0) then return 0
    if (pip->MAGIC<>PIPE_NODE_MAGIC) then return 0
    
    pip->destructor()
    Free(pip)
    
    return 1
end function

sub IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
	
	dim doReply as boolean = true
    
    select case _eax
        case 0'ready
            _eax = &hFF
        case 1'create pipe
            _eax = cuint(PIPE_CREATE())
        case 2'delete pipe
            var handle = _ebx
            var pip = cptr(PIPE_TYPE ptr,_ebx)
            _eax = PIPE_CLOSE(pip)
            
        case 3'std write
            _eax = 0
            var Handle = _ebx
            if (Handle=0) then Handle = GetProcessLocalStorage(_senderProc,STDOUT_IDX)
            if (Handle=0) then Handle = GetProcessLocalStorage(Process_Get_Parent(_senderProc),STDOUT_IDX)
            var pip = cptr(PIPE_TYPE ptr,Handle)
            if (pip<>0) then
                if (pip->MAGIC=PIPE_NODE_MAGIC) then
                    dim  buffx as unsigned byte ptr = MapBufferFromCaller(cptr(unsigned byte ptr,_esi),_ecx)
                    if (buffx<>0) then
                        _eax = pip->Write(_ecx,buffx)
                        UnmapBuffer(Buffx,_ecx)
                    end if
                end if
            end if
            
        case 4'std read
            _eax = 0
            var Handle = _ebx
            if (Handle=0) then Handle = GetProcessLocalStorage(_senderProc,STDIN_IDX)
            if (Handle=0) then Handle = GetProcessLocalStorage(Process_Get_Parent(_senderProc),STDIN_IDX)
            
            var pip = cptr(PIPE_TYPE ptr,Handle)
            if (pip<>0) then
                if (pip->MAGIC=PIPE_NODE_MAGIC) then
                    dim  buffx as unsigned byte ptr = MapBufferFromCaller(cptr(unsigned byte ptr,_edi),_ecx)
                    if (buffx<>0) then
                        pip->READ(_ecx,buffx)
                        UnmapBuffer(Buffx,_ecx)
                        if (pip->END_OF_FILE) then
                            _eax=&hFF
                        end if
                    end if
                end if
            end if
        case 5'set in
            var Handle = _ebx
            if (Handle=0) then Handle = GetProcessLocalStorage(Process_Get_Parent(_senderProc),STDIN_IDX)
            SetProcessLocalStorage(_senderProc,STDIN_IDX,Handle)
            
        case 6'set out
            var Handle = _ebx
            if (Handle=0) then Handle = GetProcessLocalStorage(Process_Get_Parent(_senderProc),STDOUT_IDX)
            SetProcessLocalStorage(_senderProc,STDOUT_IDX,Handle)
            
        case else
            _eax = 0
    end select

		
	
	if (doReply) then
		IPC_Handler_End_With_Reply()
	else
		IPC_Handler_End_No_Reply()
	end if
end sub