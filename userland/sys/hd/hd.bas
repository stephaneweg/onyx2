#include once "in_out.bi"
const HD_PRIMARBASE = &h1f0
const HD_SECUNDBASE = &h170


type PARTINFO field=1
	bootflag as unsigned byte
	head as unsigned byte
	geom as unsigned short
	id as unsigned byte
	endhead as unsigned byte
	endgeom as unsigned short
	startpos as unsigned integer
	nbrsect as unsigned integer
end type


type HD_RES field = 1
    MAGIC       as unsigned integer
    HD_NAME     as unsigned byte ptr
    IS_FREE     as unsigned integer
    DiskNumber  as unsigned integer
	Begin       as unsigned integer
	SectorCount as unsigned integer
    BytesCount  as unsigned integer
    
    DEVICE_HANDLE as unsigned integer
    
    declare function Read(alba as unsigned integer,sectorcount as unsigned short,b as byte ptr) as unsigned integer
    declare function Write(alba as unsigned integer,sectorcount as unsigned short,b as byte ptr) as unsigned integer
    declare static function Create(_
        resname as unsigned byte ptr,_
        diskNum as integer,_
        Begin as unsigned integer,_
        sectCount as unsigned integer,_
        bytesCount as unsigned integer) as HD_RES ptr
end type
dim shared DiskNames(0 to 3) as byte ptr
dim shared PartitionNames(0 to 3,0 to 3) as byte ptr
dim shared HD_BUFFER as byte ptr
dim shared HD_IPC as unsigned integer
dim shared HD_RESSOURCES(1 to 255) as HD_RES

declare sub HD_Detect()
declare sub HD_DetectSingle(pbase as unsigned short)
declare sub HD_WAIT(disknum as unsigned short)
declare sub DETECT_PARTITIONS(dev as HD_RES ptr)

declare sub HD_IPC_Handler(_intno as unsigned integer,_senderproc as unsigned integer,_sender as unsigned integer, _
	_eax as unsigned integer,_ebx as unsigned integer,_ecx as unsigned integer,_edx as unsigned integer, _
	_esi as unsigned integer,_edi as unsigned integer,_ebp as unsigned integer,_esp as unsigned integer)
    
declare function Create_HD_IPC_Handler() as unsigned integer
declare function AllocHDRes() as unsigned integer

function AllocHDRes() as unsigned integer
    for i as unsigned integer = lbound(HD_RESSOURCES) to ubound(HD_RESSOURCES)
        if (HD_RESSOURCES(i).IS_FREE = 1) then
            HD_RESSOURCES(i).IS_FREE = 0
            return i
        end if
    next
    return 0
end function

function HD_RES_Validate(b as unsigned integer) as unsigned integer
    if (b>=lbound(HD_RESSOURCES)) and _
       (b<=ubound(HD_RESSOURCES)) then
       var res = @HD_RESSOURCES(b)
       if (res->MAGIC = &h12341234) and (RES->IS_FREE = 0) then return 1
    end if
    return 0
end function

function HD_RES.Create( _
        resname as unsigned byte ptr,_
        diskNum as integer,_
        Begin as unsigned integer,_
        sectCount as unsigned integer,_
        bytesCount as unsigned integer) as HD_RES ptr
    var res = AllocHDRes()
    
    if (res<>0) then
        HD_RESSOURCES(res).MAGIC      = &h12341234
        HD_RESSOURCES(res).HD_NAME    = resname
        HD_RESSOURCES(res).DiskNumber = diskNum
        HD_RESSOURCES(res).Begin      = Begin
        HD_RESSOURCES(res).SectorCount    = sectCount
        HD_RESSOURCES(res).BytesCount     = bytesCount
        var h = DEVMAN_REGISTER(1,resname,HD_IPC,res)
        return @HD_RESSOURCES(res)
    end if
    return 0
end function



sub HD_Detect()
    ConsoleWriteLine(@"Detecting HD")
	
	DiskNames(0) = @"HDA"
	DiskNames(1) = @"HDB"
	DiskNames(2) = @"HDC"
	DiskNames(3) = @"HDD"
	PartitionNames(0,0)=@"HDA1"
	PartitionNames(0,1)=@"HDA2"
	PartitionNames(0,2)=@"HDA3"
	PartitionNames(0,3)=@"HDA4"
	PartitionNames(1,0)=@"HDB1"
	PartitionNames(1,1)=@"HDB2"
	PartitionNames(1,2)=@"HDB3"
	PartitionNames(1,3)=@"HDB4"
	PartitionNames(2,0)=@"HDC1"
	PartitionNames(2,1)=@"HDC2"
	PartitionNames(2,2)=@"HDC3"
	PartitionNames(2,3)=@"HDC4"
	PartitionNames(3,0)=@"HDD1"
	PartitionNames(3,1)=@"HDD2"
	PartitionNames(3,2)=@"HDD3"
	PartitionNames(3,3)=@"HDD4"
    HD_BUFFER = PAlloc(1)
    HD_DetectSingle(HD_PRIMARBASE)
    HD_DetectSingle(HD_SECUNDBASE)
