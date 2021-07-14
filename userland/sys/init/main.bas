#include once "in_out.bi"
#include once "stdlib.bi"
#include once "stdlib.bas"
#include once "system.bas"
#include once "console.bas"

#include once "slab.bi"
#include once "slab.bas"
#include once "vfs.bas"

#include once "vfile.bas"
Declare Sub INIT_KBD()
Declare Sub KBD_FLUSH()
Declare Sub KBD_HANDLER()
dim shared fline(0 to 1024) as unsigned byte
declare sub ProcessInitFile(path as unsigned byte ptr)
Sub main(argc As Unsigned Integer, argv As Unsigned byte ptr ptr)
    ConsoleWriteLine(@"Init process starting")
    SlabInit()
    
    ConsoleWriteLine(@"Waiting for SYS:/ to be mounted")
    while VFS_EXISTS(@"SYS:/")=0 
        Thread_Sleep(200)
    Wend
    
    ConsoleSetForeground(10)
    ConsoleWrite(@"SYS:/ Ready")
    ConsoleSetForeground(7)
    ConsoleNewLine()
    
    'dim testfile as VFILE
    'testFile.OPEN_CREATE(@"SYS:/TOTO.TXT")
    'var txt = @"ceci est un text 2 abc"
    'testFile.Write(txt,strlen(txt)+1)
    'testFile.Close()
    
    if (argc>0) then
        if (strcmp(argv[0],@"2")=0) then
            ProcessInitFile(@"SYS:/ETC/INIT2.CFG")
        end if
    else
        ProcessInitFile(iif(GetRunMode()=1, @"SYS:/ETC/INIT1.CFG",@"SYS:/ETC/INIT0.CFG"))
    end if
	
    'ConsoleWrite(@"Keyboard driver loading")
    'INIT_KBD()
    'IRQ_Create_Handler(&h21,@KBD_HANDLER)
    'ConsolePrintOK()
    
    Process_Exit()
End Sub

sub ProcessInitFile(path as unsigned byte ptr)
    dim initFile as VFILE
    if (initFile.OPEN_READ(path)<>0) then
        while  initFile.EOF() = 0
            
            initFile.ReadLine(@fline(0))
            
            if strlen(@fline(0))>0 then
                dim cmd as unsigned byte ptr = @fline(0)
                dim args as unsigned byte ptr  = 0
                dim n as unsigned integer = 0
                while cmd[n]<>0
                    if (cmd[n]=32) then
                        cmd[n]=0
                        args = cmd+n+1
                        exit while
                    end if
                    n+=1
                wend
                
                ConsoleWrite(@"Starting : ")
                ConsoleWriteLine(cmd)
                if (ExecApp(cmd,args)=0) then
					ConsoleSetForeground(12)
					ConsoleWrite(@"Failed to execute")
					ConsoleSetBackGround(7)
				end if
            end if
        wend
        initFile.Close()
    end if
end sub


Sub KBD_HANDLER()
    Dim akey As Unsigned Byte = 0
    inb(&h60,[akey])
    ConsoleWrite(@"Key pressed : ")
    ConsoleWriteNumber(akey,10)
    ConsoleNewLine()
    
    Thread_IRQ_Handler_End()
End Sub

Sub INIT_KBD()
    Dim akey As Unsigned Byte = 0
    Do
        inb(&h60,[akey])
    Loop While akey = 0
	
    KBD_FLUSH()
End Sub

Sub KBD_FLUSH()
	'KBD_BUFFERPOS=0
End Sub