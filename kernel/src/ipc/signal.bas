

constructor Signal()
    value           = 0
    PendingThread   = 0
    nextSignal      = Signals
    Signals         = @this
end constructor

destructor Signal()
    dim s as Signal ptr = Signals
    if (s=@this) then
        Signals = this.NextSignal
    else
        while s<>0
            if (s->NextSignal = @this) then
                s->NextSignal = this.NextSignal
                exit while
            end if
            s=s->NextSignal
        wend
    end if
    value           = 0
    PendingThread   = 0
    nextSignal      = 0
end destructor


function Signal.Wait(th as Thread ptr) as unsigned integer
    'somebody else is already waiting
    if (this.PendingThread<>0) then return 0
    
    'if event is signaled
    if (value = 1) then 
        'go ahead
        value = 0
        return 1
    else
        'block the thread until a signal is received
        th->State = WaitingSignal
        this.PendingThread = th
        th->NextThreadQueue = 0
        th->PrevThreadQueue = 0
    end if
    return 0
end function

sub Signal.Set()
    'if it's not already set
    if (Value = 0) then
        'is there any thread waiting.
        if (this.PendingThread<>0) then
            'in this case simple make them ready
            var t = this.PendingThread
            this.PendingThread = 0
            t->NextThreadQueue = 0
            t->PrevThreadQueue = 0
            cptr(irq_stack ptr, t->SavedESP)->EAX = 1
            Scheduler.SetThreadReadyNow(t)
        else
            'else, set the signal as signaled
            value = 1
        end if
        
    end if
end sub