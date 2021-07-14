#include once "stdlib.bi"
#include once "stdlib.bas"
#include once "system.bas"
#include once "console.bas"
#include once "slab.bi"
#include once "slab.bas"

#include once "stdio.bas"
#include once "vfs.bas"
#include once "vfile.bas"

dim shared input_data(0 to 4096) as unsigned byte

'dim shared CurrentWorkingDirectory as unsigned byte ptr
dim shared entries(0 to 50) as VFSDirectoryEntry
declare function STD_INPUT() as unsigned byte ptr
declare sub DO_COMMANDX(cmd as unsigned byte ptr,_stdin as unsigned integer)
declare sub DO_COMMAND(cmd as unsigned byte ptr,_stdin as unsigned integer,_stdout as unsigned integer)
declare function GET_EXEC_PATH(cmd as unsigned byte ptr) as unsigned byte ptr
declare function GET_APP_PATH(cmd as unsigned byte ptr) as unsigned byte ptr
declare function RunInternalCommand(cmd as unsigned byte ptr,args as unsigned byte ptr) as unsigned integer
sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
    STDIO_INIT()
    SlabInit()
    ConsoleWrite(@"SHELL READY")
    'CurrentWorkingDirectory = MAlloc(1024)
    'GetCurrentWorkingDirectory(CurrentWorkingDirectory)
    Do
		STDIO_WRITE(0,@"root@onyx:# ")
        'ConsoleWrite(CurrentWorkingDirectory)
        'STDIO_WRITE(0,@"# ")
        
		dim cmd as unsigned byte ptr = 0
		while cmd=0
			cmd = STD_INPUT()
		wend
        if cmd>0 then
            if (strcmp(cmd,@"exit")=0) then 
                exit do
            elseif (strcmp(cmd,@"ping")=0) then
                STDIO_WRITE(0,@"pong"):STDIO_WRITE_BYTE(0,10)
            else
                DO_COMMANDX(cmd,0)
                STDIO_SET_IN(0)
                STDIO_SET_OUT(0)
            end if
        end if
	loop	
    Process_Exit()
end sub


function str_TRIMX(x as unsigned byte ptr) as unsigned byte ptr
	dim s as unsigned byte ptr = x
	while (s[0]=32) or (s[0]=9) 
		s+=1
	wend
	var i = strlen(s)-1
	while (i>0) and (s[i]=32)
		s[i]=0
		i-=1
	wend
	return s
end function

function STD_INPUT() as unsigned byte ptr
    dim i as unsigned integer = 0
    do
        var b = STDIO_READ(0)
        'if (STDIO_ERR_NUM<>0) then
        '    input_data(i)=0
        '    if (i>0) then
        '        return @input_data(0)
        '    else
        '        return 0
        '    end if
        'end if
        if (b=13) or (b=10) then
            if (i>0) then
                STDIO_WRITE_BYTE(0,10)
                input_data(i)=0
                if (i>0) then
                    return @input_data(0)
                else
                    return 0
                end if
            end if
        end if
        if (b=8) then
            if (i>0) then
                STDIO_WRITE_BYTE(0,8)
                i-=1
                input_data(i)=0
            end if
        end if
        if (b>=32) then ' and b<128) then
            STDIO_WRITE_BYTE(0,b)
            input_data(i)=b
            i+=1
        end if
    loop
    return 0
end function


sub DO_COMMANDX(cmd as unsigned byte ptr,_stdin as unsigned integer)
	cmd = str_TRIMX(cmd)
	dim i as unsigned integer = 0
	var inQuote = 0
	while cmd[i]<>0
		if (cmd[i]=34) then
			if (inQuote=0) then 
				inQuote=1
			else
				inQuote=0
			end if
		elseif (cmd[i]=asc("|")) and (inQuote=0) then
			cmd[i]=0
			var leftCMD  = str_TRIMX(cmd)
			var rightCMD = str_TRIMX(cmd+i+1)
			
			var p = STDIO_CREATE()
			DO_COMMAND(leftCMD,_stdin,p)
			DO_COMMANDX(rightCMD,p)
			exit sub
		end if
		i+=1
	wend
	
	DO_COMMAND(cmd,_stdin,0)
    
end sub