end sub

sub HD_DetectSingle(pbase as unsigned short)
    dim rv1 as unsigned byte,rv2 as unsigned byte
    dim inpbase7 as unsigned integer
	dim cpt as integer
    dim pbase3 as unsigned short = pbase+3
    dim pbase6 as unsigned short = pbase+6
    dim pbase7 as unsigned short = pbase+7
    
	outb([pbase3],&h88)
	inb([pbase3],[rv1])
	outb([pbase3],&h88)
	inb([pbase3],[rv2])
    if pbase=HD_PRIMARBASE then
        cpt=0
    else 
        cpt=2
    end if
	if (rv1 = &h88) then
		outb([pbase6],&hA0)
        inb([pbase7],[inpbase7])
		if (inpbase7 AND &h40)>0 then
            ConsoleWrite(@"Found "):ConsoleWriteLine(DiskNames(cpt))
                var hd = HD_RES.Create(DiskNames(cpt),cpt,0,0,0)
				DETECT_PARTITIONS(hd)
				
		end if
		outb([pbase6],&hB0)
        inb([pbase7],[inpbase7])
		if (inpbase7 AND &h40)>0 then
            ConsoleWrite(@"Found "):ConsoleWriteLine(DiskNames(cpt+1))
                var hd = HD_RES.Create(DiskNames(cpt+1),cpt+1,0,0,0)
				DETECT_PARTITIONS(hd)
		end if
	end if
end sub

sub DETECT_PARTITIONS(dev as HD_RES ptr)
	dim cpt as integer
	dim table as PARTINFO ptr = cptr(PARTINFO ptr,HD_BUFFER+446)
	dev->READ(0,1,HD_BUFFER)
	for cpt = 0 to 3
		if (table[cpt].ID AND &hFF) >0 then
            var part = HD_RES.Create(PartitionNames(dev->DiskNumber,cpt),dev->DiskNumber,table[cpt].startpos,table[cpt].nbrsect,table[cpt].nbrsect shl 9)
		end if
	next
end sub



function HD_RES.Write(alba as unsigned integer,sectorcount as unsigned short,b as byte ptr) as unsigned integer
	dim lba0 as unsigned byte
    dim lba1 as unsigned byte
    dim lba2 as unsigned byte
    dim lba3 as unsigned byte
    dim lba4 as unsigned byte
    dim lba5 as unsigned byte
    
	dim abase as unsigned short
    dim abase2 as unsigned short
    dim abase3 as unsigned short
    dim abase4 as unsigned short
    dim abase5 as unsigned short
    dim abase6 as unsigned short
    dim abase7 as unsigned short
    
    dim out1 as unsigned byte
    dim out2 as unsigned byte
    dim outwval as unsigned short
    
	dim mydrive as unsigned byte
	dim nanosleep as unsigned byte
	dim buffer as unsigned short ptr=cptr(unsigned short ptr,b)
	dim x as unsigned integer
	dim cpt as integer
	if (this.DiskNumber<4) then
		'//lba48 pio
		'//selection du controleur et du disque
		select case this.DiskNumber
			case 0:
				abase=HD_PRIMARBASE
				mydrive=&h40
			case 1:
				abase=HD_PRIMARBASE
				mydrive=&h50
			case 2:
				abase=HD_SECUNDBASE
				mydrive=&h40
			case 3:
				abase=HD_SECUNDBASE
				mydrive=&h50
		end select
        
        abase2 = abase+2
        abase3 = abase+3
        abase4 = abase+4
        abase5 = abase+5
        abase6 = abase+6
        abase7 = abase+7
        
		lba0 =  alba AND &h000000FF
		lba1 = (alba AND &h0000FF00) shr 8
		lba2 = (alba AND &h00FF0000) shr 16
		lba3 = (alba AND &hFF000000) shr 24
		'//limit to 32bits (should be suffisant to read up to 2Tera
		lba4 = &h0
		lba5 = &h0
		
        out1 = (sectorcount and &hFF00) shr 8
        out2 = (sectorcount AND &hff)
		outb([abase6],[mydrive])	'//quel disque
		'//high
		outb([abase2],[out1]) ';//sector count high
		outb([abase3],[lba3])	';//LBA 4rd
		outb([abase4],[lba4]) ';//LBA 5rd
		outb([abase5],[lba5]) ';//LBA 5rd
		'//low
		outb([abase2],[out2]) ';//sectorcount low byte
		outb([abase3],[lba0])	'//LBA 1st
		outb([abase4],[lba1])	'//LBA 2nd
		outb([abase5],[lba2])	'//LBA 3rd
		outb([abase7],&h34)	'//Send "WRITE SECTOR EXT

		'//Wait for device to become ready
        dim buff as unsigned integer = cast(unsigned integer,b)
		for cpt=0 to sectorcount-1
                HD_WAIT(abase)
                asm
                    mov esi,[buff]
                    mov ecx,256
                    mov edx,[abase]
                    rep outsw
                end asm
                buff+=512
		next
		outw([abase7],&he7) 'Cache flush
        return 1
	end if
	return 0
