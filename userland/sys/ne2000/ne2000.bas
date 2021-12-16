#include once "ne2000.bi"

sub ETH_IRQ_Thread_Loop(p as any ptr)
    IRQ_CREATE_HANDLER(ne.IRQ,@ETH_IRQ_Handler)
	ConsoleWriteLine(@"NE2000 - IRQ Thread started")
    Thread_Wait_For_Event()
	do:loop
end sub

sub ETH_IRQ_Handler()
	dim isr as unsigned byte
	dim b as unsigned byte
	dim _addr_P0_CR		as unsigned short = ne.nic_addr + NE_P0_CR
	dim _addr_P0_ISR	as unsigned short = ne.nic_addr + NE_P0_ISR
	
	ConsoleWriteLine(@"NE2000 - IRQ HANDLER")
	
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD2 | NE_CR_STA);
	b = NE_CR_RD2 or NE_CR_STA
	outb([_addr_P0_CR],[b])
	
	'// Loop until there are no pending interrupts
	inb([_addr_P0_ISR],[isr])
	while isr<>0
		ConsoleWriteLine(@"NE2000 - check event")
		' // Reset bits for interrupts being acknowledged
		'outportb(ne->nic_addr + NE_P0_ISR, isr);
		outb([_addr_P0_ISR], [isr])

		'// Packet received
		if ((isr and NE_ISR_PRX) = NE_ISR_PRX) then
			ConsoleWriteLine(@"NE2000 - new packet arrived")
			ne_receive()
			ne.prx=1
		end if

		'// Packet transamitted
		if ((isr and NE_ISR_PTX) = NE_ISR_PTX) then
			ConsoleWriteLine(@"NE2000 - packet transmitted")
			ne.ptx=1
		end if

		'// Remote DMA complete
		if ((isr and NE_ISR_RDC)  = NE_ISR_RDC) then
			ConsoleWriteLine(@"NE2000 - remote DMA complete")
			ne.rdc=1
		end if

		'// Select page 0
		'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD2 | NE_CR_STA);
		b = NE_CR_RD2 or NE_CR_STA
		outb([_addr_P0_CR],[b])
		
		inb([_addr_P0_ISR],[isr])
	wend

	ConsoleWriteLine(@"NE2000 - IRQ HANDLER END")
    Thread_IRQ_Handler_End()
end sub


