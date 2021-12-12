dim shared DEVMAN_IPC_NUM as unsigned integer = 0

sub DEVMAN_BIND()
    'ConsoleWrite(@"Connecting to Device manager ... ")
    dim devmanName as unsigned byte ptr = @"DEVMAN"
    
    'wait until device manager created his mailbox
    DEVMAN_IPC_NUM = IPC_Find(devmanName)
    if DEVMAN_IPC_NUM=0 then
        for i as unsigned integer = 1 to 20
            Thread_Sleep(200)
            DEVMAN_IPC_NUM = IPC_Find(devmanName)
            if (DEVMAN_IPC_NUM<>0) then exit for
        next
    end if
    
    
    
    if (DEVMAN_IPC_NUM = 0) then 
        ConsoleSetForeground(10)
        ConsoleWriteLine(@"Cannot connect to device manager")
        ConsoleSetForeground(7)
        return
    end if
    
    'ConsoleWrite(@"MailBox ID : 0x"):ConsoleWriteNumber(DEVMAN_IPC_NUM,16):ConsoleNewLine()
    'ConsoleWrite(@"Waiting for device manager ... ")
    dim ready as unsigned integer = IPC_SEND(DEVMAN_IPC_NUM,0,0,0,0,0,0,0,0,0,0)
    if (ready<>&hFF) then
        for i as unsigned integer = 1 to 20
            Thread_Sleep(200)
            ready = IPC_SEND(DEVMAN_IPC_NUM,0,0,0,0,0,0,0,0,0,0)
            if (ready = &hFF) then exit for
        next 
    end if
    
    
    if (ready<>&hFF) then
        ConsoleSetForeground(10)
        ConsoleWriteLine(@"Device manager was not ready")
        ConsoleSetForeground(7)
        return
    end if
    'COnsoleWriteLine(@"Ready")
end sub


function DEVMAN_REGISTER(devType as unsigned integer,devName as unsigned byte ptr,devIPC as unsigned integer,devHandle as unsigned integer) as unsigned integer
    if (DEVMAN_IPC_NUM = 0) then
        DEVMAN_BIND()
    end if
    if DEVMAN_IPC_NUM = 0 then return 0
    
    return  IPC_SEND(DEVMAN_IPC_NUM,1,devType,devIPC,devHandle,cuint(devName),0,0,0,0,0)
    
end function

function DEVMAN_GET_DEVICE(devtype as unsigned integer,devname as unsigned byte ptr,devipc as unsigned integer ptr) as unsigned integer
    return IPC_SEND(DEVMAN_IPC_NUM,2,devType,0,0,cuint(devName),0,0,0,devipc,0)
end function
    