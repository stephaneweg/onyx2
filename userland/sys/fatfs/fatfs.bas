#include once "vfs.bi"

function FAT_DETECT() as unsigned integer
    dim myboot as FAT_BOOTSECTOR ptr        
    dim MyBoot16 as BS16 ptr
    dim MyBoot32 as BS32 ptr
    dim sign as unsigned byte
    
    myboot= PAlloc(1)
    MyBoot16=cptr(BS16 ptr, cast(unsigned integer,myboot)+sizeof(FAT_BOOTSECTOR))
    MyBoot32=cptr(BS32 ptr, cast(unsigned integer,myboot)+sizeof(FAT_BOOTSECTOR))
    
    
    if (DEVICE.READ(0,1,cptr(unsigned byte ptr,myboot))=0) then
        PFree(myboot)
        ConsoleSetForeground(12)
        ConsoleWriteLine(@"UNABLE TO READ BLOCK DEVICE")
        ConsoleSetForeground(7)
        return 0
    end if
    
    if (myboot->bps=0) or (myboot->spc=0) then
        PFree(myboot)
        ConsoleSetForeground(12)
        ConsoleWriteLine(@"BPS or SPC values is invalid")
        ConsoleWrite(@"BPS : "):COnsoleWriteNumber(myboot->BPS,10):ConsoleNewLine()
        ConsoleWrite(@"SPC : "):COnsoleWriteNumber(myboot->spc,10):ConsoleNewLine()
        ConsoleSetForeground(7)
        return 0
    end if
        
    var seccount = iif(myboot->Sectors_Count<>0,myboot->Sectors_Count,myboot->Sectors_Count2)
    if (seccount=0) then
        PFree(myboot)
        ConsoleSetForeground(12)
        ConsoleWrite(@"INVALID SECTOR COUNT : "):ConsoleWriteNumber(seccount,10):ConsoleNewLine()
        ConsoleSetForeground(7)
        return 0
    end if
    
    SECTOR_COUNT = seccount
    if SECTOR_COUNT<4085  then
        FAT_TYPE=12
        ConsoleWrite(@" FAT12 ")
        sign=MyBoot16->Signature
        FAT_LIMIT=&hFF8
    elseif myboot->spf<>0 then ' SECTOR_COUNT<65525 then
        FAT_TYPE=16
        ConsoleWrite(@" FAT16 ")
        sign=MyBoot16->Signature
        FAT_LIMIT=&hFFF8
    else
    	FAT_TYPE=32
    	ConsoleWrite(@" FAT32 ")
    	sign=MyBoot32->Signature
    	FAT_LIMIT=&h0FFFFFF8
    end if
    
    if (sign <> &h29 and sign <> &h0) then
        PFree(myboot)
        ConsoleSetForeground(12)
        ConsoleWriteLine(@" Signature invalid")
        ConsoleSetForeground(7)
        return 0
    end if
    ConsolePrintOK()
    ConsoleNewLine()
    
    reserved_sectors = myboot->reserved_sectors
    root_dir_count = myboot->root_dir_ent
    bytes_per_sector=myboot->bps
    sector_per_cluster=myboot->spc
    fat_count = myboot->fat_count
    
    FAT_DirectoryBuffer = PAlloc(65536 shr 12)
    if (FAT_TYPE<>32) then
        root_dir_sectors = (((myboot->root_dir_ent * 32) + (myboot->bps - 1)) / myboot->bps)
        fat_sectors = (fat_count * myboot->spf)
        root_cluster=0
    else
        root_dir_sectors = 0
        fat_sectors = (fat_count * myboot32->spf)
        root_cluster=myboot32->root_cluster
    end if
    
    data_sectors        = sector_count - (myboot->reserved_sectors + fat_sectors + root_dir_sectors)
    total_clusters      = data_sectors \ sector_per_cluster
    first_data_sector   = reserved_sectors + fat_sectors + root_dir_sectors
    first_fat_sector    = reserved_sectors
    PFree(myboot)

    var ftable_size = bytes_per_sector * fat_sectors*2
    var ftable_pages = (ftable_size shr 12)
    if (ftable_pages shl 12) < ftable_size then ftable_pages+=1
    fat_table = PAlloc(ftable_pages)
    
    DEVICE.READ(first_fat_sector,fat_sectors,fat_table)
    
    fat_dirty=0
    
    return 1
