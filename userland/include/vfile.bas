

declare function VFSListDir(path as unsigned byte ptr,attrib as unsigned integer,skip as unsigned integer,count as unsigned integer,dst as VFSDirectoryEntry ptr) as unsigned integer


TYPE VFILE field = 1
    HANDLE  as unsigned integer
    IPC     as unsigned integer
    
    declare function OPEN(path as unsigned byte ptr,mode as unsigned integer) as unsigned integer
    declare sub CLOSE()
    declare function Read(dst as any ptr,count as unsigned integer) as unsigned integer
    declare function Write(src as any ptr,count as unsigned integer) as unsigned integer
    declare function OPEN_READ(path as unsigned byte ptr) as unsigned integer
    declare function OPEN_CREATE(path as unsigned byte ptr) as unsigned integer
    declare function OPEN_APEND(path as unsigned byte ptr) as unsigned integer
    declare function OPEN_RANDOM(path as unsigned byte ptr) as unsigned integer
    
    declare function FSIZE() as unsigned integer
    declare function EOF() as unsigned integer
    declare function FPOS() as unsigned integer
    declare sub ReadLine(dest as unsigned byte ptr)
end type

function VFILE.OPEN(path as unsigned byte ptr,mode as unsigned integer) as unsigned integer
    if (VFS_IPC_NUM = 0) then
        VFS_BIND()
    end if
    if VFS_IPC_NUM = 0 then 
        return 0
    end if
    HANDLE = IPC_SEND(VFS_IPC_NUM,3,mode,0,0,cuint(path),0,0,0,@IPC,0)
    
    if (HANDLE <> 0) and (IPC<>0) then
        return 1
    end if
    return 0
end function

sub VFILE.CLOSE()
    if (HANDLE<>0) and (IPC<>0) then
        IPC_SEND(IPC,&h2,HANDLE,0,0,0,0,0,0,0,0)
        HANDLE = 0
        IPC = 0
    end if
end sub

function VFILE.OPEN_READ(path as unsigned byte ptr) as unsigned integer
    return OPEN(path,1)
end function

function VFILE.OPEN_CREATE(path as unsigned byte ptr) as unsigned integer
    return OPEN(path,2)
end function

function VFILE.OPEN_APEND(path as unsigned byte ptr) as unsigned integer
    return OPEN(path,3)
end function

function VFILE.OPEN_RANDOM(path as unsigned byte ptr) as unsigned integer
    return OPEN(path,4)
end function

function VFILE.Read(dst as any ptr,count as unsigned integer) as unsigned integer
    if (HANDLE<>0) and (IPC<>0) then
        return IPC_SEND(IPC,&h3,HANDLE,count,0,0,cuint(dst),0,0,0,0)
    end if
    return 0
end function

function VFILE.Write(src as any ptr,count as unsigned integer) as unsigned integer
    if (HANDLE<>0) and (IPC<>0) then
        return IPC_SEND(IPC,&h4,HANDLE,count,0,cuint(src),0,0,0,0,0)
    end if
    return 0
end function

function VFILE.FSIZE() as unsigned integer
    if (HANDLE<>0) and (IPC<>0) then
        return IPC_SEND(IPC,&hA,HANDLE,0,0,0,0,0,0,0,0)
    end if
    return 0
end function

function VFILE.EOF() as unsigned integer
    if (HANDLE<>0) and (IPC<>0) then
        return IPC_SEND(IPC,&hB,HANDLE,0,0,0,0,0,0,0,0)
    end if
    return 1
end function

function VFILE.FPOS() as unsigned integer
    if (HANDLE<>0) and (IPC<>0) then
        return IPC_SEND(IPC,&hC,HANDLE,0,0,0,0,0,0,0,0)
    end if
    return 0
end function

sub VFile.ReadLine(dest as unsigned byte ptr)
    dim i as unsigned integer = 0
    dest[0]=0
    while not this.EOF()
        Read(dest+i,1)
        dest[i+1]=0
        if (dest[i]=10) or (dest[i]=13) or (dest[i]=0) then exit while
        i+=1
    wend
    dest[i]=0
    
end sub

function VFS_LOAD_FILE(path as unsigned byte ptr,_fsize as unsigned integer ptr) as unsigned byte ptr
    dim f as VFILE
    *_fsize = 0
    if (f.OPEN_READ(path)) then
        *_fsize = f.FSIZE()
        dim  buff as unsigned byte ptr = Malloc(*_fsize)
        if (buff<>0) then
            f.READ(buff,*_fsize)
        end if
        f.Close()
        return buff
    end if
    return 0
end function


function ExecAppAndWait(path as unsigned byte ptr,args as unsigned byte ptr) as unsigned integer
	dim fsize as unsigned integer = 0
	dim img as unsigned byte ptr = VFS_LOAD_FILE(path,@fsize)
	if (img<>0 and fsize<>0) then
		dim retval as unsigned integer= Process_Create(img,fsize,args,1)
        Free(img)
        return retval
	else
    '    ConsoleWrite(@"File not found : ")
     '   ConsoleWriteLine(path)
		return 0
	end if
end function

function ExecApp(path as unsigned byte ptr,args as unsigned byte ptr) as unsigned integer
	dim fsize as unsigned integer = 0
	dim img as unsigned byte ptr = VFS_LOAD_FILE(path,@fsize)
	if (img<>0 and fsize<>0) then
		dim retval as unsigned integer= Process_Create(img,fsize,args,0)
        Free(img)
        return retval
	else
    '    ConsoleWrite(@"File not found : ")
     '   ConsoleWriteLine(path)
		return 0
	end if
end function

function VFSListDir(path as unsigned byte ptr,attrib as unsigned integer,skip as unsigned integer,count as unsigned integer,dst as VFSDirectoryEntry ptr) as unsigned integer
    if (VFS_IPC_NUM = 0) then
        VFS_BIND()
    end if
    if VFS_IPC_NUM = 0 then return 0
    
    
    return IPC_SEND(VFS_IPC_NUM,4,attrib,count,skip,cuint(path),cuint(dst),0,0,0,0)
    
    return 0
end function
    