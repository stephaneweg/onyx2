#include once "stdlib.bi"
#include once "stdlib.bas"

#include once "system.bas"
#include once "console.bas"
#include once "devman.bas"

type IP_MESSAGE field = 1
	dst_addr(0 to 5) as unsigned byte
	src_addr(0 to 5) as unsigned byte
	proto as unsigned short
end type

type ARP_PAYLOAD field = 1
	HDR as unsigned short
	PRO as unsigned short
	HLN as unsigned byte
	PLN as unsigned byte
	OP as unsigned short
	SHA(0 to 5) as unsigned byte
	SPA as unsigned integer
	THA(0 to 5) as unsigned byte
	TPA as unsigned integer
end type

type ARP_MESSAGE field = 1
	HEADER as IP_MESSAGE
	PAYLOAD as ARP_PAYLOAD
end type


dim shared ETH_IPC as unsigned integer
dim shared ETH_HANDLE as unsigned integer
dim shared hwAddr(0 to 7) as unsigned byte

dim shared NET_IP		as unsigned integer
dim shared NET_MASK		as unsigned integer
dim shared NET_GATEWAY	as unsigned integer

declare sub ReadMacAddr()
declare sub SetupNet(_localIp as unsigned integer,_subnetMask as unsigned integer,_gatewayIp as unsigned integer)

declare function GetIP(i1 as unsigned byte,i2 as unsigned byte,i3 as unsigned byte,i4 as unsigned byte) as unsigned integer
declare sub PrintIP(ip as unsigned integer)
declare sub send_arp_request(_ip as unsigned integer)

sub MAIN(argc as unsigned integer,argv as unsigned byte ptr ptr) 
	ConsoleWriteLine(@"Network test")
	DEVMAN_BIND()
	ETH_IPC = 0
	ETH_HANDLE = DEVMAN_GET_DEVICE(2,@"NE2000",@ETH_IPC)
	ConsoleWrite(@"ETH Handle : ")
	COnsoleWriteNumber(ETH_Handle,10)
	ConsoleNewLine()
	ConsoleWrite(@"ETH IPC : ")
	COnsoleWriteNumber(ETH_IPC,10)
	ConsoleNewLine()
	
	
	
	
	ReadMacAddr()
	ConsoleWrite(@"ETH Mac addr : ")
	dim i as integer
	for i=0 to 5
		if (hwAddr(i)<16) then ConsoleWrite(@"0")
		ConsoleWriteNumber(hwAddr(i),16)
		if (i<5) then ConsoleWrite(@":")
	next
	ConsoleNewLine()
	
	SetupNet(_
		GetIP(10,0,2,16),_
		GetIP(255,255,0,0),_
		GetIP(10,0,2,2)_
	)
		
	send_arp_request(GetIP(192,168,0,7))
	Process_Exit()
	do:loop
end sub

sub SetupNet(_localIp as unsigned integer,_subnetMask as unsigned integer,_gatewayIp as unsigned integer)


	NET_IP 		= _localIp
	NET_MASK	= _subnetMask
	NET_GATEWAY	= _gatewayIp
	
	ConsoleWrite(@"inet addr : ")
	PrintIP(NET_IP)
	ConsoleNewLine()
	
	ConsoleWrite(@"subnet mask : ")
	PrintIP(NET_MASK)
	ConsoleNewLine()
	
	ConsoleWrite(@"Gateway inet addr : ")
	PrintIP(NET_GATEWAY)
	ConsoleNewLine()
end sub

sub ReadMacAddr()
	*cptr(unsigned integer ptr,@hwAddr(0)) = IPC_Send(ETH_IPC,3,0,0,0,0,0,0,0, cptr(unsigned integer ptr,@hwaddr(4)),0)
end sub

