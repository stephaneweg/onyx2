
#include once "in_out.bi"
#include once "stdlib.bi"
#include once "system.bas"
#include once "slab.bi"
#include once "console.bi"
#include once "tobject.bi"
#include once "tstring.bi"
#include once "vfs.bas"
#include once "vfile.bas"
#include once "gdi/gdi.bi"
#include once "drivers/mouse.bi"
#include once "drivers/keyboard.bi"

dim shared ProcToTerminate as unsigned integer
dim shared TerminatedProc as unsigned integer

dim shared LFB as unsigned integer
dim shared LFBSize as unsigned integer
dim shared XRes as unsigned integer
dim shared YRes as unsigned integer
dim shared Bpp as unsigned integer
dim shared BytesPerPixel as unsigned integer
dim shared TMPString as unsigned byte ptr
dim shared TMPString2 as unsigned byte ptr

declare sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
declare sub INT35Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer,_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer,_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)

declare sub XAppButtonClick(btn as TButton ptr)
declare sub XAppMouseClick(elem as GDIBase ptr,mx as integer,my as integer)
declare sub XAppKeyPress(elem as GDIBase ptr,k as unsigned byte)



dim shared WinColor as unsigned integer
dim shared EV_SIGNAL as unsigned integer

sub SetEvent()
    Event_Set(EV_SIGNAL)
end sub



#include once "stdlib.bas"
#include once "slab.bas"
#include once "console.bas"
#include once "tobject.bas"
#include once "tstring.bas"
#include once "gdi/gdi.bas"



#include once "syscall.bas"
#include once "drivers/mouse.bas"
#include once "drivers/keyboard.bas"
declare sub INIT_GUI()
declare sub GUI_THREAD_LOOP(p as any ptr)
sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
	SlabInit()
    EV_SIGNAL   = Event_Create()
    
    
    TMPString = MAlloc(256)
    TMPString2 = MAlloc(256)
	GetScreenInfo(@XRes,@Yres,@Bpp,@LFB,@LFBSize)
	BytesPerPixel = Bpp shr 3
	
    INIT_GUI()
    INIT_KBD()
    INIT_MOUSE()
    ProcToTerminate = 0
	TerminatedProc = 0
    
    Thread_Wait_For_Event()
	do:loop
end sub

sub INIT_GUI()
    WinColor = &h303d45'&h224488'
    WindowSkin = Skin.Create(@"SYS:/RES/WINGS.BMP",1,7,7,32,7)
	ButtonSkin = Skin.Create(@"SYS:/RES/BUTTON.BMP",3,12,12,12,12)
	WindowCloseBtn = GImage.LoadFromBitmap(@"SYS:/RES/CLOSEBGS.BMP")
    WindowSkin->ApplyColor(wincolor,0)
    WindowCloseBtn->FillRectangleAlphaHalf(0,0,WindowCloseBtn->_width-1,WindowCloseBtn->_height-1,wincolor)
    FontManager.Init()
    
	ScreenInit()
    
    'create a separate thread for the gui loop
    Thread_Create(@GUI_THREAD_LOOP)
    'the syscall handler is defined in the main thread
	IPC_Create_Handler_ID(&h35,@int35Handler,1)    
	ExecApp(@"SYS:/SYS/INIT.BIN",@"2")
end sub


sub GUI_THREAD_LOOP(p as any ptr)
    do
        Event_Wait(EV_SIGNAL)
        ScreenLoop()
        
        if (ProcToTerminate<>0 or TerminatedProc<>0) then
            
            if (ProcToTerminate<>0) then
                Process_Kill(ProcToTerminate)
            end if
            'remove the from the gui
            var g = RootScreen->FirstChild
            while g<>0
                var  n = g->NextChild
                if (g->Owner<>0) and ((g->Owner = ProcToTerminate) or (g->Owner=TerminatedProc)) then
                    RootScreen->RemoveChild(g)
                    DestroyObj(g)
                end if
                g = n
            wend
            TerminatedProc = 0
            ProcToTerminate = 0
            
            g = RootScreen->LastChild
            
        end if
    loop
end sub



sub XAppButtonClick(btn as TButton ptr)
    if (btn->OwnerThread<>0 and btn->AppCallback) then
        IPC_Signal_Thread(btn->OwnerThread,btn->AppCallback,cuint(btn),btn->AppCallBackParameter)
    end if
end sub

sub XAppMouseClick(elem as GDIBase ptr,mx as integer,my as integer)
    if (elem->OwnerThread<>0 and elem->_onUserClick<>0) then
        IPC_Signal_Thread(elem->OwnerThread,elem->_onUserClick,cuint(elem),(mx shl 16) or my)
    end if
end sub

sub XAppKeyPress(elem as GDIBase ptr,k as unsigned byte)
    if (elem->OwnerThread<>0 and elem->_onUserKeyDown<>0) then
        IPC_Signal_Thread(elem->OwnerThread,elem->_onUserKeyDown,cuint(elem),k)
    end if
end sub