end function

function FATFS_Absolute_sector(cluster as unsigned integer) as unsigned integer
	return ((cluster-2) * sector_per_cluster)  + first_data_sector
end function


function  FATFS_find_fatentry(N as unsigned integer) as unsigned integer
	dim table_value16 as unsigned short
	dim table_value32 as unsigned integer
	dim table_value as unsigned integer
	dim cluster_size as unsigned integer=bytes_per_sector
	dim fatoffset as unsigned integer
	dim fatentoffset as unsigned integer

	if (fat_type = 12) then fatoffset = N + (N shr 1)
	if (fat_type = 16) then fatoffset = N shl 1
	if (fat_type = 32) then fatoffset = N shl 2
	
	fatentoffset = fatoffset

	
	
	if (Fat_Type<>32) then
		table_value16 = *cptr(unsigned short ptr, @fat_table[fatentoffset])
        'table_value16 = cptr(unsigned short ptr,fat_table)[N]' @fat_table[fatentoffset])
		if Fat_Type=12 then
			if ((N AND &h0001)=&h0001) then 
				table_value16 = table_value16 shr 4
			else 
				table_value16 = table_value16 AND &hfff
			end if
		end if
	else
		'table_value32 = *cptr(unsigned integer ptr, @fat_table[fatentoffset]) AND &h0fffffff
        
        table_value32 = cptr(unsigned integer ptr,fat_table)[N]' @fat_table[fatentoffset])
	end if

	if (fat_type<>32) then
		return table_value16
	else
		return table_value32
	end if
end function

sub FATFS_READ_ROOT(dst as FAT_ENTRY ptr)
    
    if (Fat_Type<>32) then
        DEVICE.READ((RESERVED_SECTORS+FAT_SECTORS),ROOT_DIR_SECTORS,cptr(unsigned byte ptr,dst))
	else
		FATFS_READ_CHAIN(root_cluster,cptr(byte ptr,dst))
	end if
end sub

sub FATFS_WRITE_ROOT(src as FAT_ENTRY ptr)
    if (Fat_Type<>32) then
        DEVICE.WRITE((RESERVED_SECTORS+FAT_SECTORS),ROOT_DIR_SECTORS,cptr(unsigned byte ptr,src))
	else
		FATFS_WRITE_CHAIN(root_cluster,cptr(byte ptr,src))
	end if
end sub

sub FATFS_READ_CHAIN(clusternum as unsigned integer, dst as unsigned byte ptr)
	dim nxt as unsigned integer
	dim buf as unsigned byte ptr
	
	if ((clusternum=0))  then
		FATFS_Read_ROOT(cptr(FAT_ENTRY ptr ,dst))
		exit sub
	end if
    
    nxt = clusternum
    buf=dst 
    while(nxt<Fat_limit)
        if (FAT_TYPE=32) then
            DEVICE.READ((FATFS_Absolute_sector(nxt)),sector_per_cluster,buf)
        else
            DEVICE.READ((FATFS_Absolute_sector(nxt)-1),sector_per_cluster,buf)
        end if
        nxt	= FATFS_find_fatentry(nxt)
        buf +=(sector_per_cluster*bytes_per_sector)
    wend
end sub

function FATFS_READ_NEXT_CLUSTER(clusternum as unsigned integer,dst as unsigned byte ptr) as unsigned integer
    if (clusternum<FAT_LIMIT) then
        if (FAT_TYPE=32) then
            DEVICE.READ((FATFS_Absolute_sector(clusternum)),sector_per_cluster,dst)
        else
            DEVICE.READ((FATFS_Absolute_sector(clusternum)-1),sector_per_cluster,dst)
        end if
        
        var nxt =  FATFS_find_fatentry(clusternum)
        if (nxt>=FAT_LIMIT) then return 0
        return nxt
    end if
    return 0
end function

