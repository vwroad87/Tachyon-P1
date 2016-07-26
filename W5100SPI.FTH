TACHYON  
[~ 

FORGET W5100.fth

pub W5100.fth        PRINT" WIZNET W5100 SPI driver 150514.0000 " ;

!!! Work in progress - converting W5100 driver to SPI !!!

--- WIZnet W5100 driver ---
{
Adapted from the W5200.fth SPI driver
Uses Parallal indirect mode

CHANGELOG
141125    Fixed new bug in socket addressing
141104     included advances from W5200  MJB
140818    Removed all W5100 specifics from EASYNET
140616    Optimized low level bus driver

BUILD NOTES:
Compile Tachyon V2.4 onto Spinneret using Spin tool or BST etc
Load in this order:
NET.SET 
EXTEND.FTH
EPRINT.FTH
SPINNERET.FTH
SDCARD.FTH
EASYFILE.FTH
SDWORDS.FTH

Now ensure you have a FAT32 card loaded and have a copy of WORDS.DCT file on it (or create a blank 64K file). Check that all is well by listing the directory using either DIR or ls.
Now run COMPACT which will move the dictionary to WORDS.DCT and free up space not only for networking but also for applications.
After COMPACT has completed perform a BACKUP then load W5100.FTH and EASYNET.FTH to complete the build.
Type AUTORUN EASYNET if you want the board to boot up into the server. 

To change IP addresses it is just as easy to do this at runtime or anytime. For instance to change it to 10.0.0.5 with a 10.0.0.245 gateway:
  &10.0.0.5 SIP
  &10.0.0.245 GATEWAY

The & prefix ensures that the number will be interpreted in IP notation.
To make an image of the build use SAVEROM which will try to find a 64K file called FIRMWARE.ROM and save to that. The WORDS.DCT file is also needed. This image cannot be loaded directly by Spin tool though. An easier method will be developed later.


NOTES
current version is using emulated P@ and STROBE (slower)
}


--- USER DEFAULTS - CHANGE TO SUIT ---

&192.168.16.1		== myGW
&192.168.16.152		== myIP
&255.255.255.0		== mySN


--- W5100 SPINNERET CONNECTIONS ---

--- W5100 and PROPELLER connections



( HARDWARE DEFINITIONS )
{
NOTE: Use Spinneret Parallel interface
add hardware defs file "SPINNERET.FTH" as this is also used by SDCARD.fth to access SD and RTC etc.

8 bit data bus      -  P0..P7
2 bit address bus  -  P8..P9
/WR            - P10
/RD            - P11
/CS            - P12
/INT            - P13
E_RST            - P14
SEN            - P15
}
( HARDWARE DEFINITIONS )


#P12    |< == &WNDO                    --- MISO from WIZNET
#P13    |< == &WNCS                    --- WIZNET CS
#P14    |< == &WNCK
#P15    |< == &WNDI                    --- MOSI to WIZNET
}
\ Compile time constant for pin configuration
&WNCS >| #24 SHL &WNDO >| 16 SHL + &WNDI >| 8 SHL + &WNCK >| + == wizpins ( &ce.miso.mosi.sck )

IFNDEF WRESET                    \ what to do if the user has not specified the reset and pwrdn
pub WRESET ( on/off -- )    DROP ;     \ assume it's not connected
pub WPWRDN ( on/off )        DROP ;


}



$FF			== &W51DATA		--- W5100 databus mask for P0..P7    
$300			== &W51ADDR		--- W5100 address bus mask for P8..P9 in indirect mode as available in Spinneret

#P12    |<		== &W51CS		--- /CS

#P10    |< &W51CS +	== &W51WR		--- /WR is combined with CS
#P11    |< &W51CS +	== &W51RD		--- /RD is combined with CS
#P13    |<		== &W51INT		--- /INT
#P14    |<		== &W51RST		--- W5100 reset (E_RST)
#P15    |<		== &W51SEN		--- SEN  high to enable SPI 

&W51ADDR &W51WR + &W51RD + &W51CS + &W51SEN + == &W51OUTS 
}






$F000.0000	== wrop
$0F00.0000	== rdop

