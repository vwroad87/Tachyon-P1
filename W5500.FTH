TACHYON
[~

FORGET W5500.fth
pub W5500.fth		PRINT" WIZNET W5500 driver 150512.2100 " ;
{

160512	Optimized low level SPI interface - i.e. shaved 10us off LC@
}


--- some default IP settings that are only loaded in on a new pcb and if storage locations in upper eeprom is blank
&192.168.16.1		== myGW
&192.168.16.150		== myIP
&255.255.255.0		== mySN



( HARDWARE DEFINITIONS )
IFNDEF &WNCS
#P12	|< == &WNDO			'' MISO from WIZNET
#P13	|< == &WNCS			'' WIZNET CS
#P14	|< == &WNCK
#P15	|< == &WNDI			'' MOSI to WIZNET
}
\ Compile time constant for pin configuration
&WNCS >| #24 SHL &WNDO >| 16 SHL + &WNDI >| 8 SHL + &WNCK >| + == wizpins ( &ce.miso.mosi.sck )

IFNDEF WRESET					\ what to do if the user has not specified the reset and pwrdn
pub WRESET ( on/off -- )	DROP ; 	\ assume it's not connected
}
IFNDEF WPWRDN					\ what to do if the user has not specified the reset and pwrdn
pub WPWRDN ( on/off )		DROP ;
}

IFNDEF SPICE
pub SPICE	&WNCS OUTSET ;
}


( Diagram: WIZnet SPI timing )

--- Setup both read and write control byte constants for selected block - 160512
0 == wrc		--- Control byte - b7..5 = socket ; b4..b3 = tx/rx/skt/com section ; b2 = r/w ; b1..b0 = 0
0 == rdc
--- skt.2 skt.1 skt.0 seg.1 - seg.0 rw  0 0


--- BLOCK ADDRESSING ---

\ 7   6   5   4   3   2   1   0
\  --BLOCK--   -SET-   RW  -LEN-

--- Select  socket, rx or tx block in the current socket
pri SKTBLK ( blk -- )	rdc $1C ANDN OR				--- clear reg/tx/rx context b4,b3
pri ctrl!		DUP ' rdc 1+ ! 4 OR ' wrc 1+ ! ;		--- preset control control for reads or writes
pub @COMMON		0 ctrl! ;					--- common registers ( socket 0, bank 0)
pub @SKT		8 SKTBLK ;					--- select RX buffer
pub @TX			$10 SKTBLK ;					--- select TX buffer
pub @RX			$18 SKTBLK ;					--- select RX buffer



--- WRITE METHODS ---

pub LC! ( byte wizadr -- ) ( 34.6us )
	SPIWR16 DROP						--- write address
 	wrc SPIWRB DROP
 	SPIWRB DROP
 	SPICE
	;
pub LW! ( word wizadr -- )
	SPIWR16 DROP						--- write address
 	wrc SPIWRB DROP
 	SPIWR16 DROP
 	SPICE
	;
pub L! ( long wizadr -- )
	SPIWR16 DROP						--- write address
 	wrc SPIWRB DROP
 	SPIWR SPIWR SPIWR SPIWR DROP				--- write 4 bytes (long)
 	SPICE
	;

--- READ METHODS ---


pub LC@ ( wizadr -- data )					--- 13.5us (11us SPI)
	SPIWR16 DROP						--- send addr
 	rdc SPIWRB SPIRD					--- read back 8-bits data
 	SPICE >B						--- limit to single 8-bits
	;
pub LW@ ( wizadr -- data )					--- 16.6us (14.5us SPI)
	SPIWR16 DROP						--- send addr
 	rdc SPIWRB DROP
	0 SPIRD SPIRD	 					--- read back 16-bits data
 	SPICE
	;
pub L@ ( wizadr -- data )					--- 18,166us (17us SPI)
	SPIWR16 DROP						--- send addr
 	rdc SPIWRB SPIRD SPIRD SPIRD SPIRD			--- read back 32-bits data
 	SPICE
	;

--- BLOCK TRANSFER METHODS ---

--- 140703 - Allow block read/write to access virtual memory if > $8000
LONG vread,vwrite --- maintain a read/write pointer for any virtual memory writes