sub FATFS_WRITE_CHAIN(clusternum as unsigned integer, src as unsigned byte ptr)
	dim nxt as unsigned integer
	dim buf as unsigned byte ptr
	
	if ((clusternum=0))  then
		FATFS_Write_ROOT(cptr(FAT_ENTRY ptr ,src))
		exit sub
	end if
    
    nxt = clusternum
    buf=src 
    while(nxt<fat_limit)
        if (FAT_TYPE=32) then
            DEVICE.WRITE((FATFS_Absolute_sector(nxt)),sector_per_cluster,buf)
        else
            DEVICE.WRITE((FATFS_Absolute_sector(nxt)-1),sector_per_cluster,buf)
        end if
        nxt	= FATFS_find_fatentry(nxt)
        buf +=(sector_per_cluster*bytes_per_sector)
    wend
end sub


function FATFS_find(fname as unsigned byte ptr,attrib as unsigned byte ,repertoire as FAT_ENTRY ptr) as unsigned integer
	dim cara as unsigned byte
	dim cpt1 as unsigned integer,cpt2 as unsigned integer
	dim trouve as unsigned integer,ok as unsigned integer,isdir as unsigned integer

	isdir = 0
	if (attrib = &h10) then isdir=1

	trouve=0
	cara=repertoire[0].Entry_Name(0)
	
	
	
	cpt1=0
	while (cpt1<255) and (trouve=0)
		ok=0
		if (isdir=1) then
			if( ((repertoire[cpt1].attrib AND &h10)<>0) AND (cara<>&he5) AND ((repertoire[cpt1].attrib AND &hf) <>&hf) AND (repertoire[cpt1].attrib <> &h0)) then ok = 1
		else
			if( ((repertoire[cpt1].attrib AND &h10)=0) AND (cara<>&he5) AND ((repertoire[cpt1].attrib and &hF) <>&hf)) then ok = 1
		end if
		
		if (ok=1) then
            trouve=1
			for cpt2=0 to 10 
				if (fname[cpt2]<>repertoire[cpt1].Entry_Name(cpt2)) then trouve=0
			next
				
			if (trouve=1) then 
                exit while
            end if
		end if
		cara=repertoire[cpt1+1].Entry_Name(0)
		cpt1+=1
	wend
	
	suiteb:
	if (trouve=1) then
		return cpt1+1
	else
		return 0
	end if
end function


function FATFS_Find_entry(fichier as byte ptr,first_cluster as unsigned integer,entnum as unsigned integer ptr,cnum as unsigned integer ptr,fsize as unsigned integer ptr,entrytype as unsigned byte) as unsigned integer
	dim clusternum as unsigned integer, entrynum as unsigned integer
	dim filename as unsigned byte ptr,nextchaine as unsigned byte ptr
	dim fname(0 to 29) as unsigned byte
	dim cpt as unsigned integer,trouve as integer,clusternum2 as unsigned integer
	dim newrep as FAT_ENTRY ptr
	
    if (fichier=0) then return root_cluster
	'//cas 1)  we dont specify anything so it's the root cluster
	if fichier[0]=0 then return root_cluster
	
	'//cas 2), we specify only the root folder
	if (fichier[0]=47) and (fichier[1]=0) then return root_cluster

	'//cas 3) on recherche dans current folder
	if (fichier[0]<>47) then 
		clusternum      = first_cluster 	';//le cluster de depart est donc le cluster courrant
		filename        = fichier 			';//le nom du fichier est celui specifie
	'//cas 4 we look in the root folder
	else			
		clusternum  =   root_cluster		';//le cluster de depart est donc le cluster courrant
		filename    =   fichier+1
	end if

	
	
	'//par defaut on considère  qu'il n'y a pas de repertoire suivant
	nextchaine=0
	cpt = 0
	while (filename[0]<>0) and (nextchaine=0) and (cpt<=12)
		if (filename[cpt]=47) then 		'"/"
			filename[cpt]=0			 	';//on isole le nom du repertoire
			nextchaine=filename+cpt+1	';//on definis le repertoire suivant
		end if
		cpt+=1
	wend
	
	
	str2fat(filename,@fname(0))					        ';//on converi le nom de repertoire en nom valide
    
    newrep=cptr(FAT_ENTRY ptr,FAT_DirectoryBuffer)		';//(sector_per_cluster*bytes_per_sector*4);
	FATFS_READ_CHAIN(clusternum,cptr(byte ptr,newrep))	';//on charge le cluster
    
	'//:s'il n'y a pas de prochaine chaine, on recherche un fichier
	if (nextchaine = 0) then
		trouve=FATFS_find(@fname(0),entrytype,newrep)		';//on cherche l'entree
		if (trouve) then
			clusternum2=((newrep[trouve-1].clusternum_high shl 16) AND &hFFFF0000) + ((newrep[trouve-1].clusternum_low) AND &h0000FFFF)
			*entnum=trouve-1
			*cnum  = clusternum
			*fsize = newrep[trouve-1].size
			return clusternum2
		else
			return 0
		end if
	'//sinon on recher d'abord un repertoire pour trouver le fichier dedans
	else
		trouve=FATFS_find(@fname(0),&h10,newrep)
		if (trouve>0) then
			clusternum2=((newrep[trouve-1].clusternum_high shl 16) AND &hFFFF0000) + ((newrep[trouve-1].clusternum_low) AND &h0000FFFF)
			return FATFS_Find_entry(nextchaine,clusternum2,entnum,cnum,fsize,entrytype)
		else
			return 0
		END IF
	end if
	return 0