pub LC! ( byte wizadr -- ) 
    8<< OR wrop OR
    SPIWR SPIWR SPIWR SPIWR DROP
    SPICE
    ;
    
    
pub LW! ( word wizadr -- )
    SWAP W>B 3RD LC! SWAP LC!
    ;

pub L! ( long wizadr -- )
    SWAP L>W 3RD LW! SWAP LW! 
    ;


pub LC@ ( wizadr -- data ) ( 21.4us)
    8<< OR rdop OR
    SPIWR SPIWR SPIWR SPIRD
    SPICE >B						--- limit to 8-bits
    ;

pub LW@ ( wizadr -- data )
XX
    SPIWR16 DROP					// write address
\    0 SPIWRB DROP 2 SPIWRB DROP				// send count
    2 SPIWR16 DROP
    0 SPIRD SPIRD					// read back data
    SPICE
    ;
pub L@ ( wizadr -- data )
    SPIWR16 DROP					// write address
    4 SPIWR16						// send count
    SPIRD SPIRD SPIRD SPIRD				// read back data
    SPICE
    ;











--- INDIRECT REGISTERS ---


--- Optimize: directly specifiy the address lines I/O to use  ($300  for 3 )

pub WIND ( indreg<<8 -- )				--- set W5100 indirect address lines (2-bits)
	&W51ADDR OUTCLR					--- clear all ind address lines
	OUTSET						--- and set data
;

pub WIND@ ( -- byte )					--- fetch from indirect register
	&W51ADDR WIND					--- only ever need to read from data reg - no addr req
	&W51DATA INPUTS					--- make sure data lines are inputs
	&W51RD DUP OUTCLR				--- read strobe
	P@						--- read in data
	SWAP OUTSET					--- release strobe
	>B						--- only need first 8-bits P0..P7
;


pub WDAT! ( byte -- )					--- 24.8us
	&W51ADDR
pub WIND! ( byte reg<<8 -- )				--- write to 1 of 4 indirect registers
	WIND >B						--- only allow bytes (i/o masking)
	&W51DATA OUTCLR OUTSET				--- write data bus 
	&W51WR DUP OUTCLR OUTSET			--- write strobe - pulse WR low
;

pub WADDR ( addr -- ) --- set the 16-bit address via the indirect registers
     W>B $100 WIND! $200 WIND!
     ;

--- read a byte from anywhere in W5100 memory map
pub LC@ ( addr -- byte ) --- read a byte from a 16-bit W51 address ( 85.4us)
     WADDR WIND@  
     ;
pub LC! ( byte addr -- ) --- write a byte to a 16-bit W51 address
     WADDR WDAT!
     ;

pub LW@ ( addr -- word ) --- read a word from a 16-bit W51 address
     WADDR
pub LW@@ 
     WIND@ WIND@ SWAP B>W
     ;
pub L@ ( addr -- long ) --- read a long from a 16-bit W51 address
     LW@ LW@@ SWAP W>L
     ;

pub LW! ( word addr -- ) --- write a word to a 16-bit W51 address
     WADDR
pub LW!!
     W>B WDAT! WDAT!
     ;
pub L! ( long addr -- ) --- write a long to a 16-bit W51 address
     WADDR
     L>W LW!! LW!!
     ;

--- to do sequential read just issue WADDR then successive  WIND@




{ *** W5100 MEMORY MAP ***
0000-002F    Common Registers
0400-0429    Socket Registers
4000-5FFF    Transmit memory
6000-7FFF    Receive memory
}

--- 140703 - Allow block read/write to access virtual memory if > $8000
LONG vread,vwrite --- maintain a read/write pointer for any virtual memory writes

--- Read a block of memory from the WIZnet - 78ms for 2K block
pub LREAD ( src dst cnt -- )
    ROT ( dst cnt src )
     WADDR
     OVER $7FFF >                        --- physical or virtual address method?
     IF ADO WIND@ I XC! LOOP ELSE ADO WIND@ I C! LOOP THEN
     ;

