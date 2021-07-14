dim shared TotalThreadCount as unsigned integer
dim shared ThreadIDS as unsigned integer
dim shared CriticalCount as unsigned integer

sub EnterCritical()
    if (Scheduler.CurrentRuningThread<>0) then
        Scheduler.CurrentRuningThread->InCritical = 1 
    end if
end sub

sub ExitCritical()
    if (Scheduler.CurrentRuningThread<>0) then
        Scheduler.CurrentRuningThread->InCritical = 0 
    end if
end sub



sub Thread.InitManager()
    TotalEllapsed = 0
    CriticalCount = 0
    TotalThreadCount = 0
    ThreadIDS = 0
    IDLE_THREADRunCount = 0
    IDLE_Thread = 0
    Scheduler.Constructor()
end sub

sub Thread.Ready()
    IRQ_ATTACH_HANDLER(&h20,@Int20Handler)
    set_timer_freq(500)
    IRQ_ENABLE(0)    
end sub


function int20Handler(stack as irq_stack ptr) as irq_stack ptr
    asm cli
    TotalEllapsed+=2
    if (ProcessToTerminate) then
        Process.Terminate(ProcessToTerminate)
        ProcessToTerminate = 0
    end if
    
    
    return Scheduler.Switch(stack,Scheduler.Schedule())
end function

destructor Thread()
    Magic = 0
    ReplyTo = 0
	ID = 0
	InCritical =0
	Owner = 0
    VMM_Context = 0
	State = 0
    PrevThreadQueue = 0
	NextThreadQueue = 0
    Queue = 0
	NextThreadProc = 0
	SavedESP = 0
    
    KMM_FREEPAGE(cptr(any ptr,KernelStackBase))
	
	KernelStackBase = 0
	KernelStackLimit = 0
    
	TotalThreadCount-=1
end destructor

function Thread.IsValid() as unsigned integer
    if (@this = 0) then return  0
    if (this.Magic<>&hFFABCDEF) then return 0
    return 1
end function


function Thread.Create(proc as Process ptr,entryPoint as unsigned integer) as Thread ptr
    dim th as Thread ptr = cptr(Thread ptr,KAlloc(sizeof(Thread)))
    
    TotalThreadCount+=1
    ThreadIDS+=1    
    th->Magic = &hFFABCDEF
    th->ReplyTo = 0
	th->InCritical = 0
    th->ID = ThreadIDS
    th->Owner = proc
    th->VMM_Context = @proc->VMM_Context
    th->State = ThreadState.created
    th->NextThreadQueue = 0
    th->NextThreadProc = 0
    th->Queue = 0
    
    th->KernelStackBase =cuint(KMM_ALLOCPAGE())
    th->KernelStackLimit = th->KernelStackBase + PAGE_SIZE
    th->SavedESP = th->KernelStackLimit - sizeof(irq_stack)-4
    if (proc=KERNEL_PROCESS) then
        th->SavedESP+=12
    end if
    
   'configure the process's context
    var st = cptr(irq_stack ptr,th->SavedESP)
    st->EAX = 0
    st->EBX = 0
    st->ECX = 0
    st->EDX = 0
    st->ESI = 0
    st->EDI = 0
    st->EIP = entrypoint
    if (proc<>KERNEL_PROCESS) then
        st->cs = &h18 or &h03
        st->ds = &h20 or &h03
        st->es = &h20 or &h03
        st->fs = &h20 or &h03
        st->gs = &h20 or &h03
        st->ss = &h20 or &h03
        th->UserStack = proc->AllocStack(1)
        st->ESP = cuint(th->UserStack) + PAGE_SIZE' - 8
    else
        st->cs = &h8 
        st->ds = &h10 
        st->es = &h10
        st->fs = &h10
        st->gs = &h10
        th->UserStack = 0
    end if
    
    st->eflags = &h3202
    th->AddToList()
    return th
end function

sub Thread.AddToList()
    if (this.Owner<>0) then
        this.Owner->AddThread(@this)
    end if
end sub

function Thread.CheckForEvent() as unsigned integer
    if (IRQ_EVENT_CHECK(@this)<>0) then return 1
    var ep = FirstIPCEndPoint
    while ep<>0
        if (ep->Owner = @this) then
            if (ep->ProcessReceive()<>0) then return 1
        end if
        ep=ep->NextEndPoint
    wend
end function

function Thread.DoWait(stack as IRQ_Stack ptr) as irq_stack ptr
    this.State=ThreadState.waiting
    CheckForEvent()
    return Scheduler.Switch(stack,Scheduler.Schedule()) 
end function