end function



function FATFS_Find_Free_Cluster() as unsigned integer
    dim cpt as unsigned integer
    dim retval as unsigned integer
	retval=0

    cpt=2
    while (cpt<=total_clusters) and (retval=0)
        if (FATFS_find_fatentry(cpt)=0) then return cpt
        cpt+=1
    wend
    return 0
end function

sub FATFS_Set_Cluster(N as unsigned integer, value as unsigned integer)
    dim table_value_16 as unsigned short
    dim aecrire as unsigned short
	dim table_value_32 as unsigned integer
    dim table_value as unsigned integer
	dim cluster_size as unsigned integer=bytes_per_sector
    dim fatoffset as unsigned integer
    dim fatsecnum as unsigned integer
    dim fatentoffset as unsigned integer
    dim fatoffset2 as unsigned integer
    if (N>=total_clusters) then return

	if (fat_type = 12) then fatoffset = N + (N shr 1)   '/2
	if (fat_type = 16) then fatoffset = N shl 1         '*2
	if (fat_type = 32) then fatoffset = N shl 2         '*4
	
	fatentoffset = fatoffset ';//fatoffset % cluster_size;
	fatoffset2 = fatoffset+((fat_sectors/fat_count)*bytes_per_sector)

	if (fat_type=32) then
        *cptr(unsigned integer ptr,@fat_table[fatentoffset])=value
		*cptr(unsigned integer ptr,@fat_table[fatoffset2])=value
		'*(unsigned int *)&fat_table[fatoffset2]=value;//writing value in the 2nd fat
    elseif (fat_type=16)  then
        *cptr(unsigned short ptr,@fat_table[fatentoffset])=value and &hFFFF
		*cptr(unsigned short ptr,@fat_table[fatoffset2])=value and &hFFFF
        
		'*(unsigned short *)&fat_table[fatentoffset]=value&0xffff;
		'*(unsigned short *)&fat_table[fatoffset2]  =value&0xffff; //writing value in the 2nd fat
    elseif (fat_type=12) then
    
		table_value_16 =*(cptr(unsigned short ptr,@fat_table[fatentoffset]))
		if ((N and &h0001)=&h0001) then 
            aecrire= ((table_value_16 and &h000f) or ((value  and &h0fff) shl 4))
		else            
            aecrire= ((table_value_16 and &hf000) or (value  and &h0fff))
        end if
        *cptr(unsigned short ptr,@fat_table[fatentoffset])=aecrire
		*cptr(unsigned short ptr,@fat_table[fatoffset2])=aecrire
	end if
	fat_dirty=1
end sub

function FATFS_Alloc_Cluster() as unsigned integer
    dim tomark as unsigned integer
    dim value as unsigned integer
	
	'//printf("Recherche de %u cluster\n",count);
	tomark=FATFS_find_free_cluster()
	if (tomark<>0) then
		FATFS_set_cluster(tomark,fat_limit)
        return tomark
	end if
	return 0
end function

sub FATFS_FREE_CLUSTER(n as unsigned integer)
   var nextCluster = n
   while  (nextCluster<>0 and nextCluster<>FAT_LIMIT)
        FATFS_set_cluster(nextCluster,0)
        nextCluster = FATFS_find_fatentry(nextCluster)
   wend
