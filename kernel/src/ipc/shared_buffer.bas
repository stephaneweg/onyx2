constructor shared_buffer(proc as process ptr,pcount as unsigned integer)
	ConsoleWrite(@"Create shared buffer")
	Magic		= SHARED_BUFFER_MAGIC
	'allocate the physical pages
	PagesCount	= pcount
	PagesPhys	= KAlloc(sizeof(unsigned integer)*pcount)
	if (PagesCount>0) then
		for i as integer = 0 to PagesCount-1
			PagesPhys[i] = cuint(PMM_ALLOCPAGE())
		next
	end if
	
	'add the buffer to the linked list
	
	PrevBuffer	= LAST_SHARED_BUFFER
	NextBuffer	= 0
	
	if (LAST_SHARED_BUFFER = 0) then
		FIRST_SHARED_BUFFER = @this
	else
		LAST_SHARED_BUFFER->NextBuffer = @this
	end if
	LAST_SHARED_BUFFER = @this
	
	'other variables
	FirstLink	= 0
	LastLink	= 0
	Owner		= proc
	ConsoleWriteLine(@".... created")
end constructor

destructor shared_buffer()
	'remove the buffer from the linked list
	if (PrevBuffer<>0) then PrevBuffer->NextBuffer = NextBuffer
	if (NextBuffer<>0) then NextBuffer->PrevBuffer = PrevBuffer
	if FIRST_SHARED_BUFFER	= @this then FIRST_SHARED_BUFFER = NextBuffer
	if LAST_SHARED_BUFFER	= @THIS then LAST_SHARED_BUFFER  = PrevBuffer

	'destroy all links
	dim link as Shared_Buffer_Link ptr = this.FirstLink
	while link<>0
		var nextLink = link->NextLink
		link->destructor()
		KFree(link)
		link=nextLink
	wend
	
	'free the physical pages
	if (PagesCount>0) then
		for i as integer = 0 to PagesCount -1
			PMM_FREEPAGE(cptr(any ptr,PagesPhys[i]))
		next i
		KFree(PagesPhys)
	end if
	
	PrevBuffer	= 0
	NextBuffer	= 0
	PagesCount	= 0
	PagesPhys	= 0
	FirstLink   = 0
	LastLink	= 0
	Owner		= 0
	Magic		= 0
	
	ConsoleWriteLine(@"Shared buffer deleted")
end destructor

destructor shared_buffer_link()
	'unmap pages
	if (Owner<>0 and VirtualAddress<>0 and Buffer<>0) then
		dim virt as unsigned integer = VirtualAddress
		dim buff as SHARED_BUFFER ptr = Buffer
		for i as integer = 0 to buff->PagesCount -1
			Owner->VMM_CONTEXT.unmap_page(cptr(any ptr,virt))
			virt+=4096
		next i
	end if
	'clear values
	NextLink 		= 0
	PrevLink 		= 0	
	VirtualAddress	= 0
	Buffer	 		= 0
	Owner			= 0
	ConsoleWriteLine(@"Shared buffer link removed")
end destructor

function Shared_buffer.FindLink(proc as Process ptr) as SHARED_BUFFER_LINK ptr
	dim link as Shared_Buffer_Link ptr = this.FirstLink
	while link<>0
		if (link->Owner = proc) then return link
		link=link->NextLink
	wend
	return 0
end function

function Shared_buffer.RemoveLink(proc as Process ptr) as unsigned integer
	var link = this.FindLink(proc)
	if (link = 0) then return  0
	
	'unlink the node from the shared buffer
	if (link->PrevLink<>0) then link->PrevLink->NextLink = link->NextLink
	if (link->NextLink<>0) then link->NextLink->PrevLink = link->PrevLink 
	if FirstLink = link then FirstLink = link->NextLink
	if LastLink	 = link then LastLink  = link->PrevLink
	
	'destroy and free it
	link->Destructor()
	KFree(link)
	return 1
end function

static sub Shared_buffer.RemoveLinks(proc as Process ptr)
	var buff = FIRST_SHARED_BUFFER
	while buff<>0
		var n = buff->NextBuffer
		buff->RemoveLink(proc)
		buff = n
	wend
end sub

function Shared_buffer.CreateLink(proc as Process ptr) as Shared_Buffer_Link ptr
	dim result as Shared_Buffer_Link ptr = this.FindLink(proc)
	if (result<>0) then return result
	
	'//map the physical pages to the process address space
	dim virt as unsigned integer = proc->VMM_CONTEXT.find_free_pages(PagesCount,ProcessHeapAddress,&hFFFFFFFF)
	if (virt = 0) then return 0
	dim vaddr as unsigned integer = virt
	for i as integer = 0 to PagesCount-1
		proc->VMM_Context.MAP_PAGE(cptr(any ptr,vaddr),cptr(any ptr,PagesPhys[i]),VMM_FLAGS_USER_DATA)
		vaddr+=4096
	next i
	
	result 						= KAlloc(sizeof(Shared_Buffer_Link))
	result->Buffer				= @this
	result->Owner				= proc
	result->VirtualAddress		= virt
	result->PrevLink			= this.LastLink
	result->NextLink			= 0
	
	if (this.LastLink = 0) then
		this.FirstLink			= result
	else
		this.LastLink->NextLink = result
	end if
	this.LastLink				= result
	
	return result
end function