function ne_setup(iobase as unsigned integer, irq as unsigned integer, membase as unsigned short,  memsize as unsigned short) as unsigned integer
	
	dim romdata(0 to 15) as unsigned byte
	dim i as unsigned integer
	dim char(0 to 19) as unsigned byte
	
	ne.IOBASE	= iobase
	ne.IRQ		= irq
	ne.MEMBASE	= membase
	ne.MEMSIZE	= memsize
	
	ne.NIC_ADDR	= iobase + NE_NOVELL_NIC_OFFSET
	ne.ASIC_ADDR= iobase + NE_NOVELL_ASIC_OFFSET

	ne.rx_page_start	= membase / NE_PAGE_SIZE
	ne.rx_page_stop		= ((membase + memsize)/NE_PAGE_SIZE) - (NE_TXBUF_SIZE * NE_TX_BUFERS)
	ne.next_pkt			= ne.rx_page_start+1
	ne.rx_ring_start 	= ne.rx_page_start * NE_PAGE_SIZE
	ne.rx_ring_end 		= ne.rx_page_stop * NE_PAGE_SIZE

  
	if (ne_probe()=0) then return 0

	'// Initialize network interface
	ne.ptx=0
	ne.rdc=0
	ne.prx=0
	dim _ptr as unsigned integer = cptr(unsigned integer,@eth_buffer_bytes(0))
	eth_buffer = cptr(buffer ptr,_ptr)
	eth_buffer->next_entry = cptr(buffer_header ptr,_ptr + sizeof(buffer))
	
	'// Install interrupt handler
	if (ETH_IRQ_THREAD=0) then
		ETH_IRQ_THREAD = Thread_Create(@ETH_IRQ_Thread_Loop)
	end if
  
	dim _addr_P0_CR		as unsigned short = ne.nic_addr 	+ NE_P0_CR
	dim _addr_P0_DCR	as unsigned short = ne.nic_addr 	+ NE_P0_DCR
	dim _addr_P0_RBCR0  as unsigned short = ne.nic_addr		+ NE_P0_RBCR0
	dim _addr_P0_RBCR1  as unsigned short = ne.nic_addr		+ NE_P0_RBCR1
	dim _addr_P0_PSTART as unsigned short = ne.nic_addr		+ NE_P0_PSTART
	dim _addr_P0_PSTOP	as unsigned short = ne.nic_addr		+ NE_P0_PSTOP
	dim _addr_P0_BNRY	as unsigned short = ne.nic_addr		+ NE_P0_BNRY
	dim _addr_P0_IMR	as unsigned short = ne.nic_addr 	+ NE_P0_IMR
	dim _addr_P0_RCR	as unsigned short = ne.nic_addr 	+ NE_P0_RCR
	dim _addr_P0_TCR	as unsigned short = ne.nic_addr 	+ NE_P0_TCR
	dim _addr_P0_ISR	as unsigned short = ne.nic_addr 	+ NE_P0_ISR
	
	dim _addr_P1_CURR	as unsigned short = ne.nic_addr + NE_P1_CURR
	dim _addr_P1_PAR0(0 to ETHER_ADDR_LEN-1) as unsigned short
	dim _addr_P1_MAR0(0 to 7) as unsigned short
	
	for i = 0 to ETHER_ADDR_LEN-1
		_addr_P1_PAR0(i) = ne.nic_addr + NE_P1_PAR0 + i
	next
	for i = 0 to 7
		_addr_P1_MAR0(i) = ne.nic_addr + NE_P1_MAR0 + i
	next i
	
	dim b as unsigned byte
	dim w as unsigned short
	
	'// Set page 0 registers, abort remote DMA, stop NIC
	'outportb(ne->nic_addr + NE_P0_CR,NE_CR_RD2 | NE_CR_STP );
	b = NE_CR_RD2 or NE_CR_STP
	outb([_addr_P0_CR],[b])
	

	'// Set FIFO threshold to 8, no auto-init remote DMA, byte order=80x86, word-wide DMA transfers
	'outportb(ne->nic_addr + NE_P0_DCR, NE_DCR_FT1 | NE_DCR_WTS | NE_DCR_LS);
	b = NE_DCR_FT1 or NE_DCR_WTS or NE_DCR_LS
	outb([_addr_P0_DCR],[b])
	
	'// Get Ethernet MAC address
	ne_readmem(0,@ne.hwaddr(0),ETHER_ADDR_LEN)
	ConsoleWrite(@"NE2000 - Found Mac addr : ")
	for i=0 to ETHER_ADDR_LEN-1
		if (ne.hwaddr(i)<16) then ConsoleWrite(@"0")
		ConsoleWriteNumber(ne.hwaddr(i),16)
		if (i<ETHER_ADDR_LEN-1) then ConsoleWrite(@":")
	next
	ne.padding(0) = 0
	ne.padding(1) = 0
	ConsoleNewLine()
  
	'// Set page 0 registers, abort remote DMA, stop NIC
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD2 | NE_CR_STP);
	b = NE_CR_RD2 or NE_CR_STP
	outb([_addr_P0_CR],[b])

	'// Clear remote byte count registers
	'outportb(ne->nic_addr + NE_P0_RBCR0, 0);
	'outportb(ne->nic_addr + NE_P0_RBCR1, 0);
	outb([_addr_P0_RBCR0],0)
	outb([_addr_P0_RBCR1],0)

	'// Initialize receiver (ring-buffer) page stop and boundry	
	'outportb(ne->nic_addr + NE_P0_PSTART, ne->rx_page_start);
	'outportb(ne->nic_addr + NE_P0_PSTOP, ne->rx_page_stop);
	'outportb(ne->nic_addr + NE_P0_BNRY, ne->rx_page_start);
	b =  ne.rx_page_start
	outb([_addr_P0_PSTART],[b])
	b =  ne.rx_page_stop
	outb([_addr_P0_PSTOP],[b])
	b =  ne.rx_page_start
	outb([_addr_P0_BNRY],[b])

	'// Enable the following interrupts: receive/transmit complete, receive/transmit error, 
	'// receiver overwrite and remote dma complete.
	'outportb(ne->nic_addr + NE_P0_IMR, NE_IMR_PRXE | NE_IMR_PTXE | NE_IMR_RXEE | NE_IMR_TXEE | NE_IMR_OVWE | NE_IMR_RDCE);
	b = NE_IMR_PRXE or NE_IMR_PTXE or NE_IMR_RXEE or NE_IMR_TXEE or NE_IMR_OVWE or NE_IMR_RDCE
	outb([_addr_P0_IMR],[b])
	
	'// Set page 1 registers
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_PAGE_1 | NE_CR_RD2 | NE_CR_STP);
	b = NE_CR_PAGE_1 or NE_CR_RD2 or NE_CR_STP
	outb([_addr_P0_CR],[b])
	
	'// Copy out our station address
	'for (i = 0; i < ETHER_ADDR_LEN; i++) outportb(ne->nic_addr + NE_P1_PAR0 + i, ne->hwaddr[i]);
	for i=0 to ETHER_ADDR_LEN-1
		b = ne.hwaddr(i)
		w = _addr_P1_PAR0(i)
		outb([w],[b])
	next

	'// Set current page pointer 
	'outportb(ne->nic_addr + NE_P1_CURR, ne->next_pkt);
	b=ne.next_pkt
	outb([_addr_P1_CURR],[b])
	
	'// Initialize multicast address hashing registers to not accept multicasts
	'for (i = 0; i < 8; i++) outportb(ne->nic_addr + NE_P1_MAR0 + i, 0);
	for i = 0 to 7
		w = _addr_P1_MAR0(i)
		outb([w],0)
	next

	'// Set page 0 registers
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD2 | NE_CR_STP);
	b = NE_CR_RD2 or NE_CR_STP
	outb([_addr_P0_CR],[b])

	'// Accept broadcast packets
	'outportb(ne->nic_addr + NE_P0_RCR, NE_RCR_AB);
	b = NE_RCR_AB
	outb([_addr_P0_RCR],[b])

	'// Take NIC out of loopback
	'outportb(ne->nic_addr + NE_P0_TCR, 0);
	outb([_addr_P0_TCR],0)

	'// Clear any pending interrupts
	'outportb(ne->nic_addr + NE_P0_ISR, 0xFF);
	outb([_addr_P0_ISR],&hFF)

	'// Start NIC
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD2 | NE_CR_STA);
	b = NE_CR_RD2 or NE_CR_STA
	outb([_addr_P0_CR],[b])

	'// Create packet device
	'config_ressource(&eth_ress,eth_alias,eth_ioctl);
	'add_ressource(&eth_ress);
	
	ConsoleWrite(@"NE2000 installed at I/O : 0x")
	ConsoleWriteNumber(iobase,16)
	ConsoleNewLine()
	
	return 1
