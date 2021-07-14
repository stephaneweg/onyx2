
#include once "stdlib.bi"
#include once "stdlib.bas"
#include once "system.bas"
#include once "console.bas"
#include once "slab.bi"
#include once "slab.bas"

#include once "stdio.bas"
#include once "vfs.bas"
#include once "vfile.bas"

#include once "gdi.bi"

#include once "gdi.bas"

#include once "tobject.bi"
#include once "font.bi"
#include once "fontmanager.bi"
#include once "gimage.bi"



#include once "tobject.bas"
#include once "font.bas"
#include once "fontmanager.bas"
#include once "gimage.bas"

#include once "xconsole.bi"
#include once "xconsole.bas"

dim shared mainWin as unsigned integer


sub SHELLThread()
    ConsoleWrite(@"Starting shell")
    ExecAppAndWait(@"SYS:/SYS/SHELL.BIN",0)
   Process_Exit()
end sub

sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
    STDIO_INIT()
    
    SlabINIT()
    FontManager.Init()
    
	MainWin = GDIWindowCreate(500,355,@"TEMINAL")
	GDISetVisible(MainWin,0)
	XConsoleCREATE(mainWin,0,0,500,350)
	GDISetVisible(MainWin,1)
    
	Thread_Create(@SHELLThread)
	Thread_Wait_For_Event()
end sub




