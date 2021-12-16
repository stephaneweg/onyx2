#include once "stdlib.bi"
#include once "stdlib.bas"

#include once "system.bas"
#include once "console.bas"

sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
	dim virt as unsigned integer ptr = 0
	dim handle as unsigned integer = CreateSharedBuffer(64,@virt)
	ConsoleWrite(@"Shared buffer created : 0x")
	COnsoleWriteNumber(cuint(handle),16)
	ConsoleNewLIne()
	
	dim virt2 as unsigned integer ptr = MapSharedBuffer(handle)
	
	
	
	ConsoleWrite(@"Shared buffer Virtual : 0x")
	ConsoleWriteNumber(cuint(virt),16)
	ConsoleNewLIne()
	
	
	ConsoleWrite(@"Shared buffer Virtual2 : 0x")
	ConsoleWriteNumber(cuint(virt2),16)
	ConsoleNewLIne()
	
	var cpt = 64
	for i as unsigned integer = 0 to cpt
		virt2[i] =  i*2
	next
	
	
	for i as unsigned integer = 0 to cpt
		ConsoleWriteNumber(virt2[i],10)
		ConsoleNewLine()
	next
	UnmapSharedBuffer(handle)
	ConsoleWriteLine(@"Shared buffer unmapped")
	
	DeleteSharedBuffer(handle)
    Process_Exit()
end sub
