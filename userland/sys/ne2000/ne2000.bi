
const ETHER_ADDR_LEN = 6
const eth_page_start = &h1000


const NE_NOVELL_NIC_OFFSET	= &h00
const NE_NOVELL_ASIC_OFFSET	= &h10

const NE_NOVELL_DATA        = &h00
const NE_NOVELL_RESET       = &h0F

const	NE_PAGE_SIZE          	= 256	 'Size of RAM pages in bytes
const	NE_TXBUF_SIZE			= 6      'Size of TX buffer in pages
const	NE_TX_BUFERS            = 2      'Number of transmit buffers

'//
'// Page 0 register offsets
'//
const NE_P0_CR		= &h00           '// Command Register

const NE_P0_CLDA0	= &h01           '// Current Local DMA Addr low (read)
const NE_P0_PSTART	= &h01           '// Page Start register (write)

const NE_P0_CLDA1	= &h02           '// Current Local DMA Addr high (read)
const NE_P0_PSTOP	= &h02           '// Page Stop register (write)

const NE_P0_BNRY	= &h03           '// Boundary Pointer

const NE_P0_TSR		= &h04           '// Transmit Status Register (read)
const NE_P0_TPSR	= &h04           '// Transmit Page Start (write)

const NE_P0_NCR		= &h05           '// Number of Collisions Reg (read)
const NE_P0_TBCR0	= &h05           '// Transmit Byte count, low (write)

const NE_P0_FIFO	= &h06           '// FIFO register (read)
const NE_P0_TBCR1	= &h06           '// Transmit Byte count, high (write)

const NE_P0_ISR 	= &h07           '// Interrupt Status Register

const NE_P0_CRDA0	= &h08           '// Current Remote DMA Addr low (read)
const NE_P0_RSAR0	= &h08           '// Remote Start Address low (write)

const NE_P0_CRDA1	= &h09           '// Current Remote DMA Addr high (read)
const NE_P0_RSAR1	= &h09           '// Remote Start Address high (write)

const NE_P0_RBCR0	= &h0A           '// Remote Byte Count low (write)

const NE_P0_RBCR1	= &h0B           '// Remote Byte Count high (write)

const NE_P0_RSR 	= &h0C           '// Receive Status (read)
const NE_P0_RCR		= &h0C           '// Receive Configuration Reg (write)

const NE_P0_CNTR0	= &h0D           '// Frame alignment error counter (read)
const NE_P0_TCR		= &h0D           '// Transmit Configuration Reg (write)

const NE_P0_CNTR1	= &h0E           '// CRC error counter (read)
const NE_P0_DCR		= &h0E           '// Data Configuration Reg (write)

const NE_P0_CNTR2	= &h0F           '// Missed packet counter (read)
const NE_P0_IMR     = &h0F           '// Interrupt Mask Register (write)

'//
'// Page 1 register offsets
'//
const NE_P1_CR        = &h00           '// Command Register
const NE_P1_PAR0      = &h01           '// Physical Address Register 0
const NE_P1_PAR1      = &h02           '// Physical Address Register 1
const NE_P1_PAR2      = &h03           '// Physical Address Register 2
const NE_P1_PAR3      = &h04           '// Physical Address Register 3
const NE_P1_PAR4      = &h05           '// Physical Address Register 4
const NE_P1_PAR5      = &h06           '// Physical Address Register 5
const NE_P1_CURR      = &h07           '// Current RX ring-buffer page
const NE_P1_MAR0      = &h08           '// Multicast Address Register 0
const NE_P1_MAR1      = &h09           '// Multicast Address Register 1
const NE_P1_MAR2      = &h0A           '// Multicast Address Register 2
const NE_P1_MAR3      = &h0B           '// Multicast Address Register 3
const NE_P1_MAR4      = &h0C           '// Multicast Address Register 4
const NE_P1_MAR5      = &h0D           '// Multicast Address Register 5
const NE_P1_MAR6      = &h0E           '// Multicast Address Register 6
const NE_P1_MAR7      = &h0F           '// Multicast Address Register 7

'//
'// Command Register (CR)
'//
const NE_CR_STP		= &h01           '// Stop
const NE_CR_STA		= &h02           '// Start
const NE_CR_TXP		= &h04           '// Transmit Packet
const NE_CR_RD0		= &h08           '// Remote DMA Command 0
const NE_CR_RD1		= &h10           '// Remote DMA Command 1
const NE_CR_RD2		= &h20           '// Remote DMA Command 2
const NE_CR_PS0		= &h40           '// Page Select 0
const NE_CR_PS1		= &h80           '// Page Select 1

const NE_CR_PAGE_0		= &h00           '// Select Page 0
const NE_CR_PAGE_1		= &h40           '// Select Page 1
const NE_CR_PAGE_2		= &h80           '// Select Page 2

