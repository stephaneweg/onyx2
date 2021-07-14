TYPE EXECUTABLE_Header field =1
    Magic as unsigned integer
    Init  as unsigned integer
    ArgsCount as unsigned integer
    ArgsValues as unsigned byte ptr ptr
    ImageEnd as unsigned integer
end type



TYPE Process field =1
    
    Image as EXECUTABLE_Header ptr
    ImageSize as unsigned integer
    PrevProcessList as Process ptr
    NextProcessList as Process ptr
    Parent as Process ptr
    NextProcess as Process ptr
    
    LocalStorage(0 to 31) as unsigned integer
    
    Threads as any ptr
    
    VMM_Context as VMMContext
    TmpArgs as unsigned byte ptr
    
    ServerChannels as any ptr
    ClientChannels as any ptr
    
    
    FirstMutex as any ptr
    LastMutex as any ptr
    
    AddressSpace as AddressSpaceEntry ptr
    CodeAddressSpace as AddressSpaceEntry ptr
    
    WaitingThread           as any ptr
    
    declare function CreateMutex() as any ptr
    declare sub DeleteMutex(m as any ptr)
        
    declare function CreateAddressSpace(virt as unsigned integer) as AddressSpaceEntry ptr
    declare function FindAddressSpace(virt as unsigned integer)  as AddressSpaceEntry ptr
    declare sub RemoveAddressSpace(virt as unsigned integer)
    declare function AllocPage(n as unsigned integer,baseaddr as unsigned integer) as any ptr
    declare function AllocHeap(n as unsigned integer) as any ptr
    declare function AllocStack(n as unsigned integer) as any ptr
    
    declare static sub InitEngine()
    declare static function Create(image as EXECUTABLE_HEADER ptr,size as unsigned integer,args as unsigned byte ptr,parentProcess as Process ptr) as Process ptr
    declare static function CreateKernel(entryPoint as unsigned integer) as Process ptr
    
    declare static sub Terminate(app as Process ptr)
    declare static sub RequestTerminate(app as Process ptr)
    
    declare constructor()
    declare destructor()
    declare sub AddThread(t as any ptr)
    declare sub DoLoad()
    declare function DoLoadFlat() as unsigned integer
    declare function DoLoadElf() as unsigned integer
    declare sub ParseArguments()
    
end type

'the address where the service  process can map a buffer from a client
#define ProcessMapAddress &hA0001000
#define ProcessConsoleAddress &hA0000000
'the address where the process are loaded
#define ProcessAddress      &h40000000
#define ProcessHeapAddress  &h50000000
#define ProcessStackAddress &h60000000
dim shared FirstProcessList     as Process ptr
dim shared LastProcessList      as Process ptr
dim shared ProcessToTerminate   as Process ptr
dim shared KERNEL_PROCESS       as Process ptr