--- Write a block to the WIZnet - 3.2ms/512 bytes = = 6.25us/byte = 160kB/sec
pub LWRITE ( src dst cnt -- )
    SWAP WADDR
     OVER $7FFF >
     IF ADO I XC@ WDAT! LOOP ELSE ADO I C@ WDAT! LOOP THEN
    ;


--- Use the very top part of the 64K EEPROM to save IP settings
$FF00    ORG
4    DS @gateway
4    DS @sip
4    DS @subnet
4    DS @mac
4    DS @wcold
#16    DS @ports



( SOCKET INTERRUPTS )
4    |< ==     &SENDOK
3    |< ==     &TIMEOUT
2    |< ==     &RECV
1    |< ==     &DISCON
0    |< ==     &CON

{
( SOCKET STATUS CODES )
$00    ==    SOCK_CLOSED
$13    ==    SOCK_INIT 
$14    ==    SOCK_LISTEN
$17    ==    SOCK_ESTABLISHED
$1C    ==    SOCK_CLOSE_WAIT
$22    ==    SOCK_UDP
$32    ==    SOCK_IPRAW
$42    ==    SOCK_MACRAW
$5F    ==    SOCK_PPOE

( SOCKET TRANSIENT STATUS CODES )
$15    ==    SOCK_SYNSENT
$16    ==    SOCK_SYNRECV
$18    ==    SOCK_FIN_WAIT
$1A    ==    SOCK_CLOSING
$1B    ==    SOCK_TIME_WAIT
$1D    ==    SOCK_LAST_ACK
$11    ==    SOCK_ARP
$21    ==    SOCK_ARP1
$31    ==    SOCK_ARP2
}

{
\ is the parallel access really faster than SPI ? on the W5100 ??
W5100 NOTES:
See that W5100 is a lot slower than W5500 although the STROBE is no longer in the kernel so you needed the space, (no room) so that does make access a bit slower too. W5100 uses indirect parallel access but SPI on W5200/5500 is very fast at around 3us/byte whereas the emulated STROBE for indirect parallel is taking 5us alone! PASM space is very tight and I forgot STROBE was used in W5100 but not elsewhere. Also P@ and P! are emulated too as that is never used normally.


141125 - test good
************ NETWORK STATUS ************
HARDWARE: SPINNERET using WIZnet W5100 (indirect mode)
SRC IP    192.168.016.150.
MASK      255.255.255.000.
GATEWAY   192.168.016.001.
MAC       02.FF.F6.FB.98.9D.
*** SOCKETS ***
#0 08:12:06 MODE= TCP  PORT#   21;       TXRW=    .    .RXRW=    .    .RXSZ=    .IR=00 ST=14 LISTEN      
#1 08:12:06 MODE= TCP  PORT#   80;       TXRW=    .    .RXRW=    .    .RXSZ=    .IR=00 ST=14 LISTEN      
#2 08:12:06 MODE= TCP  PORT#10001;       TXRW=    .    .RXRW=    .    .RXSZ=    .IR=00 ST=14 LISTEN      
#3 08:12:06 MODE= IPRW PORT#  511;43024  TXRW=    .    .RXRW=2800.    .RXSZ=    .IR=A8 ST=10

* WEB, FTP, and TELNET servers running *
 ok
 Mounted SD Card
Media mounted as CAC0.660D          NO NAME     FAT32    Cluster size = 2,768   Sectors = 6,320

}

$400             == SOCKET0 --- fixed base for all sockets $400 $500 $600 $700
--- current socket register address offset
$400             == #SOCKET ( -- wizsktbase ) PRIVATE    

WORD socket
--- Set the socket number ( calculates address and sets as a SOCKET constant )
--- mask for 4 sockets (detected by next layer)
pub SKT! socket C! ;  \ MJB 


pub SKT
pub SOCKET ( socket -- )    
     3 AND DUP SKT! 8 SHL SOCKET0 +
     ' #SOCKET 1+ !
;
pub SKT@      socket C@    ;


--- return absolute address of current socket register
pub @SOCKET ( offset -- addr )        #SOCKET + ;

