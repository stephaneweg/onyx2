sub INIT_IRQ_EVENT_HANDLERS()
    
    for i as unsigned integer = &h20 to &h2F
        IRQ_EVENT_HANDLERS(i).OWNER_PROCESS = 0
        IRQ_EVENT_HANDLERS(i).OWNER_THREAD  = 0
        IRQ_EVENT_HANDLERS(i).COUNT         = 0
        IRQ_EVENT_HANDLERS(i).ENTRY         = 0
    next i
end sub

function SET_IRQ_EVENT_HANDLER(intno as unsigned integer,proc as any ptr,th as any ptr,entry as unsigned integer) as unsigned integer
    if (intno <&h0) or (intno>&h2f) then return 0 'can only be used for hardware interrupt
    if (IRQ_HANDLERS(intno)<>0)     then return 0 'cannot request irq for id already handled by the kernel
    
    dim handler as IRQ_EVENT_HANDLER ptr = @IRQ_EVENT_HANDLERS(intno)
    if (handler->OWNER_PROCESS <> 0)    then return 0
    if (handler->OWNER_THREAD <> 0)     then return 0
    if (handler->ENTRY <> 0)            then return 0
    
    handler->OWNER_PROCESS  = proc
    handler->OWNER_THREAD   = th
    handler->ENTRY          = entry
    handler->COUNT          = 0
    return 1
end function

'check if any irq events is sent to this thread
function IRQ_EVENT_CHECK(th as any ptr) as unsigned integer
    for i as unsigned integer = &h20 to &h2f
        var r  = IRQ_EVENT_CHECK_ETC(i,th)
        if (r<>0) then return r
    next
    return 0
end function

'check if a irq event was sent to this thread
'if the thread was waiting, it will be made ready
function IRQ_EVENT_CHECK_ETC(intno as unsigned integer,th as any ptr) as unsigned integer
    if (intno <&h20) or (intno>&h2f) then return 0
    dim handler as IRQ_EVENT_HANDLER ptr = @IRQ_EVENT_HANDLERS(intno)
    if (handler->OWNER_THREAD <> th)     then return 0
    if (handler->COUNT>0) then
        
        dim ath as Thread ptr = handler->OWNER_THREAD 
        
        if (ath->State = ThreadState.Waiting) then
            dim st as IRQ_Stack ptr = cptr(IRQ_Stack ptr,ath->SavedESP)
            st->EIP = handler->ENTRY
            Scheduler.SetThreadReadyNow(ath)
            handler->COUNT-=1
            return 1
        end if
    
    end if
    return 0
end function
    

'signal an irq
'if the irq is attached to a thread , it will wakeup the thread if its waiting, or it will increment the counter
function IRQ_EVENT_SIGNAL(intno as unsigned integer) as unsigned integer
    if (intno <&h20) or (intno>&h2f) then return 0
    dim handler as IRQ_EVENT_HANDLER ptr = @IRQ_EVENT_HANDLERS(intno)
    if (handler->OWNER_PROCESS = 0)    then return 0
    if (handler->OWNER_THREAD = 0)     then return 0
    if (handler->ENTRY = 0)            then return 0
    dim th as Thread ptr = handler->OWNER_THREAD 
    
    if (th->State = ThreadState.Waiting) then
        dim st as IRQ_Stack ptr = cptr(IRQ_Stack ptr,th->SavedESP)
        st->EIP = handler->ENTRY
        Scheduler.SetThreadReadyNow(th)
        return 1
    else
        handler->COUNT +=1
    end if
    return 0
end function

'when a thread is terminated
'remove any handler
sub IRQ_EVENT_THREAD_TERMINATED(t as unsigned integer)
    for i as unsigned integer = &h0 to &h2f
        dim handler as IRQ_EVENT_HANDLER ptr = @IRQ_EVENT_HANDLERS(i)
        if (handler->OWNER_THREAD = t) then
            
            handler->OWNER_PROCESS  = 0
            handler->OWNER_THREAD   = 0
            handler->ENTRY          = 0
            handler->COUNT          = 0
        end if
    next
end sub