--- Read a block of memory from the WIZnet
--- if dst is > $8000 then use virtual memory
pub LREAD ( src dst cnt -- )
	ROT SPIWR16 DROP ( dst cnt)				--- src address (WIZnet)
 	rdc SPIWRB DROP \ RD_WCTRL
 	OVER $7FFF >
 	  IF 2DUP + vwrite ! ADO 0 SPIRD I XC! LOOP		--- byte read every 5.5us (96MHZ)
 	  ELSE ADO 0 SPIRD I C! LOOP
 	  THEN
	SPICE
	;



--- Write a block to the WIZnet - 3.2ms/512 bytes = = 6.25us/byte = 160kB/sec  : 1kB block in 4.63ms (217K/sec)
pub LWRITE ( src dst cnt -- )
	SWAP SPIWR16 DROP					--- Send dst address
 	wrc SPIWRB DROP \ WR_WCTRL				--- Control block
	( src cnt ) ADO I C@ SPIWRB DROP LOOP			--- now just send the bytes sequentially every 4.5us
 	SPICE
	;



( ----------------------------------- REGISTER LEVEL INTERFACE -------------------------------- )

--- EEPROM CONFIG BACKUP ---
--- Use the top part of the 64K EEPROM to save IP settings
--- 141219 Moved from $FF00 to $FFC0 because EEWORDS using top 32K of EEPROM
$FFC0	ORG
4	DS @gateway
4	DS @sip
4	DS @subnet
4	DS @mac
4	DS @wcold
#32	DS @ports

\ common registers

\ Access common registers
pub wMODE ( mask -- )		0 @COMMON LC! ;
pub GATEWAY ( addr -- )		DUP @gateway E! 1 @COMMON L! ;
pub SUBNET ( mask -- )		DUP @subnet E! 5 @COMMON L! ;
pub MAC ( high low  -- )	DUP @mac E! $0B @COMMON L! 9 LW! ;
pub SIP ( long -- )		DUP @sip E! $0F @COMMON L! ;


pri INTS@ ( -- ints )		$15 @COMMON LC@ ;
pri INTMASK ( mask -- )		$16 @COMMON LC! ;


pri @RTR ( -- adr )		$19 @COMMON ;
pri @RCR ( -- adr )		$1B @COMMON ;

pri UIP ( ip -- )		$28 @COMMON L! ;
pri UPORT ( port -- )		$2C @COMMON LW! ;



( SOCKET INTERRUPTS )
4	|< == 	&SENDOK
3	|< == 	&TIMEOUT
2	|< == 	&RECV
1	|< == 	&DISCON
0	|< == 	&CON

{
( SOCKET STATUS CODES )
$00	==	SOCK_CLOSED
$13	==	SOCK_INIT
$14	==	SOCK_LISTEN
$17	==	SOCK_ESTABLISHED
$1C	==	SOCK_CLOSE_WAIT
$22	==	SOCK_UDP
$32	==	SOCK_IPRAW
$42	==	SOCK_MACRAW
$5F	==	SOCK_PPOE

( SOCKET TRANSIENT STATUS CODES )
$15	==	SOCK_SYNSENT
$16	==	SOCK_SYNRECV
$18	==	SOCK_FIN_WAIT
$1A	==	SOCK_CLOSING
$1B	==	SOCK_TIME_WAIT
$1D	==	SOCK_LAST_ACK
$11	==	SOCK_ARP
$21	==	SOCK_ARP1
$31	==	SOCK_ARP2
}

2 BYTES socket --- current socket plus foreground socket

--- Set the socket number ( calculates address and sets as a SOCKET constant b7,b6,b5 )
pub SOCKET ( socket -- )	DUP socket C! 5 SHL rdc $1C AND OR ctrl! ;
ALIAS SOCKET SKT

pub SKT@			socket C@ ;

--- modify wrc to address a socket register
pub @SOCKET			rdc $1B ANDN 8 OR ctrl! ;

\ Socket registers ( -- addr )
pri sCMD!			1 @SOCKET LC! ;		--- command
pri sINTS			2 @SOCKET ;		--- interrupts
pri sSTAT			3 @SOCKET ;		--- status
pri sPORT			4 @SOCKET ;		--- 2 byte src port
pri sDHAR! ( dst. -- )		6 @SOCKET ;		--- 6 byte dest hardware address
pri sDIP! ( ip -- )		SWAP $0C @SOCKET L! ;	--- 4 byte dest IP address
pri sDPORT			$10 @SOCKET ;		--- 2 byte dest port
pri sSSIZE			$12 @SOCKET ;		--- 2 byte dest max seg size
pri sPRO			$14 @SOCKET ;		--- protocol in IP raw mode

