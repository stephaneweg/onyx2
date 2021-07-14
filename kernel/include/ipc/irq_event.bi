TYPE IRQ_EVENT_HANDLER field = 1
    OWNER_PROCESS as ANY PTR
    OWNER_THREAD as ANY PTR
    COUNT as unsigned integer
    ENTRY as unsigned integer
end type


dim shared IRQ_EVENT_HANDLERS(&h0 to &h2f) as IRQ_EVENT_HANDLER
declare sub INIT_IRQ_EVENT_HANDLERS()
declare function SET_IRQ_EVENT_HANDLER(intno as unsigned integer,proc as any ptr,th as any ptr,entry as unsigned integer) as unsigned integer
declare function IRQ_EVENT_SIGNAL(intno as unsigned integer) as unsigned integer
declare function IRQ_EVENT_CHECK_ETC(intno as unsigned integer,th as any ptr) as unsigned integer
declare function IRQ_EVENT_CHECK(th as any ptr) as unsigned integer
declare sub IRQ_EVENT_THREAD_TERMINATED(t as unsigned integer)

    