--- Socket registers ( -- addr )
pri sMODE        0 @SOCKET ;        --- mode
pri sCMD!        1 @SOCKET LC! ;    --- command
pri sINTS        2 @SOCKET ;        --- interrupts
pri sSTAT        3 @SOCKET ;        --- status 
pri sPORT        4 @SOCKET ;        --- 2 byte src port
pri sDHAR        6 @SOCKET ;        --- 6 byte dest hardware address
pri sDIP        $0C @SOCKET ;    --- 4 byte dest IP address
pri sDPORT        $10 @SOCKET ;    --- 2 byte dest port
pri sSSIZE        $12 @SOCKET ;    --- 2 byte dest max seg size
pri sPRO        $14 @SOCKET ;    --- protocol in IP raw mode
pri sTOS        $15 @SOCKET ;    --- 
pri sTTL        $16 @SOCKET ;    --- 
pri TXFREE@        $20 @SOCKET LW@ ;
pri TXREAD        $22 @SOCKET ;
pri TXWRITE        $24 @SOCKET ;
pri RXSIZE@        $26 @SOCKET LW@ ;
pri RXREAD        $28 @SOCKET ;

--- Protocol modes
pri CLOSED        0 sMODE LC! ;
pub TCP        1 sMODE LC! ;
pub UDP        2 sMODE LC! ;
pri IPRAW        3 sMODE LC! ;
pri MACRAW        4 sMODE LC! ;
pri PPPoE        5 sMODE LC! ;

[PRIVATE
$4000        == TXBASE0
$07FF        == TXMASK0
$6000        == RXBASE0
$07FF        == RXMASK0
PRIVATE]

pub @TXBASE ( -- addr )
     TXBASE0
 pub @BASE ( addr0 -- addr )
     SKT@ #11 SHL +
     ;

--- common registers

--- Access common registers
pub wMODE ( mask -- )        0 LC! ;
pub GATEWAY ( addr -- )        DUP @gateway E! 1 L! ;
pub SUBNET ( mask -- )        DUP @subnet E! 5 L! ;
pub MAC ( high low  -- )    DUP @mac E! $0B L! 9 LW! ;
pub SIP ( long -- )        DUP @sip E! $0F L! ;


pri INTS@ ( -- ints )        $15 LC@ ;
pri INTMASK ( mask -- )        $16 LC! ;
pri RETRYTIME ( val -- )    $17 LW! ;
pri RETRYS ( cnt -- )        $19 LC! ;
pri RXSIZ ( mask -- )        $1A LC! ; --- default sets 2K for each socket (%01010101)
pri TXSIZ ( mask -- )        $1B LC! ;

pri UIP ( ip -- )            $2A L! ;
pri UPORT ( port -- )        $2E LW! ;




( SOCKET COMMANDS - use currently select socket )
pub sOPEN		1 sCMD! ; 
pub sLISTEN		2 sCMD! ;
pub sCONNECT            4 sCMD! ;
pub sDISCON		8 sCMD! ;
pub sCLOSE		$10 sCMD! ;
pub sSEND		$20 sCMD! ;
pub sSENDMAC		$21 sCMD! ;
pub sSENDKEEP		$22 sCMD! ;
pub sRECV		$40 sCMD! ;

--- from W5200 MJB
pri sCLOSED?		sSTAT LC@ 0= ;
pri sINACTIVE?		sSTAT LC@ $17 < ;
pri sESTAB?		sSTAT LC@ $17 = ;
pri sCLOSING?		sSTAT LC@ $18 $1B WITHIN ;            --- closing or wait closing
pri sCONNECTED?		sINTS LC@ &CON AND   &CON sINTS LC! ;     --- Test and reset the connection interrupt;
pri sDISCON?		sINTS LC@ &DISCON AND -1 sINTS LC! ;
---  MJB  not sure if this is all the same on W5100 


pub PORT! ( srcport -- ) --- save port config and set port        
     DUP SKT@ 2* 2* @ports + E! 
pub SetPORT
     sPORT LW!
     ;



( Set the factory defaults on very first run - generate a random MAC in the 01.FF.xx.xx.xx.xx range )
pub WCOLD
    CR PRINT" Setting default IP configuration "
     myGW @gateway E!
     myIP @sip E!
     mySN @subnet E!
     RND @mac E!			--- calculate a random MAC on first boot.
     1 SKT #21 PORT!			--- default ftp port
     2 SKT #80 PORT!			--- default web port
     3 SKT #23 PORT!			--- default Telnet port
     $A55A @wcold E!
     ;