end function

function ne_probe() as unsigned integer
	dim b as unsigned byte
	
	dim _addr_reset as unsigned short = ne.asic_addr 	+ NE_NOVELL_RESET
	dim _addr_P0_CR as unsigned short = ne.nic_addr 	+ NE_P0_CR
	dim _addr_P0_ISR as unsigned short = ne.nic_addr 	+ NE_P0_ISR
	
	'reset
	inb([_addr_reset],[b])
	outb([_addr_reset],[b])
	b = NE_CR_RD2 or NE_CR_STP
	outb([_addr_P0_CR],[b])

	'sleep 5 milli seconds
	Thread_Sleep(5)

	'// Test for a generic DP8390 NIC
	inb([_addr_P0_CR],[b])
	b = b and (NE_CR_RD2 or NE_CR_TXP or NE_CR_STA or NE_CR_STP)
	if (b <> (NE_CR_RD2 or NE_CR_STP)) then return 0
  
	inb([_addr_P0_ISR],[b])
	b = b and NE_ISR_RST
	if (b <> NE_ISR_RST) then return 0
	return 1
end function

sub ne_readmem(_src as unsigned short,dst as unsigned byte ptr,_len as unsigned short)

	dim _addr_NE_P0_CR		as unsigned short = ne.nic_addr + NE_P0_CR
	dim _addr_NE_P0_RBCR0	as unsigned short = ne.nic_addr + NE_P0_RBCR0
	dim _addr_NE_P0_RBCR1	as unsigned short = ne.nic_addr + NE_P0_RBCR1
	dim _addr_NE_P0_RSAR0	as unsigned short = ne.nic_addr + NE_P0_RSAR0
	dim _addr_NE_P0_RSAR1	as unsigned short = ne.nic_addr + NE_P0_RSAR1
	dim _addr_NE_NOVELL_DATA	as unsigned short = ne.asic_addr+NE_NOVELL_DATA
	
	dim cpt as unsigned integer
	dim b as unsigned byte
	dim w as unsigned short
	
	'// Word align length
	if (_len and 1) then _len+=1

	
	'// Abort any remote DMA already in progress
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD2 | NE_CR_STA);
	b = NE_CR_RD2 or NE_CR_STA
	outb([_addr_NE_P0_CR],[b])

	'// Setup DMA byte count
	'outportb(ne->nic_addr + NE_P0_RBCR0, (len&0xff));
	'outportb(ne->nic_addr + NE_P0_RBCR1, (len >> 8)&0xff);
	b = _len and &hff
	outb([_addr_NE_P0_RBCR0],[b])
	b = (_len shr 8) and &hff
	outb([_addr_NE_P0_RBCR1],[b])

	'// Setup NIC memory source address
	'outportb(ne->nic_addr + NE_P0_RSAR0, (src&0xff));
	'outportb(ne->nic_addr + NE_P0_RSAR1, (src >> 8)&0xff);
	b = _src and &hff
	outb([_addr_NE_P0_RSAR0],[b])
	b = (_src shr 8) and &hFF
	outb([_addr_NE_P0_RSAR1],[b])
	
	'// Select remote DMA read
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD0 | NE_CR_STA);
	b = NE_CR_RD0 or NE_CR_STA
	outb([_addr_NE_P0_CR],[b])

	'// Read NIC memory
	'insw(ne->asic_addr+NE_NOVELL_DATA,(unsigned short *)dat,len/2);
	dim l as unsigned short = _len /2
	
	dim buff as unsigned short ptr = cptr(unsigned short ptr,dst)
	for cpt = 0 to _len-1
		inb([_addr_NE_NOVELL_DATA],[b])
		dst[cpt]=b
	next