end sub


function FAT2STR(str1 as unsigned byte ptr,buffer as unsigned byte ptr) as unsigned byte ptr
    dim cpt1 as unsigned integer=0
    dim cpt2 as unsigned integer=0
    dim dotAdded as unsigned integer=0
    for cpt1=0 to 7
        if (str1[cpt1]<>32) then
            buffer[cpt2]=str1[cpt1]
        else
            exit for
        end if
        cpt2+=1
    next cpt1
    
    for cpt1=8 to 10
        if (str1[cpt1]<>32) then
            if (dotAdded=0) then
                buffer[cpt2]=46
                cpt2+=1
                dotAdded=1
            end if
            buffer[cpt2]=str1[cpt1]
        else
            exit for
        end if
        cpt2+=1
    next cpt1
    buffer[cpt2]=0
    return buffer
end function

function STR2FAT(texte as unsigned byte ptr,buffer as unsigned byte ptr) as integer
	dim cpt as integer,cpt2 as integer
	dim cara as unsigned byte

	for cpt=0 to 10 
		buffer[cpt]=&h20
	next
	if (texte[0]= &h20) then return 0
	if (texte[0]= &h0) then return 0
	if (texte[0]= &h2e) then ' "."
		if (texte[1]<>&h2e) then
			if (texte[1]<>&h0) then return 0
			buffer[0]=&h2e
			return -1
		end if
		if (texte[2]<>0) and (texte[2]<>&h47) then return 0
		buffer[0]=&h2e
		buffer[1]=&h2e
		return -1
	end if
    
	cpt=0
	while (cpt<11) and (texte[cpt]<>0)
		cara=texte[cpt]
		if (cara=&h2e) then
			cpt2=cpt
			while (cpt2<11) and (texte[cpt2]<>0)
                cara=texte[cpt2+1]
                if ((cara>=97) and (cara<=122)) then cara -= 32
				buffer[8+(cpt2-cpt)]=cara
				cpt2+=1
			wend
			exit while
		end if
		if ((cara>=97) and (cara<=122)) then cara -= 32
		buffer[cpt]=cara
		cpt+=1
	wend
	return -1
end function

function GET_FILENAME(path as unsigned byte ptr) as unsigned byte ptr
    var l = strlen(path)
    if (l>0) then
        for i as integer = l-1 to 0 step -1
            if (path[i] = asc("/")) then
                return path+i+1
            end if
        next i
    end if
    return path
end function


function GET_PARENTPATH(path as unsigned byte ptr) as unsigned byte ptr
    dim tmpPath as unsigned byte ptr = MAlloc(strlen(path)+1)
    strcpy(tmpPath,path)
    StrToUpperFix(tmpPath)
    var l = strlen(tmpPath)
    if (l>0) then
        for i as integer = l-1 to 0 step -1
            if (tmpPath[i] = asc("/")) then
                tmpPath[i] = 0
                return tmpPath
            end if
        next i
    end if
    Free(tmpPath)
    return 0
end function

function FATFS_OPEN(path as unsigned byte ptr,mode as unsigned integer) as unsigned integer
    select case mode
        case 1'read
            return FATFS_OPENREAD(path)
        case 2'create
            return FATFS_OPENWRITE(path,0)
        case 3' append
            return FATFS_OPENWRITE(path,1)
        case 4'random
            return FATFS_OPENWRITE(path,2)
    end select
    return 0
end function