--- Init the SPI for the WIZnet chip
pub !WIZIO
    !PCB
    &W51RST OUTCLR			--- start HW reset
    &W51OUTS OUTSET			--- leave all outputs high
     &W51SEN OUTCLR			--- select parallel mode
     5 us				--- at least 2us for reset
      &W51RST OUTSET			--- finish HW reset
     #10 ms				--- do some extra delay until internal PCLOCK
     3 0 WIND!				---  set indirect mode and auto increment mode
    ;


$02FF == oui2

pub !WIZIP
	@wcold E@ $A55A <> IF WCOLD THEN
	@gateway E@ GATEWAY					--- Assign a default gateway
	@subnet E@ SUBNET
	@sip E@ SIP
	oui2 @mac E@ MAC					--- random MAC at first run, Need to have a unique ID    
	4 0 DO I 2* 2* @ports + E@ I SOCKET SetPORT LOOP
	autosend C~~						--- preset to autosend
;


pri !TXBUFS     $4000 $2000 ADO 0 I L! 4 +LOOP ;

$800    == WBUFSZ

{ Since the W5100 read and write index registers are unreadable until a connection has been established
or cannot be written incrementally until a send then these are buffered for when they become readable

to be determined for W5100
} 

4 LONGS txwr PRIVATE						--- tx write buffers for 4 sockets 

pub @txwr ( -- addr )       txwr SKT@ 2* 2* + ;

pub !TXWR    txwr 16 $FF FILL ;					--- invalidate all txwr pointers (WIZnet workaround)

pub !WIZ    !WIZIO #150 ms !TXBUFS !WIZIP !TXWR ;

LONG     txtime,txsize
BYTE     autosend						--- Flag to control whether LANSEND sends when it receives a LF or not

TIMER sendtimer PRIVATE

--- Request WIZnet to send off current transmit data in buffer
pub ?SENDPOLL
    runtime @ txtime @ - 8 > 0EXIT				--- 8ms timeout since last
pub ?SEND							--- check to see if anything still needs to be sent
     txsize @ 0EXIT						--- Exit if buffer empty
pub LANSEND
     &SENDOK sINTS LC!						--- Clear send interrupt
     @txwr W@ TXWRITE LW! sSEND					--- update TXWRITE register and command WIZnet to SEND
pri WAITSEND
     txsize @ 0EXIT						--- don't bother if it's empty
     #5000 sendtimer TIMEOUT					--- give it some time to send what it has
     BEGIN 
       sINTS LC@ &SENDOK AND					--- until sent
       TXREAD LW@ TXWRITE LW@ = AND
       sendtimer TIMEOUT? OR					--- or until timeout  
     UNTIL 
     &SENDOK sINTS LC!						--- reset the sent interrupt flag
      txsize ~							--- reset txsize (buffer empty)
     ;

--- Transmit up to one complete sector (512 bytes) or less (cnt)

--- Update TXWRITE and send what we have in the buffer and waiting for completion
pri (LSEND) ( src cnt -- )
    sINACTIVE? IF 2DROP EXIT THEN				--- skip if socket is/has closed 
    @TXBASE @txwr W@ TXMASK0 AND + ( src cnt dst )		--- add in the current txbuffer write index
    SWAP DUP @txwr W+!
    LWRITE ( hsrc wdst cnt -- )					--- Write the full count - won't wrap around
     txsize ~~							--- force WAITSEND to process (140926) 
    LANSEND
    ;
pri LSEND ( src cnt -- )
     -1 sINTS LC!						---  clear interrupts ?  MJB need for W5100 as well ? yes, but NU
    TXWRITE LW@ TXMASK0 AND OVER + WBUFSZ >			--- figure out if there is a wraparound
    IF
      WBUFSZ @txwr W@ TXMASK0 AND -				--- find 1st cnt      
      SWAP OVER - SWAP ( src cnt2 cnt1 )			--- adjust cnt for 2nd
      ROT 2DUP + SWAP ROT ( cnt2 src2 src cnt1 )
      (LSEND) SWAP
    THEN
    (LSEND)
    ;

