#include once "kernel.bi"
#include once "pmm.bi"
#include once "console.bi"

dim shared PageBitmap(0 to &hFFFFF) as unsigned byte



function PMM_GET_FREEPAGES_COUNT() as unsigned integer
    return TotalPagesCount
end function

sub PMM_INIT(mb_info as multiboot_info ptr)
    ConsoleWrite(@"Physical pages allocator initializing ...")
    MemoryEnd = cptr(any ptr,mb_info->mem_upper * 1024)
    FirstPage = (cuint(KEND) shr 12)+1
    LastPage = (mb_info->mem_upper shr 2)
    for i as unsigned integer = 0 to &hFFFFF
        PageBitmap(i)=0
    next i
    
    PMM_STRIPE(0,cuint(KEND))
    PMM_STRIPE(mb_info->mem_upper shl 10,&hFFFFFFFF)
    
    for i as integer = 0 to mb_info->mods_count-1
        var mod_start   = mb_info->mods_addr[i].mod_start
        var mod_end     = mb_info->mods_addr[i].mod_end
        PMM_STRIPE(mod_start,mod_end)
        PMM_STRIPE(cuint(mb_info->mods_addr[i].mod_string),cuint(mb_info->mods_addr[i].mod_string)+strlen(mb_info->mods_addr[i].mod_string)+1)
    next i
    
    
    TotalPagesCount = 0
    for i as unsigned integer = 0 to &hFFFFF
        if (PageBitmap(i)=0) then TotalPagesCount+=1
    next i
    TotalFreePages = TotalPagesCount
    ConsolePrintOK()
    ConsoleNewLine()
    
    ConsoleWriteTextAndSize(@"UPER MEMORY      :",(mb_info->mem_upper)*1024,true)
    ConsoleWriteTextAndDec(@"Availables free page",TotalPagesCount,true)
end sub

sub PMM_STRIPE(start_addr as unsigned integer,end_addr as unsigned integer)
    dim startPage as unsigned integer = start_addr shr 12
    dim endPage as unsigned integer = end_addr shr 12
    
    for i as unsigned integer = startPage to endPage
        PageBitmap(i) = &hFF
        TotalPagesCount-=1
        TotalFreePages-=1
    next
end sub

'allocate a contigous number of pages
'it will mark the bitmap cells as used, and put the count in the first cell
'so it can free all pages when freeing the pages
function PMM_ALLOCPAGE() as any ptr
    
    dim i as unsigned integer
    i = FirstPage
    while i < LastPage
        if (PageBitmap(i)= 0) then
            PageBitmap(i)=1
            TotalFreePages-=1
            return cptr(any ptr,i shl 12)
        end if
        i+=1
    wend
    return 0
end function


'it will fre the pages at this address
'the parameter is the address of the first page
'in the bitmap , the value is the count of contigous pages allocated
function PMM_FREEPAGE(addr as any ptr) as unsigned integer
    
    if (addr<>0) then
        var idx = cuint(addr) shr 12
        if (PageBitmap(idx)=1) then
            PageBitmap(idx)=0
            TotalFreePages+=1
            return 1
        else
            KERNEL_ERROR(@"Physical page is not used",cuint(addr))
        end if
    end if
    return 0
end function