function FATFS_OPENREAD(path as unsigned byte ptr) as unsigned integer
    
    dim tmpPath as unsigned byte ptr = MAlloc(strlen(path)+1)
    strcpy(tmpPath,path)
    StrToUpperFix(tmpPath)
    var fileName    = GET_FILENAME(tmpPath)
    
    dim clusternum as unsigned integer,cnum as unsigned integer,entnum as unsigned integer
	dim nbrclust as unsigned integer
	dim buffer as unsigned byte ptr
    dim fsize as unsigned integer
	dim cpt as unsigned integer
	dim newrep as FAT_ENTRY ptr
    
    clusternum=FATFS_Find_entry(tmpPath,root_cluster,@entnum,@cnum,@fsize,&h20)
    dim descr as FATFS_FILE ptr = 0
    if (clusternum<>0) then
        'CONSOLE_WRITE(@"PARENT DIR LOCATED AT CLUSTER : "):CONSOLE_WRITE_NUMBER(cnum,10):CONSOLE_NEW_LINE()
        'CONSOLE_WRITE(@"FILE LOCATED AT CLUSTER : "):CONSOLE_WRITE_NUMBER(clusternum,10):CONSOLE_NEW_LINE()
        'CONSOLE_WRITE(@"FILE SIZE : "):CONSOLE_WRITE_NUMBER(fsize,10):CONSOLE_NEW_LINE()
        'CONSOLE_WRITE(@"FILE PATH : "):CONSOLE_WRITE_LINE(tmpPath)
        
        descr = MAlloc(sizeof(FATFS_FILE))
        descr->MAGIC                = FATFS_MAGIC
        descr->WRITEABLE            = 0
        descr->TRUNCATE             = 0
        descr->DIRECTORY_CLUSTER    = cnum
        descr->FILE_CLUSTER         = clusternum
        descr->DIRTY                = 0
        descr->CURRENT_CLUSTER      = 0
        descr->NEXT_CLUSTER         = 0
        descr->FPOS                 = 0
        descr->FPOS_IN_CLUSTER      = 0
        descr->FSIZE                = fsize
        str2FAT(filename,@descr->FAT_FILENAME(0))
        
        descr->END_OF_FILE          = 0
        descr->CLUSTER_SIZE         = sector_per_cluster*bytes_per_sector
        descr->CLUSTER_PAGES        = descr->CLUSTER_SIZE shr 12
        if (descr->CLUSTER_PAGES shl 12) < descr->CLUSTER_SIZE then descr->CLUSTER_PAGES+=1
        descr->CLUSTER              = PAlloc(descr->CLUSTER_PAGES)
    end if
    Free(tmpPath)
    return cuint(descr)
end function


function FATFS_OPENWRITE(path as unsigned byte ptr,appendMode as unsigned integer) as unsigned integer
    dim tmpPath as unsigned byte ptr = MAlloc(strlen(path)+1)
    strcpy(tmpPath,path)
    StrToUpperFix(tmpPath)
    var parentPATH = GET_PARENTPATH(tmpPath)
    var fileName = GET_FILENAME(tmpPath)
    
    dim clusternum as unsigned integer,cnum as unsigned integer,entnum as unsigned integer
	dim nbrclust as unsigned integer
	dim buffer as unsigned byte ptr
    dim fsize as unsigned integer
	dim cpt as unsigned integer
	dim newrep as FAT_ENTRY ptr
    dim clusternumParentDir as unsigned integer
    clusternum=FATFS_find_entry(tmpPath,root_cluster,@entnum,@cnum,@fsize,&h20)
    dim descr as FATFS_FILE ptr = 0
    
    if (clusternum<>0) then
        clusternumParentDir = cnum
        'free the existing clusters if we overwrite the existing files
        if (appendMode=0) then
            FATFS_FREE_CLUSTER(clusternum)
        end if
    else
        if (parentPath<>0) then
            clusternumParentDir = FATFS_find_entry(parentPATH,root_cluster,@entnum,@cnum,@fsize,&h10)
        else
            clusternumParentDir = 0
        end if
    end if
    
    if (clusternumParentDir<>0) or (parentPath=0)  then
        descr = MAlloc(sizeof(FATFS_FILE))
        descr->MAGIC                = FATFS_MAGIC
        descr->WRITEABLE            = 1
        descr->TRUNCATE             = iif(appendMode=0,1,0)
        descr->DIRTY                = 0
        descr->DIRECTORY_CLUSTER    = clusternumParentDir
        descr->FILE_CLUSTER         = iif(appendMode=0,0,clusterNum)'set here to cluster num  if we keep data (apped mode)
        descr->CURRENT_CLUSTER      = 0
        descr->NEXT_CLUSTER         = 0
        descr->FPOS                 = 0
        descr->FPOS_IN_CLUSTER      = 0
        descr->FSIZE                = iif(appendMode=0,0,fsize)
        str2FAT(filename,@descr->FAT_FILENAME(0))
        
        descr->END_OF_FILE          = 0
        descr->CLUSTER_SIZE         = sector_per_cluster*bytes_per_sector
        descr->CLUSTER_PAGES        = descr->CLUSTER_SIZE shr 12
        if (descr->CLUSTER_PAGES shl 12) < descr->CLUSTER_SIZE then descr->CLUSTER_PAGES+=1
        descr->CLUSTER              = PAlloc(descr->CLUSTER_PAGES)
        memset(descr->CLUSTER,0,descr->CLUSTER_SIZE)
        
        
         'seek to the end if append mode
        if (appendMode=1) and (descr->FILE_CLUSTER<>0) then
            descr->NEXT_CLUSTER = descr->FILE_CLUSTER
            do
                descr->LOAD_CLUSTER()
            loop until (descr->NEXT_CLUSTER  = 0) or (descr->NEXT_CLUSTER = FAT_LIMIT)
            
            descr->FPOS = descr->FSIZE
            descr->FPOS_IN_CLUSTER = descr->FSIZE mod descr->CLUSTER_SIZE
        end if
    else
        ConsoleWrite(@"DIRECTORY NOT FOUND : "):ConsoleWriteLine(parentPATH)
    end if
    if (parentPath<>0) then Free(parentPATH)
    Free(tmpPath)
    return cuint(descr)