end sub

sub ne_receive()
	dim packet_hdr as recv_ring_desc
	dim packet_ptr as unsigned short
	dim _len as unsigned short
	dim bndry as unsigned byte
	dim p as unsigned byte ptr
	dim q as unsigned byte ptr
	dim bufferaddr as buffer_header ptr
	dim rc as integer
	
	dim b as unsigned byte
	dim _addr_NE_P0_CR		as unsigned short = ne.nic_addr + NE_P0_CR
	dim _addr_NE_P1_CURR	as unsigned short = ne.nic_addr + NE_P1_CURR
	dim _addr_NE_P0_BNRY	as unsigned short = ne.nic_addr + NE_P0_BNRY
	'// Set page 1 registers
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_PAGE_1 | NE_CR_RD2 | NE_CR_STA);
	b = NE_CR_PAGE_1 or NE_CR_RD2 or NE_CR_STA
	outb([_addr_NE_P0_CR],[b])

	inb([_addr_NE_P1_CURR],[b])
	while (ne.next_pkt <> b)
  
		'// Get pointer to buffer header structure
		packet_ptr = ne.next_pkt * NE_PAGE_SIZE

		'// Read receive ring descriptor
		ne_readmem(packet_ptr, cptr(unsigned byte ptr,@packet_hdr), sizeof(recv_ring_desc))

		'// Allocate packet buffer
		_len = packet_hdr.count - sizeof(recv_ring_desc)
		

		'// Get packet from nic and send to upper layer
		packet_ptr += sizeof(recv_ring_desc)
		bufferaddr=eth_buffer->next_entry
		bufferaddr->size=_len
		dim dataptr as unsigned integer= cptr(unsigned integer,bufferaddr)+sizeof(buffer_header)
		ne_get_packet(packet_ptr,cptr(unsigned byte ptr,dataptr),_len)
		'eth_buffer->next_entry+=_len+(sizeof(buffer_header))
		eth_buffer->next_entry = cptr(buffer_header ptr, dataptr+_len)
		
		'// Update next packet pointer
		ne.next_pkt = packet_hdr.next_pkt

		'// Set page 0 registers
		'outportb(ne->nic_addr + NE_P0_CR, NE_CR_PAGE_0 | NE_CR_RD2 | NE_CR_STA);
		b = NE_CR_PAGE_0 or NE_CR_RD2 or NE_CR_STA
		outb([_addr_NE_P0_CR],[b])

		'// Update boundry pointer
		bndry = ne.next_pkt - 1
		if (bndry < ne.rx_page_start) then bndry = ne.rx_page_stop - 1
		'outportb(ne->nic_addr + NE_P0_BNRY, bndry);
		outb([_addr_NE_P0_BNRY],[bndry])

		'//kprintf("start: %02x stop: %02x next: %02x bndry: %02x\n", ne->rx_page_start, ne->rx_page_stop, ne->next_pkt, bndry);

		'// Set page 1 registers
		'outportb(ne->nic_addr + NE_P0_CR, NE_CR_PAGE_1 | NE_CR_RD2 | NE_CR_STA);
		b = NE_CR_PAGE_1 or NE_CR_RD2 or NE_CR_STA
		outb([_addr_NE_P0_CR],[b])

		inb([_addr_NE_P1_CURR],[b])
    wend