pri sRXMEM			$1E @SOCKET ;
pri sTXMEM			$1F @SOCKET ;
pri TXFREE@			$20 @SOCKET LW@ ;
pri TXREAD			$22 @SOCKET ;
pri TXWRITE			$24 @SOCKET ;
pri RXSIZE@			$26 @SOCKET LW@ ;
pri RXREAD			$28 @SOCKET ;
pri RXWRITE			$2A @SOCKET ;
pri KEEPTMR			$2D @SOCKET ;		--- keep alive timer

\ Protocol modes
pri sMODE			0 @SOCKET ;		--- mode
pri CLOSED			0 sMODE LC! ;
pub TCP				1 sMODE LC! ;
pub UDP				2 sMODE LC! ;
pri IPRAW			3 sMODE LC! ;
pri MACRAW			4 sMODE LC! ;
pri PPPoE			5 sMODE LC! ;





( SOCKET COMMANDS - use currently select socket )
pub sOPEN		1 sCMD! ;
pub sLISTEN		2 sCMD! ;
pub sCONNECT		4 sCMD! ;
pub sDISCON		8 sCMD! ;
pub sCLOSE		$10 sCMD! ;
pub sSEND		$20 sCMD! ;
pub sSENDMAC		$21 sCMD! ;
pub sSENDKEEP		$22 sCMD! ;
pub sRECV		$40 sCMD! ;


pri sCLOSED? 		sSTAT LC@ 0= ;
pri sINACTIVE?		sSTAT LC@ $17 < ;
pri sESTAB?		sSTAT LC@ $17 = ;
pri sCLOSING?		sSTAT LC@ $18 $1B WITHIN ;				--- closing or wait closing

pri sCONNECTED?		sINTS LC@ &CON AND DUP IF &CON sINTS LC! THEN ;		--- Test and reset the connection interrupt;
pri sDISCON?		sINTS LC@ &DISCON AND DUP IF -1 sINTS LC! THEN ;





pub PORT! ( srcport -- ) --- save port config and set port
 	DUP SKT@ 2* 2* @ports + E!
pub SetPORT
 	sPORT LW!
 	;






{ Since the W5500??? read and write index registers are unreadable until a connection has been established
or cannot be written incrementally until a send then these are buffered for when they become readable
}

8 WORDS txwr PRIVATE						--- tx write buffers for 8 sockets

pub @txwr ( -- addr )   	txwr SKT@ 2* + ;

--- Init local copies of tx write indices
pub !TXWR			txwr BL $FF FILL ;		--- invalidate all txwr pointers (W5500 workaround)



LONG txtime,txsize

BYTE autosend							--- Flag to control whether LANSEND sends when it receives a LF or not
\ $0A autosend C!							--- preset to autosend

TIMER sendtimer PRIVATE

pri WAITSEND
 	txsize @ 0EXIT 						--- don't bother if it's empty
 	#5000 sendtimer TIMEOUT					--- give it some time to send what it has
 	BEGIN
 	  sINTS LC@ &SENDOK AND 				--- until sent
 	  TXREAD LW@ TXWRITE LW@ = AND
 	  sendtimer TIMEOUT? OR 				--- or until timeout
 	UNTIL
 	&SENDOK sINTS LC!					--- reset the sent interrupt flag
 	;



--- Request WIZnet to send off current transmit data in buffer
pub ?SENDPOLL
	txtime @ CNT@ - ABS CLKFREQ 7 >> >			--- 1/128 sec timeout since last
 	0EXIT
pub ?SEND							--- check to see if anything still needs to be sent
 	txsize @ 0EXIT						--- Exit if buffer empty
pub LANSEND
 	&SENDOK sINTS LC!					--- Clear send interrupt
 	@txwr W@ TXWRITE LW! sSEND				--- update TXWRITE register and command WIZnet to SEND
	WAITSEND
  	txsize ~ 						--- reset txsize (buffer empty)
 	;




