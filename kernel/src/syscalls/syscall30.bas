function SysCall30Handler(stack as IRQ_Stack ptr) as IRQ_Stack ptr
    dim CurrentThread as Thread ptr = Scheduler.CurrentRuningThread
    asm cli
    select case stack->EAX
        case &h00 'set idle
            IDLE_THREAD = CurrentThread
            return Scheduler.Switch(stack, Scheduler.Schedule())
        case &h01 'load app from memory
            var ctx = vmm_get_current_context()
            var args = cptr(unsigned byte ptr,stack->ESI)
            if (args<>0) then
                if (strlen(args)=0) then args = 0
            end if
            
            var p=Process.Create(cptr( EXECUTABLE_HEADER ptr,stack->EBX),stack->ECX,args,CurrentThread->Owner)
            ctx->Activate()
            if (p<>0) then 
                    p->Parent = CurrentThread->Owner
                    for i as unsigned integer = 0 to 31
                        p->LocalStorage(i) = CurrentThread->Owner->LocalStorage(i)
                    next
                    
                    if (stack->EDX = 1) then
                        CurrentThread->STATE = WaitingForProcess
                        p->WaitingThread = CurrentThread
                        return Scheduler.Switch(stack, Scheduler.Schedule())
                    end if
                    stack->EAX = 1
            '        return Scheduler.Switch(stack, Scheduler.Schedule())
            else
                stack->EAX=0
            end if
            
         case &h02 'end current process
			Process.RequestTerminate(currentThread->Owner)
            Scheduler.CurrentRuningThread=0
            return Scheduler.Switch(stack, Scheduler.Schedule())   
            
         case &h03 'kill process
            if (SlabMeta.IsValidAddr(cptr(any ptr,stack->ebx))=1) then 
                var pc = cptr(Process ptr,stack->EBX)
                Process.Terminate(pc) 
                if (CurrentThread->Owner=pc) then  return Scheduler.Switch(stack, Scheduler.Schedule())
            end if
            
        case &h04 'create thread
            var th = Thread.Create(currentThread->Owner,stack->EBX)
            
            Scheduler.SetThreadReady(th)
            stack->EAX = cuint(th)
        
        case &h05' TO IMPLement : Exit thread
        
        
        
        case &h06 'yield
            return Scheduler.Switch(stack, Scheduler.Schedule())
            
        case &h07 'thread wait
			return currentThread->DoWait(stack)
        
        case &h08 ' thread wake up
            if (SlabMeta.IsValidAddr(cptr(any ptr,stack->ebx))=1) then
            
                var th = cptr(Thread ptr,stack->EBX)
                if (th->IsValid()) then
                    var st =cptr(IRQ_Stack ptr,  th->SavedESP)
                    
                    if (th->State=ThreadState.WaitingReply or th->State=ThreadState.Waiting) then
                         st->EAX = stack->ECX
                         st->EBX = stack->EDX
                        'shedule the thread immediately
                         Scheduler.SetThreadReadyNow(th)
                         return Scheduler.Switch(stack, Scheduler.Schedule())
                    end if
                end if
            end if
            
        case &h09 'Mutex create
            var _mutex = currentThread->Owner->CreateMutex()
            stack->EAX  = cuint(_mutex)
            
        case &h0a 'Mutex acquire
            if (SlabMeta.IsValidAddr(cptr(any ptr,stack->ebx))=1) then
                var _mutex = cptr(Mutex ptr, stack->EBX)
                if (not _mutex->Acquire(CurrentThread)) then
                    return  Scheduler.Switch(stack,Scheduler.Schedule()) 
                end if
            end if
            
        case &h0b 'Mutex release
            if (SlabMeta.IsValidAddr(cptr(any ptr,stack->ebx))=1) then
                var _mutex = cptr(Mutex ptr, stack->EBX)
                _mutex->Release(CurrentThread) 
            end if   
             
        case &h0c'create signal
                var si = cptr(Signal ptr,KAlloc(sizeof(Signal)))
                si->Constructor()
                stack->EAX = cuint(si)
                
        case &h0d'signal wait
            if (SlabMeta.IsValidAddr(cptr(any ptr,stack->ebx))=1) then
                var si = cptr(Signal ptr, stack->EBX)
                if (si->Wait(CurrentThread)=0) then
                    stack->EAX = 0
                    return  Scheduler.Switch(stack,Scheduler.Schedule()) 
                else
                    stack->EAX = 1
                end if
            end if
            
        case &h0e'signal set
            if (SlabMeta.IsValidAddr(cptr(any ptr,stack->ebx))=1) then
                var si = cptr(Signal ptr, stack->EBX)
                si->Set() 
            end if  
            
        case &h0F 'Wait N time slice
             Scheduler.SetThreadRealTime(CurrentThread,stack->EBX)
             return  Scheduler.Switch(stack,Scheduler.Schedule()) 
        
        case &h13 'Define IRQ handler
            stack->EAX = SET_IRQ_EVENT_HANDLER(stack->EBX,CurrentThread->Owner,CurrentThread,stack->ECX)
            if (stack->EAX<>0) then IRQ_ENABLE(stack->EBX)
            
        case &h14 'enable irq
            IRQ_ENABLE(stack->EBX)
            
        case &h15 'define IPC handler with ID
            var ep = IPCEndPoint.CreateID(stack->EBX,CurrentThread,stack->ECX,stack->EDX)
            if (ep<>0) then
                stack->EAX = ep->ID
            else
                stack->EAX = 0
            end if
        case &h16 'define ipc handler with name
            var ep = IPCEndPoint.CreateName(cptr(unsigned byte ptr,stack->ESI),CurrentThread,stack->ECX,stack->EDX)
            if (ep<>0) then
                stack->EAX = ep->ID
            else
                stack->EAX = 0
            end if
            
        case &h17 'define anonymous ipc handler (it will use '$$$$' as name, and generate an id)
            var ep = IPCEndPoint.CreateAnonymous(CurrentThread,stack->ECX,stack->EDX)
            if (ep<>0) then
                stack->EAX = ep->ID
            else
                stack->EAX = 0
            end if
            
        case &h18 'end of ipc handler
            stack->ESP = stack->EBP
            
            if (CurrentThread->ReplyTO->IsValid()) then
                if ((CurrentThread->ReplyTO->State=ThreadState.WaitingReply) and (CurrentThread->ReplyTO->ReplyFrom = CurrentThread)) then
                    var st =cptr(IRQ_Stack ptr, CurrentThread->ReplyTO->SavedESP)
                    st->EAX = *cptr(unsigned integer ptr,stack->ESP+20)
                    st->EBX = *cptr(unsigned integer ptr,stack->ESP+24)
                    st->ECX = *cptr(unsigned integer ptr,stack->ESP+28)
                    'st->EDX = *cptr(unsigned integer ptr,stack->ESP+32)
                    'st->ESI = *cptr(unsigned integer ptr,stack->ESP+36)
                    'st->EDI = *cptr(unsigned integer ptr,stack->ESP+40)
                    'st->EBP = *cptr(unsigned integer ptr,stack->ESP+44)
                    
                    'reply directly from interrupt
                    Scheduler.SetThreadReadyNow(CurrentThread->ReplyTO)
                end if
            end if
			stack->ESP+=48
            return currentThread->DoWait(stack)
        case &h19 'IPC Find
            stack->EAX = 0
            dim n as unsigned byte ptr = cptr(unsigned byte ptr,stack->ESI)
            'cannot specify an anonymous or id based ipc box
            if (strcmp(n,@"$$$$")<>0) then 
                var ep = IPCEndPoint.FindByName(n)
                if (ep<>0) then stack->EAX = ep->ID
            end if
        case &h1A 'IPC Send
            var endPoint = IPCEndPoint.FindBYId(stack->EBX)
            if (endPoint<>0) then
                
                dim body as IPCMessageBody ptr = cptr(IPCMessageBody ptr,stack->ECX)
                var ipcSendResult = IPCSendBody(stack->EBX,CurrentThread,body)
               
                if (ipcSendResult<>0) then
                    'caller must wait
                    if (endPoint->Synchronous = 1) then
                        stack->EAX = &hFF
                        CurrentThread->State=ThreadState.WaitingReply
                        CurrentThread->ReplyFrom=endPoint->Owner
                        return  Scheduler.Switch(stack,Scheduler.Schedule()) 
                    elseif (ipcSendResult = 2) then 'received is waked up
                        return  Scheduler.Switch(stack,Scheduler.Schedule()) 
                    end if
                end if
            end if
        
        case &h1B 'signal trhead
            if (SlabMeta.IsValidAddr(cptr(any ptr,stack->ebx))=1) then
                XappSignal2Parameters(cptr(Thread ptr,stack->EBX),stack->ECX,stack->esi, stack->EDI)
                return Scheduler.Switch(stack,Scheduler.Schedule()) 
            end if
            
       case &h1C 'get parent process
            stack->EAX = 0
            if (stack->EBX<>0) then
                if (SlabMeta.IsValidAddr(cptr(any ptr,stack->ebx))=1) then
                    var proc = cptr(Process ptr,stack->EBX)
                    stack->EAX =cuint( proc->Parent)
                end if
            else
                if (CurrentThread->Owner<>0) then
                    stack->EAX =cuint( CurrentThread->Owner->Parent)
                end if
            end if
       
        case &h20 'get string
            if (currentThread->ReplyTo->IsValid()) then
                var phys = CurrentThread->ReplyTo->VMM_Context->Resolve(cptr(any ptr,stack->ESI))
                var virt = vmm_kernel_automap(phys,PAGE_SIZE,VMM_FLAGS_KERNEL_DATA)
                
                strcpy(cptr(unsigned byte ptr,stack->EDI),cptr(unsigned byte ptr,virt))
                stack->EAX = 1
            else
                stack->EAX = 0
            end if
        case &h21 'set string
            if (currentThread->ReplyTo->IsValid()) then
                var phys = CurrentThread->ReplyTo->VMM_Context->Resolve(cptr(any ptr,stack->EDI))
                 var virt = vmm_kernel_automap(phys,PAGE_SIZE,VMM_FLAGS_KERNEL_DATA)
                strcpy(cptr(unsigned byte ptr,virt),cptr(unsigned byte ptr,stack->ESI))
            end if
            
        case &h22 'Map buffer from caller
            
            stack->EAX = 0
            if (currentThread->ReplyTo->IsValid()) then
                if (currentThread->ReplyTo->VMM_Context<>0) then
				
                    var startPage = stack->ESI and &hFFFFF000
                    var endPage = ((stack->ESI + stack->ECX -1) and &hFFFFF000)
					var nbPages = ((endPage-startPage) shr 12)+1
					var freePages = currentThread->VMM_Context->find_free_pages(nbPages,ProcessMapAddress,&hFFFFF000)
					if (freePages<>0) then
						var dst = freePages
						for i as unsigned integer=startPage to endPage step 4096
							var phys = CurrentThread->ReplyTo->VMM_Context->Resolve(cptr(any ptr,i))
							CurrentThread->VMM_Context->Map_Page(cptr(any ptr,dst),cptr(any ptr,phys),VMM_FLAGS_USER_DATA)
							dst+=4096
						next i
						stack->EAX = freePages or (stack->ESI and &hFFF)
					end if
                end if
            end if
        
        case &h23 'mapBuffer to caller
			if (currentThread->ReplyTo->IsValid()) then
                if (currentThread->ReplyTo->VMM_Context<>0) then
				
                    var startPage = stack->ESI and &hFFFFF000
                    var endPage = ((stack->ESI + stack->ECX -1) and &hFFFFF000)
					var nbPages = ((endPage-startPage) shr 12)+1
					var freePages = currentThread->ReplyTo->VMM_Context->find_free_pages(nbPages,ProcessMapAddress,&hFFFFF000)
					if (freePages<>0) then
						var dst = freePages
						for i as unsigned integer=startPage to endPage step 4096
							var phys = CurrentThread->VMM_Context->Resolve(cptr(any ptr,i))
							CurrentThread->ReplyTo->VMM_Context->Map_Page(cptr(any ptr,dst),cptr(any ptr,phys),VMM_FLAGS_USER_DATA)
							dst+=4096
						next i
						stack->EAX = freePages or (stack->ESI and &hFFF)
					end if
                end if
            end if	
            
		case &h24 'Unmap buffer
			var addr = stack->EBX
			var size = stack->ECX
			var startPage = stack->EBX and &hFFFFF000
			var endPage = (stack->EBX + stack->ECX -1) and &hFFFFF000
			for i as unsigned integer = startPage to endPage step 4096
				CurrentThread->VMM_Context->unmap_page(cptr(any ptr,i))
			next i
			
		
        
            
        case &h30 'page alloc
            stack->EAX = 0
            if (CurrentThread<>0) then
                if (CurrentThread->Owner<>0) then
                    IRQ_DISABLE(0)
                    stack->EAX =cuint( CurrentThread->Owner->AllocHeap(stack->EBX))
                    IRQ_ENABLE(0)
                end if
            end if
            
        case &h31 'Page Free
            if (CurrentThread<>0) then
                if (CurrentThread->Owner<>0) then
                    IRQ_DISABLE(0)
                    CurrentThread->Owner->RemoveAddressSpace(stack->EBX)
                    IRQ_ENABLE(0)
                end if
            end if
            
       
        case &hE1'enter critical
            EnterCritical()
		case &hE2 'exit critical
			ExitCritical()
            
         
        case &hE9 'get timer
             
             dim u0 as unsigned longint = TotalEllapsed
             dim i0 as unsigned integer
             dim i1 as unsigned integer
             asm
                 mov eax,[u0]
                 mov ebx,[u0+4]
                 mov [i0],eax
                 mov [i1],ebx
             end asm
             
             stack->EAX = i0
             stack->EBX = i1 
             
       
            
        case &hF0 'Random
            stack->EAX = NextRandomNumber(stack->EBX,stack->ECX)
        case &hF1 'GetTimeBCD
            stack->EAX = GetTimeBCD()
        case &hF2 'GetDateBCD
            stack->EAX = GetDateBCD()
		case &hF3 'GetScreenInfo
			stack->EAX = (XRes shl 16) or YRes
			stack->EBX = BPP
			stack->ECX = LFBSize
			stack->EDI = LFB
        case &hF4 'Get mem info
            stack->EAX = TotalPagesCount
            stack->EBX = TotalFreePages
            stack->ECX = SlabMeta.SlabCount
        case &hF5 'CPU IDLE COunt
            stack->EAX = IDLE_ThreadRunCount
            IDLE_ThreadRunCount = 0
        case &hF6 'GET RUN_MODE
            stack->EAX = KERNEL_RUNMODE
            
        case &hF7 'get Process Local storage
            stack->EAX = 0
            var tproc = cptr(Process ptr,stack->EBX)
            if (tproc=0) then tproc = CurrentThread->Owner
            if (stack->ECX>=0) and (stack->ECX<=31) then
                stack->EAX=tproc->LocalStorage(stack->ECX)
            end if
            
        case &hF8 'set Process Local storage
            stack->EAX = 0
            var tproc = cptr(Process ptr,stack->EBX)
            if (tproc=0) then tproc = CurrentThread->Owner
            if (stack->ECX>=0) and (stack->ECX<=31) then
                tproc->LocalStorage(stack->ECX) = stack->EDX
            end if
        
        case &hFF
            ConsoleWriteTextAndHex(@"TID ",CurrentThread->ID,true)
            ConsoleWriteTextAndHex(@"EAX ",stack->EAX,true)
            ConsoleWriteTextAndHex(@"EBX ",stack->EBX,true)
            ConsoleWriteTextAndHex(@"ECX ",stack->ECX,true)
            ConsoleWriteTextAndHex(@"EDX ",stack->EDX,true)
            ConsoleWriteTextAndHex(@"ESI ",stack->ESI,true)
            ConsoleWriteTextAndHex(@"EDI ",stack->EDI,true)
    end select
    return stack
end function


		