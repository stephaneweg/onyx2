#include once "stdlib.bi"
#include once "stdlib.bas"


#include once "system.bas"
#include once "stdio.bas"


sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
	STDIO_INIT()
    if (argc>0) then
		STDIO_WRITE_LINE(0,argv[0])
    end if
    Process_Exit()
end sub
