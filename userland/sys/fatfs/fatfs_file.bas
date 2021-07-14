function FATFS_FILE.WRITE(count as unsigned integer,src as unsigned byte ptr) as unsigned integer
    dim i as unsigned integer
    while i<count
        CLUSTER[FPOS_IN_CLUSTER]=src[i]
        FPOS            += 1
        FPOS_IN_CLUSTER += 1
        if (FSIZE<FPOS) then
            FSIZE           = FPOS
        end if
        
        if (FPOS_IN_CLUSTER>=CLUSTER_SIZE) then
            WRITE_CLUSTER()
        end if
        i+=1
    wend
    DIRTY           = 1
    RETURN COUNT
end function

function FATFS_FILE.READ(count as unsigned integer,dest as unsigned byte ptr) as unsigned integer
    dim cpt as unsigned integer = count
    if (FPOS+count>FSIZE) then cpt = FSIZE-FPOS
    
    
    'load first sector if needed
    if (CURRENT_CLUSTER = 0) then
        NEXT_CLUSTER = FILE_CLUSTER
        LOAD_CLUSTER()
    end if
    if (END_OF_FILE<>0) then return 0
    
    dim i as unsigned integer
    while i<cpt
        dest[i] = CLUSTER[FPOS_IN_CLUSTER]
        FPOS            += 1
        FPOS_IN_CLUSTER += 1
        
        if (FPOS>=FSIZE) then
            END_OF_FILE = 1
            return i+1
        end if
        
        if (FPOS_IN_CLUSTER>=CLUSTER_SIZE) then
            LOAD_CLUSTER()
        end if
        
        if (END_OF_FILE<>0) then return i+1
        
        i+=1
    wend
    return cpt
end function

sub FATFS_FILE.LOAD_CLUSTER()
    this.CURRENT_CLUSTER = this.NEXT_CLUSTER
    if (this.CURRENT_CLUSTER    = 0) then
        this.END_OF_FILE        = 1
        this.NEXT_CLUSTER       = 0
        this.FPOS_IN_CLUSTER    = 0
        exit sub
    end if
    this.NEXT_CLUSTER = FATFS_READ_NEXT_CLUSTER(this.CURRENT_CLUSTER,this.CLUSTER)
    this.FPOS_IN_CLUSTER = 0
end sub

sub FATFS_FILE.WRITE_CLUSTER()
    if (this.CURRENT_CLUSTER = 0) then
        'allocate a cluster
        this.FILE_CLUSTER = FATFS_Alloc_Cluster()
        this.CURRENT_CLUSTER = this.FILE_CLUSTER
        this.NEXT_CLUSTER = 0
    end if
    
    'write the current cluster
    if (FAT_TYPE=32) then
        DEVICE.WRITE((FATFS_Absolute_sector(this.CURRENT_CLUSTER)),sector_per_cluster,this.CLUSTER)
        DEVICE.WRITE((FATFS_Absolute_sector(this.CURRENT_CLUSTER)),sector_per_cluster,this.CLUSTER)
    else
        DEVICE.WRITE((FATFS_Absolute_sector(this.CURRENT_CLUSTER)-1),sector_per_cluster,this.CLUSTER)
        DEVICE.WRITE((FATFS_Absolute_sector(this.CURRENT_CLUSTER)-1),sector_per_cluster,this.CLUSTER)
    end if

    memset(this.CLUSTER,0,this.CLUSTER_SIZE)
    if (this.NEXT_CLUSTER<>0) then
        this.LOAD_CLUSTER()
    else
        this.NEXT_CLUSTER = FATFS_ALLOC_CLUSTER()
        FATFS_Set_Cluster(this.CURRENT_CLUSTER,this.NEXT_CLUSTER)
        this.CURRENT_CLUSTER = this.NEXT_CLUSTER
        this.NEXT_CLUSTER = 0
    end if
    
    this.FPOS_IN_CLUSTER = 0
end sub

sub FATFS_FILE.CLOSE()
    
    if (DIRTY=1) then
        
        'load the directory
        dim rep as FAT_ENTRY ptr =cptr(FAT_ENTRY ptr,FAT_DirectoryBuffer)		';//(sector_per_cluster*bytes_per_sector*4);
        FATFS_READ_CHAIN(DIRECTORY_CLUSTER,cptr(byte ptr,rep))
        
        'search for the existing entry num
        var entryNum = FATFS_find(@FAT_FILENAME(0),&h20,rep)
        if (entryNum = 0) then
            dim nbrEntry as unsigned integer = 65536 \ sizeof(FAT_ENTRY)
            'if not found, search for a free entry
            for i as unsigned integer = 0 to nbrEntry-2
                if (rep[i].entry_name(0)=&h00) then 
                    rep[i+1].entry_name(0)=&h0
                    entryNum = i+1
                    exit for
                elseif (rep[i].entry_name(0)=&he5) then
                    entryNum = i+1
                    exit for
                elseif ((rep[i].attrib and &hf)=&hf) then
                    entryNum = i+1
                    exit for
                end if
            next
        end if
        
        if (entryNum<>0) then
            entryNum-=1
            if (CURRENT_CLUSTER = 0) then
                'allocate a cluster
                FILE_CLUSTER    = FATFS_Alloc_Cluster()
                CURRENT_CLUSTER = FILE_CLUSTER
                NEXT_CLUSTER    = 0
            'elseif (descriptor->NEXT_CLUSTER <> 0) and (descriptor->TRUNCATE=1) then 'truncate
            '    descriptor->FS->FREE_CLUSTER(descriptor->NEXT_CLUSTER)
            '    descriptor->FS->SET_CLUSTER(descriptor->CURRENT_CLUSTER,descriptor->FS->FAT_LIMIT)
            end if
            
            'write the fat
            DEVICE.WRITE(FIRST_FAT_SECTOR,fat_sectors,FAT_TABLE)
            
            if (TRUNCATE=1) then
            for i as unsigned integer = FPOS_IN_CLUSTER to CLUSTER_SIZE-1
                CLUSTER[i]=0
            next i
            end if
                
            
            'write the current cluster
            if (FAT_TYPE=32) then
                DEVICE.WRITE((FATFS_Absolute_sector(CURRENT_CLUSTER)),sector_per_cluster,CLUSTER)
                DEVICE.WRITE((FATFS_Absolute_sector(CURRENT_CLUSTER)),sector_per_cluster,CLUSTER)
            else
                DEVICE.WRITE((FATFS_Absolute_sector(CURRENT_CLUSTER)-1),sector_per_cluster,CLUSTER)
                DEVICE.WRITE((FATFS_Absolute_sector(CURRENT_CLUSTER)-1),sector_per_cluster,CLUSTER)
            end if
            
            memcpy(@rep[entryNum].entry_name(0),@FAT_FILENAME(0),11)
            
            rep[entryNum].clusternum_high=cast(unsigned short,((FILE_CLUSTER  and &hffff0000) shr 16))
            rep[entryNum].clusternum_low =cast(unsigned short,(FILE_CLUSTER and &hffff))
            rep[entryNum].attrib=&h20
            rep[entryNum].size=FSIZE
            
            'write the directory
            FATFS_WRITE_CHAIN(DIRECTORY_CLUSTER,cptr(byte ptr,rep))
            
        else
            ConsoleSetForeground(12)
            ConsoleWrite(@"CANNOT FIND FREE ENTRY")
            ConsoleSetForeground(7)
            ConsoleNewLine()
        end if
    end if
    
    PFree(CLUSTER)
end sub