end sub

sub ne_get_packet(src as unsigned short, dst as unsigned byte ptr,_len as unsigned short)
	if (src+_len > ne.rx_ring_end) then
		dim split as unsigned short = ne.rx_ring_end - src
		ne_readmem(src, dst, split)
		_len -= split
		src = ne.rx_ring_start
		dst += split
	end if
	ne_readmem(src, dst, _len)
end sub

function ne_poll(dst as unsigned byte ptr) as unsigned integer
	dim myheader as buffer_header ptr
	dim asrc as unsigned byte ptr
	dim adst as unsigned byte ptr
	dim cpt as unsigned integer
	dim count as unsigned integer
	
	if (cuint(eth_buffer->next_entry) = cuint(eth_buffer)+sizeof(buffer)) then
		'ConsoleWriteLine(@"NE2000 - no packet to pool")
		return 0
	end if
	
	'//read the first packet
	myheader=cptr(buffer_header ptr,cuint(eth_buffer)+sizeof(buffer))
	count=myheader->size
	dim _data as unsigned byte ptr = cptr(unsigned byte ptr,cuint(myheader)+sizeof(buffer_header))
	for cpt = 0 to count-1
		dst[cpt] = _data[cpt]
	next
	
	'//remove it
	eth_buffer->next_entry-= (count + sizeof(buffer_header))
	'//move all the next packet
	adst= cptr(unsigned byte ptr,cuint(eth_buffer)+sizeof(buffer))
	asrc= cptr(unsigned byte ptr,cuint(adst)+sizeof(buffer_header)+count)
	dim toCopy as unsigned integer = 4096 - sizeof(buffer) - sizeof(buffer_header) - count
	for cpt = 0 to toCopy-1
		adst[cpt]=asrc[cpt]
	next
	return count
end function

