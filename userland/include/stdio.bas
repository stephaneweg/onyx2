
dim shared STDIO_IPC_NUM as unsigned integer
dim shared STDIO_ERR_NUM as unsigned integer

sub STDIO_BIND()
    STDIO_IPC_NUM = 0
    dim stdioName as unsigned byte ptr = @"STDIO"
    
    'wait until device manager created his mailbox
    STDIO_IPC_NUM = IPC_Find(stdioName)
    if STDIO_IPC_NUM=0 then
        for i as unsigned integer = 1 to 20
            Thread_Sleep(200)
            STDIO_IPC_NUM = IPC_Find(stdioName)
            if (STDIO_IPC_NUM<>0) then exit for
        next
    end if
    
    dim ready as unsigned integer = IPC_SEND(STDIO_IPC_NUM,0,0,0,0,0,0,0,0,0,0)
    if (ready<>&hFF) then
        for i as unsigned integer = 1 to 20
            Thread_Sleep(200)
            ready = IPC_SEND(STDIO_IPC_NUM,0,0,0,0,0,0,0,0,0,0)
            if (ready = &hFF) then exit for
        next 
    end if
end sub

sub STDIO_INIT()
    STDIO_ERR_NUM = 0
    STDIO_IPC_NUM = 0
end sub
        
function STDIO_CREATE() as unsigned integer
    if (STDIO_IPC_NUM=0) then
        STDIO_BIND()
        if (STDIO_IPC_NUM=0) then return 0
    end if
    var result = IPC_SEND(STDIO_IPC_NUM,1,0,0,0,0,0,0,0,0,0)
    return result
end function

sub STDIO_DELETE(n as unsigned integer)
    if (n<>0) then
        
        if (STDIO_IPC_NUM=0) then
            STDIO_BIND()
            if (STDIO_IPC_NUM=0) then return
        end if
        dim pip as unsigned integer = IPC_SEND(STDIO_IPC_NUM,2,n,0,0,0,0,0,0,0,0)
    end if
end sub

sub STDIO_WRITE_BYTE(n as unsigned integer,b as unsigned byte)
    dim buff as unsigned byte ptr = @b
    if (STDIO_IPC_NUM=0) then
        STDIO_BIND()
        if (STDIO_IPC_NUM=0) then return
    end if
    IPC_SEND(STDIO_IPC_NUM,3,n,1,0,cuint(buff),0,0,0,0,0)
end sub

sub STDIO_WRITE(n as unsigned integer,b as unsigned byte ptr)
    if (STDIO_IPC_NUM=0) then
        STDIO_BIND()
        if (STDIO_IPC_NUM=0) then return
    end if
    IPC_SEND(STDIO_IPC_NUM,3,n,strlen(b),0,cuint(b),0,0,0,0,0)
end sub

sub STDIO_WRITE_LINE(n as unsigned integer,b as unsigned byte ptr)
    STDIO_WRITE(n,b)
    STDIO_WRITE_BYTE(n,10)
end sub

function STDIO_READ(n as unsigned integer) as unsigned byte 
    if (STDIO_IPC_NUM=0) then
        STDIO_BIND()
        if (STDIO_IPC_NUM=0) then return 0
    end if
    dim b as unsigned byte = 0
    STDIO_ERR_NUM = IPC_SEND(STDIO_IPC_NUM,4,n,1,0,0,cuint(@b),0,0,0,0)
    return b
end function


sub STDIO_SET_IN(n as unsigned integer)
     if (STDIO_IPC_NUM=0) then
        STDIO_BIND()
        if (STDIO_IPC_NUM=0) then return
    end if
    IPC_SEND(STDIO_IPC_NUM,5,n,0,0,0,0,0,0,0,0)
end sub

sub STDIO_SET_OUT(n as unsigned integer)
     if (STDIO_IPC_NUM=0) then
        STDIO_BIND()
        if (STDIO_IPC_NUM=0) then return
    end if
    IPC_SEND(STDIO_IPC_NUM,6,n,0,0,0,0,0,0,0,0)
end sub