end function


function FATFS_ListDir(path as unsigned byte ptr,entrytype as unsigned integer,dst as VFSDirectoryEntry ptr,skip as unsigned integer,entryCount as unsigned integer) as unsigned integer
    dim nbuffer(0 to 32) as unsigned byte
    dim clusternum as unsigned integer,cnum as unsigned integer,entnum as unsigned integer,count as unsigned integer
    
    var slen=strlen(path)
    dim isroot as unsigned integer = 0
    if (slen = 0) or ((slen=1) and (path[0]=asc("/"))) then isroot = 1
    
    if (slen<>0) then
        ConsoleWrite(@"PATH : "):ConsoleWriteLIne(path)
    end if
    
    if (isroot=1) then
        clusternum=root_cluster
    else
        clusternum= FATFS_find_entry(path,root_cluster,@entnum,@cnum,@count,&h10)
    end if
    if (clusternum<>0) or (clusternum=root_cluster and isroot) then
        
        dim buffer as unsigned byte ptr
        dim cpt as unsigned integer
        
        
		var newrep=cptr(FAT_ENTRY ptr,FAT_DirectoryBuffer)'//(bytes_per_sector*sector_per_cluster*4);
        FATFS_READ_CHAIN(clusternum,cptr(unsigned byte ptr,newrep))
        FATFS_READ_CHAIN(clusternum,cptr(unsigned byte ptr,newrep))
        
        dim retval as unsigned integer = 0
        cpt=0
        dim nbr as unsigned integer =(bytes_per_sector*sector_per_cluster)\sizeof(FAT_ENTRY)
        while (cpt <  nbr) 
            
            if (newrep[cpt].entry_name(0)<>0) and (newrep[cpt].entry_name(0)<>&he5) and (newrep[cpt].attrib<>0)  then
                
                    if ((newrep[cpt].attrib=&h10) and (entrytype=1 or entrytype=0)) then
                        if (retval>=skip and retval<skip+entryCount) then
                            memset(@(dst[retval-skip].FileName(0)),0,256)
                            FAT2STR(@newrep[cpt].entry_name(0),@(dst[retval-skip].FileName(0)))
                            dst[retval-skip].Size=0
                            dst[retval-skip].EntryType=1
                        end if
                        retval+=1
                    end if
                    if ((newrep[cpt].attrib=&h20) and (entrytype=2 or entrytype=0)) then
                        if (retval>=skip and retval<skip+entryCount) then
                            
                            memset(@(dst[retval-skip].FileName(0)),0,256)
                            FAT2STR(@newrep[cpt].entry_name(0),@(dst[retval-skip].FileName(0)))
                            
                            dst[retval-skip].Size=newrep[cpt].size
                            dst[retval-skip].EntryType=2
                        end if
                        retval+=1
                    end if
                    
            end if
            
            cpt+=1
        wend
        return retval
    else
        ConsoleWriteLine(@"error FATFS_Find_entry result was 0")
    end if
    return 0
end function