sub DO_COMMAND(cmd as unsigned byte ptr,_stdin as unsigned integer,_stdout as unsigned integer)
    if (cmd<>0) then
        dim i as unsigned integer
        dim cmdArgs as unsigned byte ptr = 0
        dim cmdName as unsigned byte ptr = cmd
        
        dim stdOutPath as unsigned byte ptr = 0
        dim stdInPath as unsigned byte ptr = 0
        
        var inQuote = 0
        
        
        while cmd[i]<>0
            if (cmd[i]=34) then
                if (inQuote=0) then 
                    inQuote=1
                else
                    inQuote=0
                end if
            elseif (cmd[i]=asc(">")) and (inQuote=0) then
                stdOutPath = cmd+i+1
                cmd[i]=0
            elseif (cmd[i]=asc("<")) and (inQuote=0) then 
                stdInPath = cmd+i+1
                cmd[i]=0
            end if
            i+=1
        wend
        i=0
        while cmd[i]<>0
            if (cmd[i]=32) then
                cmd[i]=0
                cmdArgs=cmd+i+1
                exit while
            end if
            i+=1
        wend
        
                
        var path = GET_EXEC_PATH(cmd)
        
        if (path<>0) then
            
            if (stdInPath<>0) then
                while stdInPath[0]=32:stdInPath+=1:wend
                i = strlen(stdInPath)-1
                while (i>0) and (stdInPath[i]=32)
                    stdInPath[i]=0
                    i-=1
                wend
                'stdInPath = GetPath(stdInPath)
            end if
            if (stdOutPath<>0) then
                while stdOutPath[0]=32:stdOutPath+=1:wend
                i = strlen(stdOutPath)-1
                while (i>0) and (stdOutPath[i]=32)
                    stdOutPath[i]=0
                    i-=1
                wend
                'stdOutPath = GetPath(stdOutPath)
            end if
            
            if (cmdArgs<>0) then
                while cmdArgs[0]=32:cmdArgs+=1:wend
                i = strlen(cmdArgs)-1
                while (i>0) and (cmdArgs[i]=32)
                    cmdArgs[i]=0
                    i-=1
                wend
            end if
            
			dim _astdin as unsigned integer = 0
			dim _astdout as unsigned integer = 0
            dim _stdinbuff as unsigned byte ptr = 0
            dim _stdinbuffsize as unsigned integer = 0
            
            dim _stdOutFile  as VFile
            _stdOutFile.HANDLE = 0
            
            'create the stdout for the child process
			if (stdOutPath<>0 and _stdout=0) then 
                _stdOutFile.OPEN_CREATE(stdOutPath)
                if (_stdOutFile.HANDLE=0) then
                    STDIO_WRITE(0,@"Could not open file : "):STDIO_WRITE(0,stdOutPath):STDIO_WRITE_BYTE(0,10)
                    PFree(stdOutPath)
                    if (stdInPath<>0) then PFree(stdInPath)
                    return
                end if
                _astdout = STDIO_CREATE()
            end if
            
            'create the stdin for the child process
			if (stdInPath<>0 and _stdin=0)  then 
                _stdinbuff = VFS_LOAD_FILE(stdInPath,@_stdinbuffsize)
                
                if (_stdinbuff<>0 and _stdinbuffsize>0) then
                    _astdin = STDIO_CREATE()
                    for i as integer = 0 to _stdinbuffsize-1
                        STDIO_WRITE_BYTE(_astdin,_stdinbuff[i])
                    next
                    Free(_stdinbuff)
                else
                    STDIO_WRITE(0,@" Cannot read input stream "):STDIO_WRITE(0,stdInPath):STDIO_WRITE_BYTE(0,10)
                    PFree(stdInPath)
                    if (stdOutPath<>0) then PFree(stdOutPath)
                    return
                end if
            end if
            
            STDIO_SET_IN(iif(_stdin<>0,_stdin,_astdin))
            STDIO_SET_OUT(iif(_stdout<>0,_stdout,_astdout))
            if (ExecAppAndWait(path,cmdArgs)=0) then
                path = GET_APP_PATH(cmd)
                if (ExecAppAndWait(path,cmdArgs)=0) then
                    if (RunInternalCommand(cmd,cmdArgs)=0) then
                        STDIO_SET_OUT(0)
                        STDIO_SET_IN(0)
                        STDIO_WRITE(0,@"Command not found :"):STDIO_WRITE(0,cmd):STDIO_WRITE_BYTE(0,10)
                    end if
                end if
            end if
            STDIO_SET_OUT(0)
            STDIO_SET_IN(0)
            
            'read the output and save it to file
			if (_astdout<>0 and _stdoutFile.HANDLE<>0) then
                STDIO_WRITE(0,@"Writing output to "):STDIO_WRITE(0,stdOutPath):STDIO_WRITE_BYTE(0,10)
                dim n as unsigned integer = 0
                do
                    var b = STDIO_READ(_astdout)
                    if (STDIO_ERR_NUM) = 0 then
                    'if (b=0) then exit do
                        _stdoutFile.Write(@b,1)
                        n+=1
                    else
                        exit do
                    end if
                loop
                STDIO_WRITE(0,@" OK "):STDIO_WRITE(0,intToStr(n,10)):STDIO_WRITE(0,@" bytes"):STDIO_WRITE_BYTE(0,10)
                _stdoutFile.CLOSE()
            end if
            'F_CLOSE(_astdin)
            'F_CLOSE(_astdout)
                
            if (stdInPath<>0) then PFree(stdInPath)
            if (stdOutPath<>0) then PFree(stdOutPath)    
        else
            STDIO_WRITE(0,@"Command not found :"):STDIO_WRITE(0,cmd):STDIO_WRITE_BYTE(0,10)
        end if
        
        
    end if
end sub



function RunInternalCommand(cmd as unsigned byte ptr,args as unsigned byte ptr) as unsigned integer
    
    return 0
end function

function GET_APP_PATH(cmd as unsigned byte ptr) as unsigned byte ptr
    dim path as unsigned byte ptr = 0
    'if (FILE_EXISTS(path)) then return path
    path = strcat( strcat(@"SYS:/APPS/",cmd),@".APP/MAIN.BIN")
    return path
end function

function GET_EXEC_PATH(cmd as unsigned byte ptr) as unsigned byte ptr
    dim path as unsigned byte ptr = 0
    'if (FILE_EXISTS(path)) then return path
    path = strcat( strcat(@"SYS:/BIN/",cmd),@".bin")
    return path
end function