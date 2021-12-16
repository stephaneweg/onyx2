#include once "console.bi"

sub ConsolePutChar(b as unsigned byte)
    asm
        mov eax,&h0
        xor ebx,ebx
        mov bl,[b]
        int 0x31
    end asm
end sub

Sub ConsoleWrite(s As Unsigned Byte Ptr)
    Asm
        mov eax,&h1
        mov ebx,[s]
        Int 0x31
    End Asm
End Sub

Sub ConsoleWriteLine(s As Unsigned Byte Ptr)
    Asm
        mov eax,&h2
        mov ebx,[s]
        Int 0x31
    End Asm
End Sub

Sub ConsoleWriteNumber(n As Unsigned Integer,b As Unsigned Integer)
    Asm
        mov eax,&h3
        mov ebx,[n]
        mov ecx,[b]
        Int 0x31
    End Asm
End Sub

Sub ConsoleNewLine()
    Asm
        mov eax,&h4
        Int 0x31
    End Asm
End Sub

sub ConsolePrintOK()
    asm
        mov eax,&h5
        int 0x31
    end asm
end sub

sub ConsoleBackSpace()
    asm
        mov eax,&h06
        int 0x31
    end asm
end sub

sub ConsoleSetForeground(c as unsigned integer)
    asm
        mov eax,&h07
        mov ebx,[c]
        int 0x31
    end asm
end sub

sub ConsoleSetBackground(c as unsigned integer)
    asm
        mov eax,&h08
        mov ebx,[c]
        int 0x31
    end asm
end sub