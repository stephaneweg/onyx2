Sub Thread_Set_Idle()
    Asm
        mov eax,0
        Int 0x30
    End Asm
End Sub

Function Process_Create(image As Any Ptr,imageSize As Unsigned Integer,args As Unsigned Byte Ptr,dowait As Unsigned Integer) As Unsigned Integer
    Asm
        mov eax,&h01
        mov ebx,[image]
        mov ecx,[imageSize]
        mov edx,[dowait]
        mov esi,[args]
        Int 0x30
        mov [Function],eax
    End Asm
End Function

Sub Process_Exit()
    Asm
        mov eax,&h02
        Int 0x30
    End Asm
End Sub

Function Process_Kill(proc As Unsigned Integer) As Unsigned Integer
    Asm
        mov eax,&h03
        mov ebx,[proc]
        Int 0x30
        mov [Function],eax
    End Asm
End Function

function Process_Get_Parent(proc as unsigned integer) as unsigned integer
    asm
        mov eax,&h1C
        mov ebx,[proc]
        int 0x30
        mov [function],eax
    end asm
end function

Function Thread_Create(entry As Any Ptr) As Unsigned Integer
    Asm
        mov eax,&h04
        mov ebx,[entry]
        Int 0x30
        mov [Function],eax
    End Asm
End Function

Sub Thread_Exit()
    Asm
        mov eax,&h05
        Int 0x30
    End Asm
End Sub

Sub Thread_Yield()
    Asm
        mov eax,&h06
        Int 0x30
    End Asm
End Sub

Sub Thread_Wake_Up(t As Unsigned Integer,p1 As Unsigned Integer,p2 As Unsigned Integer)
    Asm
        mov eax,&h08
        mov ebx,[t]
        mov ecx,[p1]
        mov edx,[p2]
        Int 0x30
    End Asm
End Sub

Sub Thread_Sleep(ms As Unsigned Integer)
    Asm
        mov eax,&h0F
        mov ebx,[ms]
        Int 0x30
    End Asm
End Sub


sub Thread_Enter_Critical()
	asm
		mov eax ,&hE1
		int 0x30
	end asm
end sub

sub Thread_Exit_Critical()
	asm
		mov eax,&hE2
		int 0x30
	end asm
end sub

#macro Thread_Wait_For_Event()
Asm
    mov eax,&h07
    Int 0x30
End Asm
Do:Loop
#endmacro

#macro Thread_IRQ_Handler_End()
Asm
    mov esp,ebp
    add esp,4
    mov eax,&h07
    Int 0x30
End Asm
Do:Loop
#endmacro


#macro Thread_Callback_End()
asm
    mov esp,ebp
    add esp,12 'remove parameters (sender+args) and return addr to the stack
    mov eax,0x07
    int 0x30
end asm
do:loop
#endmacro
'--------------------------------------------
' thread synchronisation system calls
'------------------------------------------
Function Mutex_Create() As Unsigned Integer
    Asm
        mov eax,&h09
        Int 0x30
        mov [Function],eax
    End Asm
End Function

Sub Mutex_Lock(m As Unsigned Integer)
    Asm
        mov eax,&h0A
        mov ebx,[m]
        Int 0x30
    End Asm
End Sub

Sub Mutex_Unlock(m As Unsigned Integer)
    Asm
        mov eax,&h0B
        mov ebx,[m]
        Int 0x30
    End Asm
End Sub

Function Event_Create() As Unsigned Integer
    Asm
        mov eax,&h0C
        Int 0x30
        mov [Function],eax
    End Asm
End Function

Function Event_Wait(ev As Unsigned Integer) As Unsigned Integer
    Asm
        mov eax,&h0D
        mov ebx,[ev]
        Int 0x30
        mov [Function],eax
    End Asm
End Function

Sub Event_Set(ev As Unsigned Integer)
    Asm
        mov eax,&h0E
        mov ebx,[ev]
        Int 0x30
    End Asm
End Sub

'--------------------------------
'      IRQ and IPC
'---------------------------------
Function IRQ_Create_Handler(irq_num As Unsigned Integer,s As Any Ptr) As Unsigned Integer
    Asm
        mov eax,&h13
        mov ebx,[irq_num]
        mov ecx,[s]
        Int 0x30
        mov [Function],eax
    End Asm