end function




function HD_RES.Read(alba as unsigned integer,sectorcount as unsigned short,b as byte ptr) as unsigned integer	
    dim lba0 as unsigned byte
    dim lba1 as unsigned byte
    dim lba2 as unsigned byte
    dim lba3 as unsigned byte
    dim lba4 as unsigned byte
    dim lba5 as unsigned byte
    
	dim abase as unsigned short
    dim abase2 as unsigned short
    dim abase3 as unsigned short
    dim abase4 as unsigned short
    dim abase5 as unsigned short
    dim abase6 as unsigned short
    dim abase7 as unsigned short
    dim out1 as unsigned byte
    dim out2 as unsigned byte
	dim mydrive as unsigned byte
	dim nanosleep as unsigned byte
	dim buffer as unsigned short ptr=cptr(unsigned short ptr,b)
	dim x as unsigned integer
	dim cpt as integer
    dim inwres as unsigned short
	if (this.DiskNumber<4) then
		'//lba48 pio
		'//selection du controleur et du disque
		select case this.DiskNumber
			case 0:
				abase=HD_PRIMARBASE
				mydrive=&h40
			case 1:
				abase=HD_PRIMARBASE
				mydrive=&h50
			case 2:
				abase=HD_SECUNDBASE
				mydrive=&h40
			case 3:
				abase=HD_SECUNDBASE
				mydrive=&h50
		end select
        abase2 = abase+2
        abase3 = abase+3
        abase4 = abase+4
        abase5 = abase+5
        abase6 = abase+6
        abase7 = abase+7
		lba0 =  alba AND &h000000FF
		lba1 = (alba AND &h0000FF00) shr 8
		lba2 = (alba AND &h00FF0000) shr 16
		lba3 = (alba AND &hFF000000) shr 24
		'//limit to 32bits (should be suffisant to read up to 2Tera
		lba4 = &h0
		lba5 = &h0
        
        out1 = (sectorcount and &hFF00) shr 8
        out2 = (sectorcount AND &hff)
		
		outb([abase6],[mydrive])	'//quel disque
		'//high
		outb([abase2],[out1]) ';//sector count high
		outb([abase3],[lba3])	';//LBA 4rd
		outb([abase4],[lba4]) ';//LBA 5rd
		outb([abase5],[lba5]) ';//LBA 5rd
		'//low
		outb([abase2],[out2]) ';//sectorcount low byte
		outb([abase3],[lba0])	'//LBA 1st
		outb([abase4],[lba1])	'//LBA 2nd
		outb([abase5],[lba2])	'//LBA 3rd
		outb([abase7],&h24)	'//Send "READ SECTOR EXT

		'//Wait for device to become ready
        dim buff as unsigned integer = cast(unsigned integer,b)
		for cpt=0 to sectorcount-1
                HD_WAIT(abase)
                asm
                    mov edi,[buff]
                    mov ecx,256
                    mov edx,[abase]
                    rep insw
                end asm
                buff+=512
                
		next
		return 1
	end if
	return 0
end function

sub HD_WAIT(abase as unsigned short)
    dim abase7 as unsigned short= abase+7
    dim val7 as unsigned byte
    do
        inb([abase7],[val7])
         
    loop until (val7 and &h80) = 0
END SUB