'//
'// Interrupt Status Register (ISR)
'//

const NE_ISR_PRX	=&h01           '// Packet Received
const NE_ISR_PTX	=&h02           '// Packet Transmitted
const NE_ISR_RXE	=&h04           '// Receive Error
const NE_ISR_TXE	=&h08           '// Transmission Error
const NE_ISR_OVW	=&h10           '// Overwrite
const NE_ISR_CNT	=&h20           '// Counter Overflow
const NE_ISR_RDC	=&h40           '// Remote Data Complete
const NE_ISR_RST	=&h80           '// Reset status

'//
'// Data Configuration Register (DCR)
const NE_DCR_WTS      = &h01           '// Word Transfer Select
const NE_DCR_BOS      = &h02           '// Byte Order Select
const NE_DCR_LAS      = &h04           '// Long Address Select
const NE_DCR_LS       = &h08           '// Loopback Select
const NE_DCR_AR       = &h10           '// Auto-initialize Remote
const NE_DCR_FT0      = &h20           '// FIFO Threshold Select 0
const NE_DCR_FT1      = &h40           '// FIFO Threshold Select 1

'//
'// Interrupt Mask Register (IMR)
const NE_IMR_PRXE     = &h01           '// Packet Received Interrupt Enable
const NE_IMR_PTXE     = &h02           '// Packet Transmit Interrupt Enable
const NE_IMR_RXEE     = &h04           '// Receive Error Interrupt Enable
const NE_IMR_TXEE     = &h08           '// Transmit Error Interrupt Enable
const NE_IMR_OVWE     = &h10           '// Overwrite Error Interrupt Enable
const NE_IMR_CNTE     = &h20           '// Counter Overflow Interrupt Enable
const NE_IMR_RDCE     = &h40           '// Remote DMA Complete Interrupt Enable

'//
'// Receiver Configuration Register (RCR)
'//
const NE_RCR_SEP      = &h01           '// Save Errored Packets
const NE_RCR_AR       = &h02           '// Accept Runt packet
const NE_RCR_AB       = &h04           '// Accept Broadcast
const NE_RCR_AM       = &h08           '// Accept Multicast
const NE_RCR_PRO      = &h10           '// Promiscuous Physical
const NE_RCR_MON      = &h20           '// Monitor Mode


type NE_TYPE field = 1
	hwaddr(0 to ETHER_ADDR_LEN-1) as unsigned byte 'MAC address
	padding(0 to 1) as unsigned byte
	IOBASE	as unsigned short	'Configured I/O base
	IRQ		as unsigned short	'Configured IRQ
	MEMBASE as unsigned short	' Configured memory base
	MEMSIZE as unsigned short	'Configured memory size
	
	ASIC_ADDR		as unsigned short	'ASIC I/O bus address
	NIC_ADDR		as unsigned short	'NIC (DP8390) I/O bus address
	
	rx_ring_start	as unsigned short	'Start address of receive ring
	rx_ring_end		as unsigned short	'End address of receive ring
	
	rx_page_start	as unsigned byte	'Start of receive ring
	rx_page_stop	as unsigned byte	'End of receive ring
	next_pkt		as unsigned byte	'Next unread received packet
	
	ptx				as unsigned integer		'packed transmit event
	rdc				as unsigned integer		'remote dma complete event
	prx				as unsigned integer		'packed receive event
end type

type recv_ring_desc field=1
	rsr 		as unsigned byte	'// Receiver status
	next_pkt	as unsigned byte	'// Pointer to next packet
	count		as unsigned short	'// Bytes in packet (length + 4)
end type

type buffer_header field=1
	size as unsigned integer
end type

type buffer field=1
	next_entry as buffer_header ptr
end type

const NE_TIMEOUT              = 10000
const NE_TXTIMEOUT            = 30000

dim shared ETH_IRQ_THREAD as unsigned integer
dim shared ETH_IPC as unsigned integer
dim shared NE as NE_TYPE
dim shared eth_buffer as buffer ptr
dim shared eth_buffer_bytes(0 to 4095) as unsigned byte


declare sub ETH_IRQ_Thread_Loop(p as any ptr)
declare sub ETH_IRQ_Handler()

declare function ne_setup(iobase as unsigned integer, irq as unsigned integer, membase as unsigned short,  memsize as unsigned short) as unsigned integer
declare function ne_probe() as unsigned integer
declare sub ne_readmem(_src as unsigned short,_dst as unsigned byte ptr,_len as unsigned short)
declare sub ne_receive()
declare sub ne_get_packet(src as unsigned short, dst as unsigned byte ptr,_len as unsigned short)
declare function ne_poll(dst as unsigned byte ptr) as unsigned integer
declare function ne_transmit(p as unsigned byte ptr,_len as unsigned integer) as unsigned integer