End Function

Sub IRQ_Enable(irq_num As Unsigned Integer)
    Asm
        mov eax,&h14
        mov ebx,[irq_num]
        Int 0x30
    End Asm
End Sub

Function IPC_Create_Handler_ID(ipc_num As Unsigned Integer,s As Any Ptr,synchronous As Unsigned Integer) As Unsigned Integer
    Asm
        mov eax,&h15
        mov ebx,[ipc_num]
        mov ecx,[s]
        mov edx,[synchronous]
        Int 0x30
        mov [Function],eax
    End Asm
End Function

Function IPC_Create_Handler_Name(ipc_name As unsigned byte ptr,s As Any Ptr,synchronous As Unsigned Integer) As Unsigned Integer
    Asm
        mov eax,&h16
        mov esi,[ipc_name]
        mov ecx,[s]
        mov edx,[synchronous]
        Int 0x30
        mov [Function],eax
    End Asm
End Function

Function IPC_Create_Handler_Anonymous(s As Any Ptr,synchronous As Unsigned Integer) As Unsigned Integer
    Asm
        mov eax,&h17
        mov ecx,[s]
        mov edx,[synchronous]
        Int 0x30
        mov [Function],eax
    End Asm
End Function

#macro IPC_Handler_End_No_Reply()
Asm
    mov esp,ebp
    Add esp,48
    mov eax,0x07
    Int 0x30
End Asm
Do:Loop
#endmacro

#macro IPC_Handler_End_With_Reply()
Asm
    mov eax,0x18
    Int 0x30
End Asm
Do:Loop
#endmacro

function IPC_Find(ipc_name as unsigned byte ptr) as unsigned integer
    asm
        mov eax,&h19
        mov esi,[ipc_name]
        int 0x30
        mov [function],eax
    end asm
end function

function IPC_Send(ipc_num as unsigned integer,r0 as unsigned integer,r1 as unsigned integer,r2 as unsigned integer, _
    r3 as unsigned integer,r4 as unsigned integer,r5 as unsigned integer,r6 as unsigned integer,r7 as unsigned integer, _
    result2 as unsigned integer ptr,result3 as unsigned integer ptr) as unsigned integer
    dim b as any ptr = @r0
    dim res1 as unsigned integer
    dim res2 as unsigned integer
    dim res3 as unsigned integer
    asm
        mov eax,&h1A
        mov ebx,[ipc_num]
        mov ecx,[b]
        int 0x30
        mov [res1],eax
        mov [res2],ebx
        mov [res3],ecx
    end asm 
    if (result2<>0) then *result2 = res2
    if (result3<>0) then *result3 = res3
    return res1
end function

Sub IPC_Signal_Thread(t As Unsigned Integer,callback As Unsigned Integer,p1 As Unsigned Integer,p2 As Unsigned Integer)
    Asm
        mov eax,&h1B
        mov ebx,[t]
        mov ecx,[callback]
        mov esi,[p1]
        mov edi,[p2]
        Int 0x30
    End Asm
End Sub

'----------------------------------------------
' Inter process memory mapping
'----------------------------------------------
function GetStringFromCaller(dst as unsigned byte ptr,src as unsigned integer) as unsigned integer
    asm
        mov eax,&h20
        mov esi,[src]
        mov edi,[dst]
        int 0x30
        mov [function],eax
    end asm
end function

sub SetStringToCaller(dst as unsigned integer,src as unsigned byte ptr)
     asm
        mov eax,&h21
        mov esi,[src]
        mov edi,[dst]
        int 0x30
    end asm
end sub

function MapBufferFromCaller(src as any ptr,size as unsigned integer) as any ptr
    asm
        mov eax,&h22
        mov esi,[src]
        mov ecx,[size]
        int 0x30
        mov [function],eax
    end asm
end function

function MapBufferToCaller(src as any ptr,size as unsigned integer) as any ptr
    asm
        mov eax,&h23
        mov esi,[src]
        mov ecx,[size]
        int 0x30
        mov [function],eax
    end asm
end function

sub UnMapBuffer(addr as any ptr,size as unsigned integer)
    asm
        mov eax,&h24
        mov ebx,[addr]
        mov ecx,[size]
        int 0x30
    end asm