CONST NE_DMA_MIN_SIZE = 64
function ne_transmit(p as unsigned byte ptr,_len as unsigned integer) as unsigned integer
	if (_len<1) then return 0
	_len = _len+1 and &hFFFFFFFE
	
	dim _dst_addr as unsigned byte ptr = cptr(unsigned byte ptr,p)
	dim _src_addr as unsigned byte ptr = cptr(unsigned byte ptr,cuint(p)+6)
	dim ii as unsigned integer
	ConsoleWrite(@"TRANSMIT FROM ")
	for ii=0 to 5
		if (_src_addr[ii]<16) then ConsoleWrite(@"0")
		ConsoleWriteNumber(_src_addr[ii],16)
		if (ii<5) then ConsoleWrite(@":")
	next
	ConsoleWrite(@" TO ")
	for ii=0 to 5
		if (_dst_addr[ii]<16) then ConsoleWrite(@"0")
		ConsoleWriteNumber(_dst_addr[ii],16)
		if (ii<5) then ConsoleWrite(@":")
	next
	ConsoleNewLine()
	
	
	dim _addr_NE_P0_CR		as unsigned short = ne.nic_addr + NE_P0_CR
	dim _addr_NE_P0_ISR		as unsigned short = ne.nic_addr + NE_P0_ISR
	dim _addr_NE_P0_RBCR0	as unsigned short = ne.nic_addr + NE_P0_RBCR0
	dim _addr_NE_P0_RBCR1	as unsigned short = ne.nic_addr + NE_P0_RBCR1
	dim _addr_NE_P0_RSAR0	as unsigned short = ne.nic_addr + NE_P0_RSAR0
	dim _addr_NE_P0_RSAR1	as unsigned short = ne.nic_addr + NE_P0_RSAR1
	dim _addr_NE_NOVELL_DATA	as unsigned short = ne.asic_addr+NE_NOVELL_DATA
	dim _addr_NE_P0_TPSR	as unsigned short = ne.nic_addr + NE_P0_TPSR
	dim _addr_NE_P0_TBCR0	as unsigned short = ne.nic_addr + NE_P0_TBCR0
	dim _addr_NE_P0_TBCR1	as unsigned short = ne.nic_addr + NE_P0_TBCR1
	
	dim b as unsigned byte
	dim dma_len as unsigned integer
	dim dst as unsigned byte
	dim cpt as unsigned integer
	
	'kprintf("ne_transmit: transmit packet len=%d\n", p->tot_len);

	'// We need to transfer a whole number of words
	dma_len = _len
	if (dma_len<NE_DMA_MIN_SIZE) then dma_len=NE_DMA_MIN_SIZE

	'// Clear packet transmitted and dma complete event
	ne.ptx=0
	ne.rdc=0
  
	'// Set page 0 registers
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD2 | NE_CR_STA);
	b = NE_CR_RD2 or NE_CR_STA
	outb([_addr_NE_P0_CR],[b])

	'// Reset remote DMA complete flag
	'outportb(ne->nic_addr + NE_P0_ISR, NE_ISR_RDC);
	b = NE_ISR_RDC
	outb([_addr_NE_P0_ISR],[b])

	'// Set up DMA byte count
	'outportb(ne->nic_addr + NE_P0_RBCR0, dma_len);
	'outportb(ne->nic_addr + NE_P0_RBCR1, dma_len >> 8);
	b = dma_len and &hff
	outb([_addr_NE_P0_RBCR0],[b])
	b = (dma_len shr 8) and &hff
	outb([_addr_NE_P0_RBCR1],[b])

	'// Set up destination address in NIC memory
	dst = ne.rx_page_stop	'; // for now we only use one tx buffer
	'outportb(ne->nic_addr + NE_P0_RSAR0, (dst * NE_PAGE_SIZE)&0xff);
	'outportb(ne->nic_addr + NE_P0_RSAR1, ((dst * NE_PAGE_SIZE) >> 8)&0xff);
	b = (dst*NE_PAGE_SIZE) and &hFF
	outb([_addr_NE_P0_RSAR0],[b])
	b = ((dst*NE_PAGE_SIZE) shr 8) and &hFF
	outb([_addr_NE_P0_RSAR1],[b])

	'// Set remote DMA write
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD1 | NE_CR_STA);
	b =  NE_CR_RD1 or NE_CR_STA
	outb([_addr_NE_P0_CR],[b])

	'//write data to register
	'outsw(ne->asic_addr+NE_NOVELL_DATA,p,len/2);
	
	asm
		mov esi,[p]
		mov ecx,[_len]
		shr ecx,1
		mov dx,[_addr_NE_NOVELL_DATA]

		epw_002:
			mov ax,[esi]
			inc esi
			out dx,ax
		loop epw_002
	end asm
	
	dim padd as integer = 0
	if (_len<NE_DMA_MIN_SIZE) then 
		padd = NE_DMA_MIN_SIZE-_len
		
		asm
			xor eax,eax
			mov ecx,[padd]
			shr ecx,1
			mov dx,[_addr_NE_NOVELL_DATA]
			epw_003:
				out dx,ax
			loop epw_003
		end asm
	end if
	ConsoleWrite(@"DMA size : ")
	ConsoleWriteNumber(dma_len,10)
	ConsoleNewLine()
	ConsoleWrite(@"Packet size : ")
	ConsoleWriteNumber(_len,10)
	ConsoleNewLine()
	ConsoleWrite(@"Bytes written : ")
	ConsoleWriteNumber(_len+padd,10)
	ConsoleNewLine()
	ConsoleWriteLine(@"NE2000 - Data written to port")
	
	
	
	'for cpt = 0 to _len-1
	'	b = p[cpt]
	'	outb([_addr_NE_NOVELL_DATA],[b])
	'next
	'if (padd>0) then
	'for cpt = 0 to padd-1
	'	b = 0
	'	outb([_addr_NE_NOVELL_DATA],[b])
	'next
	'end if

	'// Wait for remote DMA complete
	'for (cpt=0;!(ne->rdc);cpt++)
	'{
	'	 if (cpt>NE_TIMEOUT)
	'	 {
	'		xprintf("ne2000: timeout waiting for remote dma to complete\n");
	'		return -1;
	'	 }
	'}
	
	cpt = 0
	while ne.rdc = 0
		'if (cpt>NE_TXTIMEOUT) then
		'	ConsoleWriteLine(@"NE2000 - Timeout while waiting for remote dma to complete")
		'	return 0
		'end if
		cpt+=1
	wend
	ConsoleWriteLine(@"DMA Complete")
  
	'// Set TX buffer start page
	'outportb(ne->nic_addr + NE_P0_TPSR, dst);
	ConsoleWriteLine(@"Set TX buffer start page")
	b = dst
	outb([_addr_NE_P0_TPSR],[b])

	'// Set TX length (packets smaller than 64 bytes must be padded)
	ConsoleWriteLine(@"Set TX length")
	b = dma_len and &hFF
	outb([_addr_NE_P0_TBCR0],[b])
	b = (dma_len shr 8) and &hFF
	outb([_addr_NE_P0_TBCR1],[b])

	'// Set page 0 registers, transmit packet, and start
	'outportb(ne->nic_addr + NE_P0_CR, NE_CR_RD2 | NE_CR_TXP | NE_CR_STA);
	ConsoleWriteLine(@"Set page 0 registers, transmit packet, and start")
	b = NE_CR_RD2 or NE_CR_TXP or NE_CR_STA
	outb([_addr_NE_P0_CR],[b])

	'//Wait for packet transmitted
	'for (cpt=0;!(ne->ptx);cpt++);
   '{
		'if (cpt>NE_TIMEOUT)
		'{
			'xprintf("ne2000: timeout waiting for packet transmit\n");
			'return -1;
			'}
	'}
	ConsoleWrite(@"Wait for packet transmit")
	cpt = 0
	while ne.ptx = 0
		if (cpt mod 10) = 0 then consoleWrite(@".")
		if (cpt>NE_TIMEOUT) then
			ConsoleWriteLine(@"NE2000 - Timeout while waiting for packet transmit")
			return 0
		end if
		cpt+=1
	wend
	ConsoleWriteLine(@"...Packet transmited")
	ConsoleNewLine()
	return 1
end function