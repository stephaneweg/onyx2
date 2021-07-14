Type Mutex field =1
    value as unsigned integer
    ThreadQueue as Thread ptr
    CurrentThread as Thread ptr
    OwnerProcess as Process ptr
    
    PrevMutex as Mutex ptr
    NextMutex as Mutex ptr
    declare constructor()
    declare destructor()
    
    declare function Acquire(th as thread ptr) as unsigned integer
    declare sub Release(th as thread ptr)
    
end type




    
