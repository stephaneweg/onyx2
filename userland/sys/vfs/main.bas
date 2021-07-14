#include once "stdlib.bi"
#include once "stdlib.bas"
#include once "system.bas"
#include once "console.bas"

#include once "mountpoint.bas"
#include once "vfs.bi"

dim shared TMPName(0 to 2047) as unsigned byte
declare sub IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)

declare function MountPoint_ListDir(path as unsigned byte ptr,entrytype as unsigned integer,dst as VFSDirectoryEntry ptr,skip as unsigned integer,entryCount as unsigned integer) as unsigned integer
declare function MountPoint_OPEN(path as unsigned byte ptr,mode as unsigned integer,ep as unsigned integer ptr) as unsigned integer
Sub main(argc As Unsigned Integer, argv As Unsigned Integer)
    Thread_Enter_Critical()
    ConsoleWrite(@"VFS starting ...")
	FIRST_MOUNT_POINT 	= 0
	LAST_MOUNT_POINT	= 0
	for i as unsigned integer = lbound(MountPoints) to ubound(MountPoints)
		MountPoints(i).PATH(0)              = 0
		MountPoints(i).IPC_END_POINT_NUM    = 0
		MountPoints(i).IS_FREE              = 1
	next
    
    var h = IPC_Create_Handler_Name(@"VFS",@IPC_Handler,1)
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


sub IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
	
	dim doReply as boolean = true
	
	select case _eax
		case &h0 'is alive
			_eax = &hFF
		case &h1 'create
            var ipc_num     = _ebx
            GetStringFromCaller(@TMPName(0),_esi)
            var mt = CreateMountPoint(@TMPName(0),ipc_num)
            if (mt<>0) then
                _eax = cuint(mt)
            else
                _eax = 0
            end if
        case &h2 'exists
            GetStringFromCaller(@TMPName(0),_esi)
            var p = @TMPName(0)
            var l = strlen(p)
            if (p[l-1]<>asc("/")) then
                p[l] = asc("/")
                p[l+1]=0
            end if
            if (FindMountPoint(p)<>0) then
                _eax = 1
            else
                _eax = 0
            end if
            
        case &h3 'open 
            'result:
            '   - eax : handle
            '   - ebx : end point ipc number
            GetStringFromCaller(@TMPName(0),_esi)
            _eax = MountPoint_OPEN(@TMPName(0),_ebx,@_ebx)
        case &h4 'list dir
            _EAX = 0
            var attrib  = _EBX
            var cpt     = _ECX
            var dst     = MapBufferFromCaller(cptr(any ptr,_EDI),sizeof(VFSDirectoryEntry)*cpt)
            var skip    = _EDX
            GetStringFromCaller(@TMPName(0),_ESI)
            _EAX = MountPoint_ListDir(@TMPName(0),attrib,dst,skip,cpt )
            UnMapBuffer(dst,sizeof(VFSDirectoryEntry)*cpt)
		case else
            _eax = 0
	end select
		
	
	if (doReply) then
		IPC_Handler_End_With_Reply()
	else
		IPC_Handler_End_No_Reply()
	end if
end sub

function MountPoint_OPEN(path as unsigned byte ptr,mode as unsigned integer,ep as unsigned integer ptr) as unsigned integer
    var node = VFS_FIND_NODE(path)
    *ep = 0
    if (node<>0) then
        *ep = node->IPC_END_POINT_NUM
        return IPC_SEND(node->IPC_END_POINT_NUM,1,mode,0,0,cuint(path)+strlen(@node->PATH(0)),0,0,0,0,0)
    else
        ConsoleWrite(@"Could not find mount point for ")
        ConsoleWriteLine(path)
    end if
    return 0
end function


function MountPoint_ListDir(path as unsigned byte ptr,entrytype as unsigned integer,dst as VFSDirectoryEntry ptr,skip as unsigned integer,entryCount as unsigned integer) as unsigned integer
    var node = VFS_FIND_NODE(path)
    if (node<>0) then
        if (strlen(path)<strlen(@node->PATH(0))) then
            return IPC_SEND(node->IPC_END_POINT_NUM,&hF,entrytype,entryCount,skip,cuint(path)+strlen(path),cuint(dst),0,0,0,0)
        else
            return IPC_SEND(node->IPC_END_POINT_NUM,&hF,entrytype,entryCount,skip,cuint(path)+strlen(@node->PATH(0)),cuint(dst),0,0,0,0)
        end if
    else
        ConsoleWrite(@"Could not find mount point for ")
        ConsoleWriteLine(path)
    end if
    return 0
end function