--- send out a character through the WIZnet - either block mode or autosend
pub LANEMIT ( ch -- )
 	DUP @txwr W@ @TX LC!					--- write character to buffer
  	@txwr W++ CNT@ txtime !					--- update local write index and activity
 	txsize ++						--- keep count of how much might be accumulating in the h/w buffer
	$0A = autosend C@ AND					--- SEND if this is an CRLF end of line and autosend is active
 	txsize @ $3F0 > OR 					--- or AUTOSEND if buffer size is large enough already
	  IF LANSEND THEN					--- Update WIZnet chip and command it to send what it has
	;



pub LANKEY ( -- ch )
 	RXSIZE@
 	IF
 	  RXREAD LW@ DUP @RX LC@ 				--- read a character from the receive buffer
 	  SWAP 1+ RXREAD LW! sRECV				--- update read index
 	ELSE
 	  keypoll W@ ?DUP IF CALL THEN				--- implement a keypoll for when LANKEY is doing nothing
 	  0							--- return with a null character
 	THEN
	;

( Redirect console output to the LAN )
pub LAN
	' LANEMIT uemit W!
 	' LANKEY ukey W!
	@txwr @ -1 = IF TXWRITE LW@ @txwr ! THEN		--- force an update (assumed valid) if the index is "invalid"
	;

( diagnostic to the terminal to reflect what is begin typed to the LAN )
pub LANCONEMIT
 	DUP (EMIT) LANEMIT
 	;


IFDEF KEY?
( allow input from both the serial console and the LAN socket )
pub LANCONKEY ( -- ch )
 	LANKEY KEY? AND OR
 	;
}

IFNDEF KEY?
( allow input from both the serial console and the LAN socket )
pub LANCONKEY ( -- ch )
 	LANKEY KEY OR
 	;
}

--- use both LAN and CON for output
pub LANCON
	CON CR LAN
 	' LANCONEMIT uemit W!
	;






--- initialization ---

( Set the factory defaults on very first run - generate a random MAC in the 01.FF.xx.xx.xx.xx range )
pub WCOLD
	CR PRINT" Setting default IP configuration "
 	myGW @gateway E!
 	myIP @sip E!
 	mySN @subnet E!
 	RND @mac E!						--- random MAC at first run, Need to have a unique ID
 	8 0 DO 0 I 2* 2* @ports + E! LOOP
 	$A55A @wcold E!
 	;

\ Init the SPI for the WIZnet chip
pub !WIZIO
	!PCB
	wizpins SPIPINS						--- Use SPI
	&WNCK OUTCLR						--- Clock is an output - leave low
	&WNDI OUTCLR						--- MOSI is an output
	ON WRESET OFF WPWRDN OFF WRESET
;

$02FF == oui2

pub !WIZIP
 	@wcold E@ $A55A <> IF WCOLD THEN
	@gateway E@ GATEWAY					--- Assign a default gateway
	@subnet E@ SUBNET
	@sip E@ SIP
	oui2 @mac E@ MAC
  	8 0 DO I 2* 2* @ports + E@ I SOCKET SetPORT LOOP
	$0A autosend C!						--- preset to autosend
	;

pri !TXBUFS 	8 0 DO I SOCKET $800 0 DO 0 I @TX L! 0 I @RX L! 2 +LOOP LOOP ;


pub !WIZ 	!WIZIO !TXBUFS !WIZIP ;







--- set WIZnet chip as source for any DUMP type operations
pub WIZ    ' LC@ dmm W! ' LW@ dmm 2+ W! ' L@ dmm 4 + W! ;

$800	== WBUFSZ


pri LSEND 		DUP @txwr W+! TXWRITE LW@ SWAP @TX LWRITE LANSEND ;


---  Read from WIZnet buffer into file until buffer is exhausted
--- Used by FTP STOR
pri LREADSKT ( dst --- )
	vwrite !
	BEGIN
	  RXSIZE@ ?DUP
	WHILE ( cnt )
	  RXREAD LW@ ( cnt index )						--- fetch receive read index for this socket
 	  SWAP
	  vwrite @ SWAP ( wizptr filedst cnt )
	  DUP >R
	  @RX LREAD vwrite ++							--- read WIZnet buffer directly into file and update vwrite+1
	  R> RXREAD LW@ + RXREAD LW!						--- update read index in advance
	  sRECV									--- signal that buffer up to READ index has been read
	  #10 ms
	REPEAT
	;


$10 LONGS sktbuf								--- holding buffer for socket registers

pri @SKTBUF 		sktbuf + ;

pri .IPX	DUP >B $30A .NUM 8 >> ;
pri .IP ( off -- )
	DECIMAL 3 SPACES
