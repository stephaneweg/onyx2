
dim shared keymapPtr as unsigned integer ptr
dim shared KEYMAP as unsigned byte ptr
dim shared KEYMAP_ALT as unsigned byte ptr
dim shared KEYMAP_SHIFT as unsigned byte ptr

dim shared NextArrow as unsigned byte

sub loadKeys()
    dim kmapsize as unsigned integer
    keymapPtr =cptr(unsigned integer ptr, VFS_LOAD_FILE(@"SYS:/KEYS/FR.MAP",@kmapsize))
    
    if (kmapsize<>0 and keymapPtr <> 0) then
        var kmapBase = cast(unsigned integer,keymapPtr)
        KEYMAP = cptr(unsigned byte ptr, keymapPtr[0] + kmapBase)
        KEYMAP_ALT = cptr(unsigned byte ptr, keymapPtr[1] + kmapBase)
        KEYMAP_SHIFT = cptr(unsigned byte ptr, keymapPtr[2] + kmapBase)
        
        KBD_CTRL=0
        KBD_ALT=0
        KBD_SHIFT=0
        KBD_CIRC=0
        KBD_GUILLEMETS=0
        KEYBOARD_Loaded = 1
    end if
end sub

sub INIT_KBD()
    loadKeys()
    dim akey as unsigned byte = 0
    do
        inb(&h60,[akey])
    loop while akey = 0
	
    KBD_Thread = Thread_Create(@KBD_Thread_Loop)
end sub

sub KBD_Thread_Loop(p as any ptr)
    IRQ_ENABLE(&h21)
    IRQ_Create_Handler(&h21,@KBD_IRQ_Handler)
    Thread_Wait_For_Event()
	do:loop
end sub

sub KBD_IRQ_Handler()
    dim akey as unsigned byte
	inb(&h60,[akey])
    KBD_HANDLER(akey)
    Thread_IRQ_Handler_End()
end sub

sub KBD_PutChar(char as unsigned byte)
    STDIO_WRITE_BYTE(STDIN,char)
end sub



sub KBD_HANDLER(akey as unsigned byte)
    if (akey=224) then
        NextArrow = 128
    else
        select case akey
            case KEY_CTRL:
                KBD_CTRL=1
            case KEY_CTRL+128:
                KBD_CTRL=0
            case KEY_ALT:
                KBD_ALT=1
            case KEY_ALT+128:
                KBD_ALT=0
            case KEY_SHIFT1:
                KBD_SHIFT=1
            case KEY_SHIFT2:
                KBD_SHIFT=2
            case KEY_SHIFT1+128:
                KBD_SHIFT=KBD_SHIFT AND 2
            case KEY_SHIFT2+128:
                KBD_SHIFT=KBD_SHIFT AND 1
            case else:
                if akey<128 then
                    
                    dim k as unsigned byte=0
                    if KBD_SHIFT>0 then 
                        k=KEYMAP_SHIFT[akey]
                    elseif KBD_ALT>0 then
                        k=KEYMAP_ALT[akey]
                    else
                        k=KEYMAP[akey]
                    end if
                    
                    
                    if k=94 then
                        KBD_CIRC=1
                        k=0
                    elseif k=249 then
                        KBD_GUILLEMETS=1
                        k=0
                    else
                        if KBD_CIRC=1 then
                            select case k
                            case 97: k=131 '?
                            case 101:k=136 '?
                            case 105:k=140 '?
                            case 111:k=147 '?
                            case 117:k=150 '?
                            end select
                        elseif KBD_GUILLEMETS=1 then
                            select case k
                            case 97: k=132 '?
                            case 101:k=137 '?
                            case 105:k=139 '?
                            case 111:k=148 '?
                            case 117:k=129 '?
                            end select
                        end if
                        KBD_CIRC=0
                        KBD_GUILLEMETS=0
                    end if
                    
                    
                    if (k<>0) then 
                        if (KBD_CTRL=1) then
                            KBD_PutChar(KEY_CTRL)
                        end if
                        KBD_PutChar(k or NextArrow)
                    end if
                end if
        end select
        NextArrow = 0
    end if
end sub