end sub

function CreateSharedBuffer(pagesCount as unsigned integer,virtAddress as any ptr ptr) as unsigned integer
    dim virt as unsigned integer
    dim handle as unsigned integer
    asm
        mov eax,&h25
        mov ecx,[pagesCount]
        int 0x30
        mov [handle],eax
        mov [virt],ebx
    end asm
    *virtAddress=cptr(any ptr,virt)
    return handle
end function

function MapSharedBuffer(handle as unsigned integer) as any ptr
    asm
        mov eax,&h26
        mov ebx,[handle]
        int 0x30
        mov [function],eax
    end asm
end function

sub UnmapSharedBuffer(handle as unsigned integer)
    asm
        mov eax,&h27
        mov ebx,[handle]
        int 0x30
    end asm
end sub

sub DeleteSharedBuffer(handle as unsigned integer)
    asm
        mov eax,&h28
        mov ebx,[handle]
        int 0x30
    end asm
end sub
    
'---------------------------------------
' memory management
'--------------------------------------

function PAlloc(cnt as unsigned integer) as any ptr
    asm
        mov eax,&h30
        mov ebx,[cnt]
        int 0x30
        mov [function],eax
    end asm
end function

sub PFree(addr as any ptr)
    asm
        mov eax,&h31
        mov ebx,[addr]
        int 0x30
    end asm
end sub


'------------------------------------------------
' misc
'------------------------------------------------

function GetTimer() as unsigned longint
     dim u1 as unsigned longint = 1
     asm
         mov eax,&hE9
         int 0x30
         mov [u1],eax
         mov [u1+4],ebx
     end asm
     return u1
end function

function GetRandomNumber(_min as unsigned integer,_max as unsigned integer) as unsigned integer
    asm
        mov eax,&hF0
        mov ebx,[_min]
        mov ecx,[_max]
        int 0x30
        mov [function],eax
    end asm
end function

function GetTimeBCD() as unsigned integer
    asm
        mov eax,&hF1
        int 0x30
        mov [function],eax
    end asm
end function

function GetDateBCD() as unsigned integer
    asm
        mov eax,&hF2
        int 0x30
        mov [function],eax
    end asm
end function

sub GetScreenInfo(_xres as unsigned integer ptr,_yres as unsigned integer ptr,_bpp as unsigned integer ptr,_lfb as unsigned integer ptr, _lfbsize as unsigned integer ptr)
	dim resolution as unsigned integer
	dim _abpp as unsigned integer
	dim _alfb as unsigned integer
	dim _alfbsize as unsigned integer
	asm
		mov eax,&hF3
		int 0x30
		mov [resolution],eax
		mov [_abpp],ebx
		mov [_alfbsize],ecx
		mov [_alfb],edi
	end asm
	*_lfb = _alfb
	*_lfbsize = _alfbsize
	*_bpp = _abpp
	*_xres = (resolution shr 16) and &hFFFF
	*_yres = (resolution) and &hFFFF
end sub

sub GetMemInfo(totalPages as unsigned integer ptr,freePages as unsigned integer ptr,slabCount as unsigned integer ptr)
        dim tp as unsigned integer
        dim fp as unsigned integer
        dim sc as unsigned integer
        asm
            mov eax,&hF4
            int 0x30
            mov [tp],eax
            mov [fp],ebx
            mov [sc],ecx
        end asm
        *totalPages = tp
        *freePages  = fp
        *slabCount  = sc
end sub

function GetIdleCount() as unsigned integer
    asm
        mov eax ,&hF5
        int 0x30
        mov [function],eax
    end asm
end function

function GetRunMode() as unsigned integer
    asm
        mov eax ,&hF6
        int 0x30
        mov [function],eax
    end asm
end function

function GetProcessLocalStorage(proc as unsigned integer,index as unsigned integer) as unsigned integer
    asm
        mov eax,&hF7
        mov ebx,[proc]
        mov ecx,[index]
        int 0x30
        mov [function],eax
    end asm
end function

sub SetProcessLocalStorage(proc as unsigned integer,index as unsigned integer,value as unsigned integer)
    asm
        mov eax,&hF8
        mov ebx,[proc]
        mov ecx,[index]
        mov edx,[value]
        int 0x30
    end asm
end sub
    