
type FAT_BOOTSECTOR FIELD=1
	JMPCODE(0 to 2) as unsigned byte
	OEM_NAME(0 to 7) as unsigned byte
	BPS as unsigned short
	SPC as unsigned byte
	reserved_sectors as unsigned short
	fat_count as unsigned byte
	root_dir_ent as unsigned short
	sectors_count as unsigned short
	media_descriptor as unsigned byte
	spf as unsigned short
	spt as unsigned short
	heads as unsigned short
	hidden as unsigned integer
	sectors_count2 as unsigned integer
end TYPE

type BS16 FIELD=1
	drive_num as unsigned byte
	reserved as unsigned byte
	signature as unsigned byte
	serial_num as unsigned integer
	volume_name(0 to 10) as unsigned byte
	fs_type(0 to 7) as unsigned byte
end type

type BS32 FIELD=1
	spf as unsigned integer
	mirror_flags as unsigned short
	fs_version as unsigned short
	root_cluster as unsigned integer
	fs_info as unsigned short
	backup_boot_sector as unsigned short
	reserved(0 to 11) as unsigned byte
	drive_num as unsigned byte
	reserved2 as unsigned byte
	signature as unsigned byte
	serial_num as unsigned integer
	volume_name(0 to 10) as unsigned byte
	fs_type(0 to 7) as unsigned byte
end type

type FAT_ENTRY FIELD=1
	Entry_Name(0 to 7) as unsigned byte
	ext(0 to 2) as unsigned byte
	attrib as unsigned byte
	reserved as unsigned byte
	creatime_sec as unsigned byte
	creatime as unsigned short
	creadate as unsigned short
	accessdate as unsigned short
	clusternum_high as unsigned short
	modiftime as unsigned short
	modifdate as unsigned short
	clusternum_low as unsigned short
	size as unsigned integer
end type


declare function FAT_DETECT() as unsigned integer
dim shared DEVICE               as BLOCK_DEVICE
dim shared SECTOR_COUNT         as unsigned integer
dim shared FAT_TYPE             as unsigned integer
dim shared FAT_LIMIT            as unsigned integer
dim shared reserved_sectors     as unsigned integer
dim shared root_dir_count       as unsigned integer
dim shared bytes_per_sector     as unsigned integer
dim shared sector_per_cluster   as unsigned integer
dim shared fat_count            as unsigned integer
dim shared FAT_DirectoryBuffer  as unsigned byte ptr
dim shared root_dir_sectors     as unsigned integer
dim shared fat_sectors          as unsigned integer
dim shared root_cluster         as unsigned integer
dim shared data_sectors         as unsigned integer
dim shared total_clusters       as unsigned integer
dim shared first_data_sector    as unsigned integer
dim shared first_fat_sector     as unsigned integer
dim shared fat_table            as unsigned byte ptr
dim shared fat_dirty            as unsigned integer

#define FATFS_MAGIC &h65493541

declare function FATFS_Absolute_sector(cluster as unsigned integer) as unsigned integer
declare function FATFS_find_fatentry(N as unsigned integer) as unsigned integer
declare sub FATFS_READ_ROOT(dst as FAT_ENTRY ptr)
declare sub FATFS_WRITE_ROOT(src as FAT_ENTRY ptr)
declare sub FATFS_READ_CHAIN(clusternum as unsigned integer, dst as unsigned byte ptr)
declare function FATFS_READ_NEXT_CLUSTER(clusternum as unsigned integer,dst as unsigned byte ptr) as unsigned integer
declare sub FATFS_WRITE_CHAIN(clusternum as unsigned integer, src as unsigned byte ptr)
declare function FATFS_find(fname as unsigned byte ptr,attrib as unsigned byte ,repertoire as FAT_ENTRY ptr) as unsigned integer
declare function FATFS_Find_entry(fichier as byte ptr,first_cluster as unsigned integer,entnum as unsigned integer ptr,cnum as unsigned integer ptr,fsize as unsigned integer ptr,entrytype as unsigned byte) as unsigned integer
declare function FATFS_Find_Free_Cluster() as unsigned integer
declare sub FATFS_Set_Cluster(N as unsigned integer, value as unsigned integer)
declare function FATFS_Alloc_Cluster() as unsigned integer
declare sub FATFS_FREE_CLUSTER(n as unsigned integer)

declare function FAT2STR(str1 as unsigned byte ptr,buffer as unsigned byte ptr) as unsigned byte ptr
declare function STR2FAT(texte as unsigned byte ptr,buffer as unsigned byte ptr) as integer
declare function GET_PARENTPATH(path as unsigned byte ptr) as unsigned byte ptr
declare function GET_FILENAME(path as unsigned byte ptr) as unsigned byte ptr
declare function FATFS_OPEN(path as unsigned byte ptr,mode as unsigned integer) as unsigned integer
declare function FATFS_OPENREAD(path as unsigned byte ptr) as unsigned integer
declare function FATFS_OPENWRITE(path as unsigned byte ptr,appendMode as unsigned integer) as unsigned integer
declare function FATFS_CLOSE(handle as unsigned integer,descr as any ptr) as unsigned integer
declare function FATFS_ListDir(path as unsigned byte ptr,entrytype as unsigned integer,dst as VFSDirectoryEntry ptr,skip as unsigned integer,entryCount as unsigned integer) as unsigned integer
