constructor ThreadQueue()
    this.FirstThread = 0
    this.LastThread = 0
end constructor


'enqueue at the begining of the queue
sub ThreadQueue.EnqueueHead(t as Thread ptr)
    t->NextThreadQueue = this.FirstThread
    t->PrevThreadQueue = 0
    t->Queue = @this
    if (this.FirstThread<>0) then this.FirstThread->PrevThreadQueue = t
    
    if (this.LastThread=0) then
        this.LastThread = t
    end if
    
    this.FirstThread = t
end sub

'enqueue at the end of the queue
sub ThreadQueue.EnqueueTail(t as Thread ptr)
    t->NextThreadQueue = 0
    t->PrevThreadQueue = this.LastThread
    t->Queue = @this
    
    if (this.LastThread<>0) then this.LastThread->NextThreadQueue = t
    
    if (this.FirstThread=0) then
        this.FirstThread = t
    end if
    
    this.LastThread = t
end sub

function ThreadQueue.Dequeue() as Thread ptr
    dim t as Thread ptr =  this.FirstThread
    
    if (t<>0) then
        this.FirstThread = t->NextThreadQueue
        if (this.FirstThread = 0) then this.LastThread = 0
        t->NextThreadQueue = 0
        t->PrevThreadQueue = 0
        t->Queue = 0
    end if
    return t
end function


function ThreadQueue.RTCDequeue() as Thread ptr
    dim t as Thread ptr =  this.FirstThread
    dim selected as Thread ptr = 0
    while (t<>0)
        if (t->RTCDelay<TotalEllapsed) then
            this.Remove(t)
            return t
            exit while
        end if
        t=t->NextThreadQueue
    wend
    return 0
end function

sub ThreadQueue.Remove(t as Thread ptr)
    if (t->Queue = @this) then
        if (t->PrevThreadQueue<>0) then t->PrevThreadQueue->NextThreadQueue = t->NextThreadQueue
        if (t->NextThreadQueue<>0) then t->NextThreadQueue->PrevThreadQueue = t->PrevThreadQueue
        if (this.FirstThread = t) then this.FirstThread = t->NextThreadQueue
        if (this.LastThread = t) then this.LastThread = t->PrevThreadQueue
        t->NextThreadQueue = 0
        t->PrevThreadQueue = 0
        t->Queue = 0
    end if
end sub

constructor ThreadScheduler()
    NormalQueue.Constructor()
    RTCQueue.Constructor()
    CurrentRuningThread = 0
	RemovedThread = 0
end constructor


sub ThreadScheduler.RemoveThread(t as Thread ptr)
    NormalQueue.Remove(t)
    RTCQueue.Remove(t)
	if (CurrentRuningThread=t) then
		RemovedThread = t
	end if
end sub


function ThreadScheduler.Switch(_stack as IRQ_Stack ptr,newThread as Thread ptr) as IRQ_Stack ptr
    dim nStack as IRQ_Stack ptr = _stack
    
    if (CurrentRuningThread<>0 and CurrentRuningThread<>RemovedThread) then
		CurrentRuningThread->SavedESP = cast(unsigned integer,_stack) 
	end if    
	RemovedThread           = 0
    if (CurrentRuningThread = newThread) then 
        CurrentRuningThread->State= ThreadState.Runing
        return _stack
    end if
	CurrentRuningThread     = newThread
    
    
    if (CurrentRuningThread=0) then
        KERNEL_ERROR(@"NO RUNABLE THREAD",0)
        DO:loop
    end if
    
	
    
    
	nstack =cptr(irq_stack ptr,CurrentRuningThread->SavedESP)
    if (CurrentRuningThread->Owner=KERNEL_PROCESS) then
        KTSS_SET(CurrentRuningThread->SavedESP + sizeof(irq_stack),&h8,&h10,&h3202)
    else
        KTSS_SET(CurrentRuningThread->SavedESP + sizeof(irq_stack),&h8,&h10,&h3202)
    end if
    CurrentRuningThread->VMM_Context->Activate()
	CurrentRuningThread->State = ThreadState.Runing
   
	return nstack
end function


sub ThreadScheduler.SetThreadRealTime(t as Thread ptr,delay as unsigned integer)
    if (t->State=ThreadState.Ready) then exit sub
    if (delay=0) then 
        SetThreadReady(t)
        exit sub
    end if
    t->State=ThreadState.Ready
    t->RTCDelay = TotalEllapsed+delay
    RTCQueue.EnqueueTail(t)
end sub

sub ThreadScheduler.SetThreadReadyNow(t as Thread ptr)
    if (t->State=ThreadState.Ready) then exit sub
    t->State=ThreadState.Ready
    NormalQueue.EnqueueHead(t)
end sub

sub ThreadScheduler.SetThreadReady(t as Thread ptr)
    if (t->State=ThreadState.Ready) then exit sub
    t->State=ThreadState.Ready
    NormalQueue.EnqueueTail(t)
end sub



function ThreadScheduler.Schedule() as Thread ptr
    'disable interrupt
    'asm cli
    dim i as unsigned integer
    dim j as unsigned integer
    dim newThread as Thread ptr  = 0
    
    if (CurrentRuningThread<>0) then
        if (CurrentRuningThread->InCritical = 1) and (CurrentRuningThread<> RemovedThread) then
            return CurrentRuningThread
        end if
    end if
	
    if (CurrentRuningThread <> RemovedThread) then
        if (CurrentRuningThread<>0)  and (CurrentRuningThread<>IDLE_Thread) then
            if (CurrentRuningThread->State = ThreadState.Runing) then
                SetThreadReady(CurrentRuningThread)
            end if
        end if
    end if
	
    newThread = RTCQueue.RTCDequeue()
        
    if (newThread=0) then 
        newThread=NormalQueue.Dequeue()
    end if
	
    if (newThread=0) then
        newThread = IDLE_Thread
    end if
    
    IF (newThread=IDLE_THREAD) then
        IDLE_THREADRunCount += 1
    end if
    
    return newThread
end function