function GetIP(i1 as unsigned byte,i2 as unsigned byte,i3 as unsigned byte,i4 as unsigned byte) as unsigned integer
	dim ip as unsigned integer
	dim _i as unsigned byte ptr = cptr(unsigned byte ptr,@ip)
	_i[0] = i1
	_i[1] = i2
	_i[2] = i3
	_i[3] = i4
	return ip
end function

sub PrintIP(ip as unsigned integer)
	dim _i as unsigned byte ptr = cptr(unsigned byte ptr,@ip)
	dim cpt as integer
	for cpt = 0 to 3
		ConsoleWriteNumber(_i[cpt],10)
		if (cpt<3) then ConsoleWrite(@".")
	next
end sub


sub send_arp_request(_ip as unsigned integer)
	dim cpt as unsigned integer
	dim mymessage as ARP_MESSAGE
	ConsoleWrite(@"Sending arp request for ip : ")
	PrintIP(_ip)
	ConsoleNewLine()
	
	mymessage.payload.hdr	=	&h0100	';	//1 = ethernet card
	mymessage.payload.pro 	=	&h0608	';	//0x800 = ip
	mymessage.payload.hln 	=	&h06	';	//mac addr len
	mymessage.payload.pln	=	&h04	';	// ip addr len
	mymessage.payload.op	=	&h0100	';	// 100 = arp request
	
	memcpy(@mymessage.payload.sha(0),@hwAddr(0),6)	'; 	//put my mac addr here (for the arp request)
	memset(@mymessage.payload.tha(0),0,6)			'; //we dont know the host mac addr
	
	mymessage.payload.spa = NET_IP 					';//my ip addr
	mymessage.payload.tpa = _ip 					';//i want to know the ip from this addr


	'//build the header	
	memcpy(@mymessage.header.src_addr(0),@hwAddr(0),6)	'; 	//put my mac addr here (for the arp request)
	memset(@mymessage.header.dst_addr(0),&hff,6)		'; //we send it to all computer on the network
	mymessage.header.proto= &h0608						';//arp protocol

	'transmit
	dim result as unsigned integer = IPC_Send(ETH_IPC,1,0,sizeof(ARP_MESSAGE),0,cuint(@mymessage),0,0,0,0,0)
	ConsoleWrite(@"Transmit Result : ")
	ConsoleWriteNumber(result,10)
	COnsoleNewLine()
	'//some debug message______________________________________________
	'printf("My Mac is          : %x:%x:%x:%x:%x:%x\n",	mymessage.header.src_addr[0]&0xff,
	'							mymessage.header.src_addr[1]&0xff,
	'							mymessage.header.src_addr[2]&0xff,
	'							mymessage.header.src_addr[3]&0xff,
	'							mymessage.header.src_addr[4]&0xff,
	'							mymessage.header.src_addr[5]&0xff);
	'printf("Destination Mac is : %x:%x:%x:%x:%x:%x\n",	mymessage.header.dst_addr[0]&0xff,
	'							mymessage.header.dst_addr[1]&0xff,
	'							mymessage.header.dst_addr[2]&0xff,
	'							mymessage.header.dst_addr[3]&0xff,
	'							mymessage.header.dst_addr[4]&0xff,
	'							mymessage.header.dst_addr[5]&0xff);

	'printf("My ip is           : ");printip(&mymessage.data.spa);putchar(10);
	'printf("Ip i want to guess : ");printip(&mymessage.data.tpa);putchar(10);
	'printf("Size of packet : %d\n",sizeof (struct arp_message));

	'printf("Packet dump : \n");
	'for (cpt=0; cpt < sizeof(struct arp_message); cpt++)
	'{
	'	printf(" %x",((char *)&mymessage)[cpt]&0xff);
	'	if (!((cpt+1)%16)) putchar (10);
	'}
	'putchar(10);
	'//----------------------------------------------------------------------------------
	'eth_ioctl->ioctl(0x1,&mymessage,sizeof(struct arp_message));

	'//now i must wait for response (by pooling the buffer)
end sub