---  Read from WIZnet buffer into file until buffer is exhausted - used by FTP STOR
pri LREADSKT ( dst -- )
    vwrite !
    BEGIN
      RXSIZE@ ?DUP
    WHILE ( cnt )
      RXREAD LW@ RXMASK0 AND ( cnt index )			--- fetch receive read index for this socket
      RXBASE0 @BASE + ( cnt wizptr )				--- calc buffer address
      RXBASE0 @BASE WBUFSZ + ( cnt wizptr wizend )		--- limit to end of buffer - can't wrap
      OVER - ( cnt wizptr rem )
      ROT MIN ( wizptr mincnt )
      vwrite @ SWAP ( wizptr filedst cnt )
      DUP >R
      LREAD vwrite ++						--- read WIZnet buffer directly into file and update vwrite+1
      R> RXREAD LW@ + RXREAD LW!				--- update read index in advance
      sRECV							--- signal that buffer up to READ index has been read
      #10 ms
    REPEAT
    ;   

--- CHARACTER MODE I/O ---


--- send out a character through the WIZnet - either block mode or autosend
pub LANEMIT ( ch -- )
     #100 sendtimer TIMEOUT					--- retrigger timeout even in "block" mode
    @txwr @ -1 = IF TXWRITE LW@ @txwr ! THEN			--- force an update (assumed valid) if the index is "invalid"
     @txwr W@ TXMASK0 AND					--- mask it according to buffer size (default 2K)
    @TXBASE +							--- write pointer
    OVER SWAP LC!						--- write character to buffer
      @txwr W++							--- CNT@ txtime !
     runtime @ txtime !						--- remember when the last char was sent


     txsize ++
    $0A = autosend C@ AND					--- SEND if this is an end of line and autosend is active
     txsize @ WBUFSZ $10 - > OR					--- AUTOSEND if buffer almost full. 
      IF LANSEND THEN
    ;

pub LANKEY ( -- ch )
     RXSIZE@ 
     IF 
       RXREAD LW@ 
        RXBASE0 @BASE OVER RXMASK0 AND + LC@			--- read a character from the receive buffer
       SWAP 1+ RXREAD LW! sRECV					--- update read index
     ELSE 
       keypoll W@ ?DUP IF CALL THEN				--- implement a keypoll for when LANKEY is doing nothing
       0							--- return with a null character
     THEN 
    ;

( Redirect console output to the LAN )
pub LAN     
	' LANEMIT uemit W! 
	' LANKEY ukey W! 
;

( diagnostic to the terminal to reflect what is begin typed to the LAN )
pub LCEMIT
    DUP (EMIT) LANEMIT
    ;
{
IFDEF KEY?
( allow input from both the serial console and the LAN socket )
pub LCKEY ( -- ch )
    LANKEY KEY? AND OR
    ;
}
IFNDEF KEY?
( allow input from both the serial console and the LAN socket )
pub LKEY ( -- ch )
    LANKEY KEY OR
    ;
}

pub LANCON     
    CON CR LAN
     ' LCEMIT uemit W!
    ;




--- select WIZ device for DUMP access
pub WIZ    ' LC@ mc@ W! ' LW@ mw@ W! ' L@ m@ W! ;


$30 BYTES sktbuf

pri @SKTBUF         sktbuf + ;

pri .IPX    DUP >B $30A .NUM "." EMIT 8 SHR ;
pri .IP ( off -- )
     DECIMAL 3 SPACES 
pub .IP1
     @SKTBUF U@ 
    .IPX .IPX .IPX .IPX DROP
    ;


pri .@SKTBUF        @SKTBUF
pri .PTR              C@++ 8 SHL SWAP C@ + ( $7FF AND ) $2410 .NUM "." EMIT ;

IFNDEF SWAPB
pri SWAPB ( word -- word2     --- Swap the bytes in a 16-bit word )
     DUP 8 SHR SWAP >B 8 SHL OR
     ;
}


