#include once "stdlib.bi"
#include once "multiboot.bi"
#include once "in_out.bi"
#include once "modules.bi"
#include once "realmode.bi"
#include once "gdt.bi"
#include once "pic.bi"
#include once "console.bi"
#include once "pmm.bi"
#include once "vmm.bi"
#include once "slab.bi"
#include once "kmm.bi"
#include once "interrupt.bi"
#include once "exception.bi"
#include once "vesa.bi"
#include once "address_space.bi"
#include once "process.bi"
#include once "thread.bi"
#include once "scheduler.bi"
#include once "rng.bi"
#include once "syscall.bi"
#include once "kernel.bi"
#include once "elf.bi"


#include once "ipc/signal.bi"
#include once "ipc/mutex.bi"
#include once "ipc/messaging.bi"
#include once "ipc/irq_event.bi"

declare sub PARSE_CMDLINE(cmdline as unsigned byte ptr)
declare sub PARSE_CMD_ARG(arg as unsigned byte ptr)
declare sub IDLE_LOOP()
SUB MAIN (mb_info as multiboot_info ptr)
    asm cli
    ConsoleInit()
    GDT_INIT()
    
    if (mb_info->cmdline<>0) then 
        PARSE_CMDLINE(mb_info->cmdline)
    end if
    InterruptsManager_Init()
    PMM_INIT(mb_info)
    VMM_INIT()
    VMM_INIT_LOCAL()
    MODULES_PRE_INIT(mb_info)
    
    SlabInit()
    RealMode_INIT()
    IRQ_DISABLE(0)
	
    
    
    IRQ_ATTACH_HANDLER(&h30,@Syscall30Handler)
    IRQ_ATTACH_HANDLER(&h31,@Syscall31Handler)
    
    Thread.InitManager()
    Process.InitEngine()
    
    IPC_INIT()
    
    MODULES_INIT(mb_info)
    Process.CreateKernel(cuint(@IDLE_LOOP))
    'find the best graphic mode
    dim mode as unsigned integer = 0
    
    if (KERNEL_RUNMODE=1) then
        VMM_EXIT()
        mode = VesaProbe()
        vmm_init_local()
        ConsoleNewLine()
        if (mode<>0) then
            'switch to selected graphic mode
            VMM_EXIT()
            VesaSetMode(mode)
            vmm_init_local()
        else
           KERNEL_RUNMODE = 0
           ConsoleWriteLine(@"Cannot set graphic mode")
        end if
    end if
    
    ConsoleDrawTitle()
    Thread.Ready()
    ConsoleWriteLine(@"KERNEL BOOTSTRAPING DONE")
    ConsoleNewLine()
    
    asm sti
    do
    loop
end sub

sub PARSE_CMDLINE(cmdline as unsigned byte ptr)
        KERNEL_RUNMODE = 1
        dim i   as unsigned integer = 0
        dim inquote as unsigned integer = 0
        
        while (cmdline[i] <> 0)
            if (cmdline[i] = 34) then
                inquote=iif(inquote=0,1,0)
            elseif ((cmdline[i]=32) and (inquote=0)) then
                cmdline[i]=0
                if (strlen(cmdline)>0) then
                    PARSE_CMD_ARG(cmdline)
                end if
                
                cmdline=cmdline+i+1
                i=0
            end if
            i+=1
        wend
        if (strlen(cmdline)>0) then
            PARSE_CMD_ARG(cmdline)
        end if
            
end sub

sub PARSE_CMD_ARG(arg as unsigned byte ptr)
    ConsoleWrite(@"Argument : "):ConsoleWriteLine(arg)
    if (strcmpignorecase(arg,@"nogui")=0) then
        KERNEL_RUNMODE = 0
        ConsoleWriteLine(@"    Runing in text mode")
    end if
end sub


sub IDLE_LOOP()
    asm 
        mov eax,0x0
        int 0x30
    end asm
    ConsoleWrite(@"IDLE THREAD Started")
    ConsolePrintOK()
    ConsoleNewLine()
    do
        'asm hlt
    loop
end sub

sub KERNEL_ERROR(message as unsigned byte ptr,code as unsigned integer) 
    asm cli
    VMM_EXIT()
    CONSOLE_MEM = cptr(any ptr,&hB8000)
    VesaResetScreen()
    
    ConsoleSetBackGround(4)
    ConsoleSetForeground(15)
    ConsoleClear()
    ConsoleWriteLine(@"KERNEL PANIC")
    ConsoleWriteLine(message)
    ConsoleWriteTextAndHex(@"Code : ",code,true)
    ConsoleNewLine()
    asm 
        cli
        .panic_halt:
            hlt
        jmp .panic_halt
    end asm
end sub

#include once "arch/x86/realmode.bas"
#include once "arch/x86/gdt.bas"
#include once "arch/x86/vmm.bas"
#include once "arch/x86/pic.bas"
#include once "console.bas"
#include once "modules.bas"
#include once "stdlib.bas"
#include once "pmm.bas"
#include once "slab.bas"
#include once "kmm.bas"
#include once "interrupt.bas"
#include once "exception.bas"
#include once "drivers/vesa.bas"
#include once "process.bas"
#include once "address_space.bas"
#include once "thread.bas"
#include once "scheduler.bas"
#include once "rng.bas"
#include once "syscall.bas"

#include once "ipc/signal.bas"
#include once "ipc/mutex.bas"
#include once "ipc/messaging.bas"
#include once "ipc/irq_event.bas"