pub .IP1
	 @SKTBUF U@
	.IPX "." EMIT .IPX "." EMIT .IPX "." EMIT .IPX DROP
	;


pri .@SKTBUF	@SKTBUF
pri .PTR  		C@++ 8 << SWAP C@ + ( $7FF AND ) $2410 .NUM "." EMIT ;

IFNDEF SWAPB
pri SWAPB ( word -- word2 	\ Swap the bytes in a 16-bit word )
 	DUP 8 >> SWAP >B 8 << OR
 	;
}

IFNDEF .TIME
pub .TIME	." 00:00:00" ;
}

{
SKT HH:MM:SS MODE  PORT DEST  TXRD TXWR RXRD RXWR RXSZ  IR STATUS        	IP ADDR
#1  00:00:00 TCP 	21 52775 967F.967F.	.	.	. 00 17 ESTABLISHED	192.168.016.002.
}
pub .SKTHD		CR BOLD PRINT" SKT HH:MM:SS MODE  PORT  DEST TXRD TXWR RXRD RXWR RXSZ  IR STATUS            IP ADDR" PLAIN ;

pub .SOCKET ( n -- )
	.SKTHD
 pub .SKT
	DUP SOCKET 0 sktbuf $30 @SOCKET LREAD					--- read in registers
	0 @SKTBUF C@ IF CR "#" EMIT . 2 SPACES .TIME ELSE DROP EXIT THEN
 	0  @SKTBUF C@ SPACE
      4 * " CLSDTCP UDP IPRWMACRPPP !06!!07!" + 4 CTYPE SPACE
	4 @SKTBUF W@ SWAPB $250A .NUM SPACE					--- PORT
 	16 @SKTBUF W@ SWAPB $250A .NUM SPACE					--- DPORT
	$22 .@SKTBUF $24 .@SKTBUF						--- TXRD TXWR
 	$28 .@SKTBUF $2A .@SKTBUF						--- RXRD RXWR
 	$26 .@SKTBUF SPACE							--- RX SIZE
  	2 @SKTBUF C@ .BYTE SPACE						--- INT REG
 	3 @SKTBUF C@ DUP .BYTE							--- STATUS REG
\	pri .SSTAT ( byte -- )							--- STATUS DESCRIPTION
 	SWITCH SPACE
 	  0 CASE PRINT" closed      " BREAK
 	$13 CASE PRINT" INIT        " BREAK
 	$14 CASE PRINT" LISTEN      " BREAK
	$16 CASE PRINT" SYNRECV     "  $0C .IP BREAK
   	$17 CASE PRINT" ESTABLISHED "  $0C .IP BREAK
  	$18 CASE PRINT" FIN WAIT    "  $0C .IP BREAK
 	$1C CASE PRINT" closed wait " $0C .IP BREAK
 	$22 CASE PRINT" UDP OPEN    " BREAK
 	$32 CASE PRINT" IPRAW OPEN  " BREAK
 	;


pub ifconfig
	0 sktbuf $40 @COMMON LREAD	\ read in common registers
 	BOLD
	CR PRINT" NETWORK STATUS:" PLAIN
 	CR PRINT" LINK " 		1 $2E @SKTBUF SET? IF PRINT" *UP*" ELSE PRINT" DOWN" THEN
	CR PRINT" HARDWARE: " PCB$ PRINT$ PRINT"  using WIZnet W5500 V" $39 @SKTBUF C@ .
 	CR PRINT" SRC IP "	$0F .IP
 	CR PRINT" MASK   "	5 .IP
 	CR PRINT" GATEWAY"	1 .IP
	CR PRINT" MAC       "	9 @SKTBUF 6 ADO I C@ .BYTE PRINT" ." LOOP
pub .SOCKETS
	.SKTHD 8 0 DO I .SKT LOOP CR
	;


\ SOCKETS - W5500 has 8 sockets - define 4 of them
0	== NETMAN --- network management
1	== FTP
2	== FTPDAT
3	== TELNET
4	== HTTP --- uses sockets 4..7
" NETFTPDATTELWEBWEBWEBWEB" 0 STRING skt$



{ NOTE: Use WIZ DUMP or variation thereof instead of WDUMP

0 40 @COMMON WIZ DUMP

0 40 1 SKT @TX DUMP

}


]~
END