pub .SKTHD        CR BOLD PRINT" SKT HH:MM:SS MODE  PORT  DEST TXRD TXWR RXRD RXWR RXSZ  IR STATUS            IP ADDR" PLAIN ;


pub .SOCKET ( n -- )
    .SKTHD
pub .SKT
    DUP 8 SHL SOCKET0 + sktbuf $30 LREAD
    0 @SKTBUF C@ IF CR "#" EMIT . 2 SPACES .TIME ELSE DROP EXIT THEN
    0  @SKTBUF C@ SPACE
      4 * " CLSDTCP UDP IPRWMACRPPP !06!!07!" + 4 CTYPE SPACE
    4 @SKTBUF W@ SWAPB $250A .NUM SPACE                    --- PORT
    16 @SKTBUF W@ SWAPB $250A .NUM SPACE                 --- DPORT
    $22 .@SKTBUF $24 .@SKTBUF                        --- TXRD TXWR
    $28 .@SKTBUF $2A .@SKTBUF                        --- RXRD RXWR
    $26 .@SKTBUF SPACE                            --- RX SIZE
     2 @SKTBUF C@ .BYTE SPACE                        --- INT REG
    3 @SKTBUF C@ DUP .BYTE                            --- STATUS REG
\    pri .SSTAT ( byte -- )                            --- STATUS DESCRIPTION
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
pub .NET
    0 sktbuf $30 LREAD    --- read in common registers
    BOLD
    CR PRINT" ************ NETWORK STATUS ************ " PLAIN
\\\    CR PRINT" LINK "         1 $2E @SKTBUF SET? IF PRINT" *UP*" ELSE PRINT" DOWN" THEN  
    CR PRINT" HARDWARE: " PCB$ PRINT$ PRINT"  using WIZnet W5100 (indirect)"
    CR PRINT" SRC IP "    $0F .IP
    CR PRINT" MASK   "    5 .IP
    CR PRINT" GATEWAY"    1 .IP
    CR PRINT" MAC       "    9 @SKTBUF 6 ADO I C@ .BYTE PRINT" ." LOOP
pub .SOCKETS
    .SKTHD 4 0 DO I .SKT LOOP CR
    ;


--- SOCKETS
0    == FTPDAT
1    == FTP
2    == HTTP
3    == TELNET
" DATFTPWEBTEL" 0 STRING skt$


{ testing 

!WIZIO  ok
!WIZIP  ok
.NET 
************ W5100 STATUS ************ 
LINK DOWN
CHIP VER  0000
SRC IP    192.168.016.150.
MASK      255.255.255.000.
GATEWAY   192.168.016.001.
MAC       02.FF.0B.FA.F3.78.
*** SOCKETS *** 
#0 11:51:05 MODE= CLSD PORT#             TXRW=    .    .RXRW=    .    .RXSZ=    .IR=00 ST=00 CLOSED      
#1 11:51:05 MODE= CLSD PORT#             TXRW=    .    .RXRW=    .    .RXSZ=    .IR=00 ST=00 CLOSED      
#2 11:51:05 MODE= CLSD PORT#             TXRW=    .    .RXRW=    .    .RXSZ=    .IR=00 ST=00 CLOSED      
#3 11:51:05 MODE= CLSD PORT#             TXRW=    .    .RXRW=    .    .RXSZ=    .IR=00 ST=00 CLOSED      
 ok

SYSTEM BUILD - CREATE SMALL - load EXTEND, SPINNERET, SDCARD etc
MODULES LOADED: 
400C: EASYNET.fth         WIZNET NETWORK SERVERS 140517.0100 
38B5: W5100.fth           WIZNET W5100 driver 140613.0000 
2E8B: EASYFILE.fth        FAT32 Virtual Memory Access File System Layer V1.1 140528-0000 
29D0: SDCARD.fth          SD CARD Toolkit - 140121.2200 
286D: SPINNERET.fth       Spinneret + W5100 HARDWARE DEFINITIONS 131204.1200 
1881: EXTEND.fth          Primary extensions to TACHYON kernel - 140604-02OO
BOOT: EXTEND.boot


}

]~
END
?BACKUP


