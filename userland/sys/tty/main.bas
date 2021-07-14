#include once "in_out.bi"
#include once "stdlib.bi"
#include once "stdlib.bas"
#include once "system.bas"
#include once "console.bas"
#include once "stdio.bas"

#include once "slab.bi"
#include once "slab.bas"

#include once "vfs.bas"
#include once "vfile.bas"

dim shared STDIN    as unsigned integer
dim shared STDOUT   as unsigned integer

#include once "keyboard.bi"
#include once "keyboard.bas"

declare Sub ConsoleThread()
declare sub XCONSOLEPUTCHAR(b as unsigned byte)

sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
	ConsoleWriteLine(@"TTY Starting")
    STDIO_INIT()
    
    SlabInit()


    STDIN = STDIO_CREATE()
    STDOUT = STDIO_CREATE()
    INIT_KBD()
    
    
    
	Thread_Create(@ConsoleThread)
    
    
	STDIO_SET_OUT(STDOUT)
	STDIO_SET_IN(STDIN)
    ConsoleWriteLine(@"TTY Ready")
    ExecAppAndWait(@"SYS:/SYS/SHELL.BIN",0)
    Process_Exit()
	do:loop
end sub

sub ConsoleThread()
	dim b as unsigned byte
	do
		b = STDIO_READ(STDOUT)
		if (b<>0) then 
            XCONSOLEPUTCHAR(b)
        else
            Thread_Sleep(100)
        end if
	loop
end sub


sub XCONSOLEPUTCHAR(b as unsigned byte)

	if (b=13) then
		exit sub
	elseif (b=10) then
        ConsoleNewLine()
	elseif (b=8) then 
        ConsoleBackSpace()
	elseif(b=9) then
        ConsolePutChar(32)
	else
        ConsolePutChar(b)
	end if
end sub


