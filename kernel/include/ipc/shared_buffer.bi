

TYPE SHARED_BUFFER_LINK field = 1
	NextLink			as SHARED_BUFFER_LINK ptr
	PrevLink			as SHARED_BUFFER_LINK ptr
	Owner				as Process ptr
	VirtualAddress		as unsigned integer
	Buffer				as any ptr
	declare destructor()
end TYPE

TYPE SHARED_BUFFER field = 1
	MAGIC		as unsigned integer
	Owner		as Process ptr
	PagesCount	as unsigned integer
	PagesPhys	as unsigned integer ptr
	FirstLink   as SHARED_BUFFER_LINK ptr
	LastLink	as SHARED_BUFFER_LINK ptr
	
	PrevBuffer	as SHARED_BUFFER ptr
	NextBuffer	as SHARED_BUFFER ptr
	
	
	declare constructor(proc as process ptr, pcount as unsigned integer)
	declare destructor()
	declare function CreateLink(proc as Process ptr) as SHARED_BUFFER_LINK ptr
	declare function FindLink(proc as Process ptr) as SHARED_BUFFER_LINK ptr
	declare function RemoveLink(proc as Process ptr) as unsigned integer
	declare static sub RemoveLinks(proc as Process ptr)
end TYPE

const SHARED_BUFFER_MAGIC = &hBBFFFFEE
dim shared FIRST_SHARED_BUFFER as SHARED_BUFFER ptr
dim shared LAST_SHARED_BUFFER as SHARED_BUFFER ptr