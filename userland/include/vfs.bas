#include once "vfs.bi"

dim shared VFS_IPC_NUM as unsigned integer

sub VFS_BIND()
    'ConsoleWrite(@"Connecting to Device manager ... ")
    dim vfsName as unsigned byte ptr = @"VFS"
    
    'wait until device manager created his mailbox
    VFS_IPC_NUM = IPC_Find(vfsName)
    if VFS_IPC_NUM=0 then
        for i as unsigned integer = 1 to 20
            Thread_Sleep(200)
            VFS_IPC_NUM = IPC_Find(vfsName)
            if (VFS_IPC_NUM<>0) then exit for
        next
    end if
    
    
    
    if (VFS_IPC_NUM = 0) then 
        ConsoleSetForeground(10)
        ConsoleWriteLine(@"Cannot connect to VFS server")
        ConsoleSetForeground(7)
        return
    end if
    
    dim ready as unsigned integer = IPC_SEND(VFS_IPC_NUM,0,0,0,0,0,0,0,0,0,0)
    if (ready<>&hFF) then
        for i as unsigned integer = 1 to 20
            Thread_Sleep(200)
            ready = IPC_SEND(VFS_IPC_NUM,0,0,0,0,0,0,0,0,0,0)
            if (ready = &hFF) then exit for
        next 
    end if
    
    
    if (ready<>&hFF) then
        ConsoleSetForeground(10)
        ConsoleWriteLine(@"VFS Server was not ready")
        ConsoleSetForeground(7)
        return
    end if
    'COnsoleWriteLine(@"Ready")
end sub

function VFS_EXISTS(path as unsigned byte ptr) as unsigned integer
    if (VFS_IPC_NUM = 0) then
        VFS_BIND()
    end if
    if VFS_IPC_NUM = 0 then return 0
    return IPC_SEND(VFS_IPC_NUM,2,0,0,0,cuint(path),0,0,0,0,0)
end function

function VFS_MOUNT(path as unsigned byte ptr,devIPC as unsigned integer) as unsigned integer
    if (VFS_IPC_NUM = 0) then
        VFS_BIND()
    end if
    if VFS_IPC_NUM = 0 then return 0
    
    return  IPC_SEND(VFS_IPC_NUM,1,devIPC,0,0,cuint(path),0,0,0,0,0)
    
end function
    