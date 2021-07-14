
type MOUNT_POINT field = 1
    MAGIC               as unsigned integer
    IPC_END_POINT_NUM   as unsigned integer
    IS_FREE             as unsigned integer
	PREV_MOUNT_POINT    as MOUNT_POINT ptr
	NEXT_MOUNT_POINT    as MOUNT_POINT ptr
    Path(0 to 255)      as unsigned byte
end type
dim shared FIRST_MOUNT_POINT 	    as MOUNT_POINT ptr
dim shared LAST_MOUNT_POINT		    as MOUNT_POINT ptr
dim shared MountPoints(1 to 256)    as MOUNT_POINT

declare function AllocMountPoint()  as MOUNT_POINT ptr
declare function FindMountPoint(_path as unsigned byte ptr) as MOUNT_POINT ptr
declare function CreateMountPoint(_path as unsigned byte ptr,_ipc_end_point as unsigned integer) as MOUNT_POINT ptr
declare function RemoveMountPoint(handle as MOUNT_POINT ptr) as unsigned integer


function AllocMountPoint() as MOUNT_POINT ptr
	for i as unsigned integer = lbound(MountPoints) to ubound(MountPoints)
		if (MountPoints(i).IS_FREE = 1) then return @MountPoints(i)
	next i
	return 0
end function

function VFS_CMP(s1 as unsigned byte ptr,s2 as unsigned byte ptr) as unsigned integer
    dim i as unsigned integer = 0
    while s1[i]<>0 and s2[i]<>0
        var c1 = s1[i]
        var c2 = s2[i]
        if (c1>=97 and c1<=122) then c1-=32
        if (c2>=97 and c2<=122) then c2-=32
        
        if (c1<>c2) then return 0
        i+=1
    wend
    if s1[i]<>0  then
        if (s1[i]=asc("/")) then
            if (s1[i+1]=0) then return i+1
        end if
        return 0
    end if
    'if (s1[i]=0 and s2[i]<>0 and s2[i]<>asc("/")) then return 0
    'if (s2[i]=0 and s1[i]<>0 and s1[i]<>asc("/")) then return 0 
    return i
end function

function VFS_FIND_NODE(path as unsigned byte ptr) as MOUNT_POINT ptr
    var node = FIRST_MOUNT_POINT
    dim deepestNode as MOUNT_POINT ptr
    dim deepestNodeLen as unsigned integer = 0
    while node<>0
        var i = VFS_CMP(@node->PATH(0),path)
        if (i>deepestNodeLen) then
            deepestNodeLen = i
            deepestNode = node
        end if
        node=node->NEXT_MOUNT_POINT
    wend
    return deepestNode
end function

function FindMountPoint(_path as unsigned byte ptr) as MOUNT_POINT ptr
	var mt = FIRST_MOUNT_POINT
	while  mt<>0
		if ( mt->IS_FREE = 0) then
            if (strcmpignorecase(_path,@mt->Path(0))=0) then return mt
		end if
		mt=mt->NEXT_MOUNT_POINT
	wend
	return 0
end function


function CreateMountPoint(_path as unsigned byte ptr,_ipc_end_point as unsigned integer) as MOUNT_POINT ptr
	ConsoleWrite(@"VFS : Creating mount point [")
	ConsoleWrite(_path)
	ConsoleWrite(@"] ... ")
	
	var existing = FindMountPoint(_path)
	if (existing<>0) then 
		ConsoleWriteLine(@" already exists")
	else
		var mt = AllocMountPoint()
		if (mt<>0) then
			'parameters
			mt->IS_FREE		= 0
            dim tmpPath as unsigned byte ptr = @mt->Path(0)
			strcpy(tmpPath,_path)
            strToUpperFix(tmpPath)
            if (tmpPath[strlen(_path)-1]<>asc("/")) then
                tmpPath[strlen(_path)] = asc("/")
                tmpPath[strlen(_path)+1] = 0
                
                ConsoleWrite(@" Fixed path ")
                COnsoleWrite(tmpPath)
                ConsoleWrite(@" ")
            end if
            
			mt->IPC_END_POINT_NUM	    = _ipc_end_point
			'add to the list
			mt->NEXT_MOUNT_POINT    	= 0
			mt->PREV_MOUNT_POINT 		= LAST_MOUNT_POINT
			if (LAST_MOUNT_POINT<>0) then 
				LAST_MOUNT_POINT->NEXT_MOUNT_POINT = mt
			else
				FIRST_MOUNT_POINT = mt
			end if
			LAST_MOUNT_POINT = mt
			
			
			ConsoleWrite(@"Created")
			ConsolePrintOK()
			ConsoleNewLine()
			return mt
		else
			ConsoleWriteLine(@"Cannot allocate mount point")
		end if
	end if
	return 0
end function


function RemoveMountPoint(handle as MOUNT_POINT ptr) as unsigned integer
	ConsoleWrite(@"Removing mountPoint ... ")
	if (handle>= @MountPoints(lbound(MountPoints))) and (handle>= @MountPoints(ubound(MountPoints)))  then
		if (handle->PREV_MOUNT_POINT<>0) then
			handle->PREV_MOUNT_POINT->NEXT_MOUNT_POINT = handle->NEXT_MOUNT_POINT
		else
			FIRST_MOUNT_POINT = handle->NEXT_MOUNT_POINT
		end if
		if (handle->NEXT_MOUNT_POINT<>0) then
			handle->NEXT_MOUNT_POINT->PREV_MOUNT_POINT = handle->PREV_MOUNT_POINT
		else
			LAST_MOUNT_POINT = handle->PREV_MOUNT_POINT
		end if
		ConsoleWrite(@handle->Path(0))
		handle->Path(0)             = 0
		handle->IPC_END_POINT_NUM   = 0
		handle->IS_FREE             = 1
		ConsoleWrite(@" removed")
		ConsolePrintOK()
		ConsoleNewLine()
		return 1
	else
		ConsoleWriteLine(@"Invalid handle")
	end if
	return 0
end function

