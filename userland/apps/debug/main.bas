#include once "stdlib.bi"
#include once "stdlib.bas"

#include once "system.bas"
#include once "console.bas"
#include once "slab.bi"
#include once "slab.bas"
#include once "vfs.bas"
#include once "vfile.bas"

#include once "gdi.bi"
#include once "tobject.bi"
#include once "font.bi"
#include once "fontmanager.bi"
#include once "gimage.bi"

#include once "gdi.bas"
#include once "tobject.bas"
#include once "font.bas"
#include once "fontmanager.bas"
#include once "gimage.bas"

dim shared mainWin as unsigned integer
dim shared drawableImage as GImage ptr
dim shared txtInputFile as unsigned integer
dim shared txtOutputFile as unsigned integer
dim shared txtArguments as unsigned integer

declare sub btnClick(btn as unsigned integer,parm as unsigned integer)
declare sub ConsoleThread()
sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
	SlabInit()
    FontManager.Init()
    
	MainWin = GDIWindowCreate(645,410,@"Debug console")
	GDISetVisible(MainWin,0)
	
	drawableImage = cptr(GImage ptr,MAlloc(sizeof(GImage)))
	drawableImage->constructor(MainWin,0,0,645,405)
	drawableImage->Clear(&hFF000000)
    Thread_Create(@ConsoleThread)
	GDISetVisible(MainWin,1)
	
	ConsoleWrite(@"Console Ready")
    ConsolePrintOK()
    ConsoleNewLine()
	Thread_Wait_For_Event()
end sub

sub ConsoleThread()
    dim src as unsigned short ptr = cptr(unsigned short ptr,&hB8000)
    dim Colors16(0 to 15) as unsigned integer
    
    Colors16(0) = &hFF000000
    Colors16(1) = &hFF000088
    Colors16(2) = &hFF008800
    Colors16(3) = &hFF008888
    Colors16(4) = &hFF880000
    Colors16(5) = &hFF880088
    Colors16(6) = &hFF888800
    Colors16(7) = &hFFdddddd
    Colors16(8) = &hFF888888
    Colors16(9) = &hFF0000FF
    Colors16(10) = &hFF00FF00
    Colors16(11) = &hFF00FFFF
    Colors16(12) = &hFFFF0000
    Colors16(13) = &hFFFF00FF
    Colors16(14) = &hFFFFFF00
    Colors16(15) = &hFFFFFFFF
    dim i as unsigned integer
    dim xx as unsigned integer
    dim yy as integer
	dim cx as unsigned integer
    dim cy as unsigned integer
    
    
	do
        
		i=0
		xx = 0
        yy = 5'((drawableImage->_height)-(25*16))+2
		for cy = 0 to 24
			xx = 5
			for cx = 0 to 79
				dim b as unsigned integer = src[i] and &hFF
				dim c as unsigned integer = (src[i] shr 8) and &hFF
				dim fg as unsigned integer = c and &hF
				dim bg as unsigned integer = (c shr 4) and &hF
				
				if (xx>=0 and yy>=0 and xx+7<drawableImage->_width and yy+15<drawableImage->_height) then
					
                    drawableImage->FillRectangle(xx,yy,xx+7,yy+15,colors16(bg))
					drawableImage->DrawChar(b,xx,yy,colors16(fg),FontManager.ML,1)
				end if
				i+=1
				xx+=8
			next
			yy+=16
		next
        drawableImage->Flush()
		Thread_Sleep(100)
	loop
    
    
	do:loop
end sub

