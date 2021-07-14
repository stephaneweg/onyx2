
type BLOCK_DEVICE field = 1
    HANDLE  as unsigned integer
    IPC_NUM as unsigned integer
    declare function Open(n as unsigned byte ptr) as unsigned integer
    declare function Read(alba as unsigned integer,sectorcount as unsigned short,b as byte ptr) as unsigned integer
    declare function Write(alba as unsigned integer,sectorcount as unsigned short,b as byte ptr) as unsigned integer
end type

function BLOCK_DEVICE.Open(n as unsigned byte ptr) as unsigned integer
    HANDLE = DEVMAN_GET_DEVICE(1,n,@IPC_NUM)
    
    if (HANDLE<>0) then return 1
    
    for i as unsigned integer = 1 to 20
        THREAD_SLEEP(200)
        HANDLE = DEVMAN_GET_DEVICE(1,n,@IPC_NUM)
        if (HANDLE<>0) then return 1
    next
    
    return 0
end function

function BLOCK_DEVICE.Read(alba as unsigned integer,sectorcount as unsigned short,b as byte ptr) as unsigned integer
    return IPC_SEND(IPC_NUM,1,HANDLE,sectorcount,alba,0,cuint(b),0,0,0,0)
end function

function BLOCK_DEVICE.Write(alba as unsigned integer,sectorcount as unsigned short,b as byte ptr) as unsigned integer
    return IPC_SEND(IPC_NUM,2,HANDLE,sectorcount,alba,cuint(b),0,0,0,0,0)
end function