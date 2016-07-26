TACHYON
[~

FORGET W5200.fth
pub W5200.fth        PRINT" WIZNET W5200 driver 140928.0000 " ;


--- some default IP settings that are only loaded in on a new pcb and if storage locations in upper eeprom is blank
&192.168.16.1		== myGW
&192.168.16.150		== myIP
&255.255.255.0		== mySN

{                  *** WIZnet W5200 driver ***

Implements the SPI interface to the WIZnet W5200 including the primitives to talk to the chip 

CHANGELOG:
160513	  Optimized low level SPI interface
160510	  Updated to 2.8 kernel
140928    Fixed bugs in WAITSEND - buffer could be overwritten before sent
140823    Fixed LANEMIT TXWRITE bug (inc to FFFF then reloads @txwr from TXWRITE)
140818    Removed all W5100 specifics from EASYNET
140730    Replace all WIZNET fetch and stores with faster individual words.
140403    Optimized code
140210    Optimized code, SPIWR16
140206    
131211    Added timed autosend and also buffer full autosend (SERVER polls ?SEND)


MODULE INFO:
NAMES:  $527E...7309 for 8331 (0945 bytes added)
CODE:   $0000...46F3 for 9832 (1652 bytes added)
CALLS:  0231 vectors free
RAM:    2955 bytes free


NOTE: Refresh webpage for latest version
}



( HARDWARE DEFINITIONS )


IFNDEF &WNCS                    --- Use these if none have been defined yet
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


{ WIZnet setup on a CE1372 
The interrupt signal can be read from MOSI by floating MOSI and reading the state
Only 4 Propeller I/O are required to interface to the WIZnet W5200 rather than 7 I/O
}


( Additional hardware as used on CE1372 for reset and power-down )




( Diagram: WIZnet SPI timing ) 


{
3. Write target address for transmission on SPDR register (SPI Data Register).
4. Write OP code and data length for transmission on SPDR register.
5. Write desired data for transmission on SPDR register.
6. Configure nSCS as ‘Low’ (data transfer start)
7. Wait for reception complete
8. If all data transmission ends, configure nSCS as ‘High’

}

( W5200 SPI ACCESS WORDS )

pub LC! ( byte wizadr -- ) ( 25.4us )
    SPIWR16 DROP					// write address
    $8001 SPIWR16 DROP					// Write OP + count of 1 byte
    SPIWRB DROP						// write the byte
    SPICE
    ;
pub LW! ( word wizadr -- )
    SPIWR16 DROP					// write address
    $8002 SPIWR16 DROP					// Write OP + count of 2 bytes
    SPIWR16 DROP
    SPICE
    ;
pub L! ( long wizadr -- )
    SPIWR16 DROP					// write address
    $8004 SPIWR16 DROP					// write OP + count of 4 bytes
    SPIWR SPIWR SPIWR SPIWR DROP
    SPICE
    ;


pub LC@ ( wizadr -- data ) ( 21.4us)
    SPIWR16 DROP					// write address
    \ 0 SPIWRB DROP 1 SPIWRB				// send count
    1 SPIWR16
    SPIRD						// read back data
    SPICE >B						--- limit to 8-bits
    ;
pub LW@ ( wizadr -- data )
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

{ *** W5200 MEMORY MAP ***
0000-0036    Common Registers
4000-4FFF    Socket Registers
8000-BFFF    Transmit memory
C000-FFFF    Receive memory
}

( VIRTUAL MEMORY ACCESS )
--- 140703 - Allow block read/write to access virtual memory if > $8000
LONG vread,vwrite --- maintain a read/write pointer for any virtual memory writes


--- Read a block of memory from the WIZnet
--- if dst is > $8000 then use virtual memory
pub LREAD ( src dst cnt -- )
    ROT SPIWR16 DROP ( dst cnt)				--- transmit src address 
     DUP SPIWR16 DROP ( dst cnt )			--- transmit count
     OVER $7FFF >					--- select either RAM or virtual memory method
     IF  
       2DUP + vwrite ! 
         ADO 0 SPIRD I XC! LOOP 
       ELSE 
         ADO 0 SPIRD I C! LOOP 
       THEN
    SPICE
    ;

\ Write a block to the WIZnet - 3.2ms/512 bytes = = 6.25us/byte = 160kB/sec
pub LWRITE ( src dst cnt -- )
    SWAP
    SPIWR16 DROP					--- Send address
     DUP $8000 + SPIWR16 DROP				--- send total count
    ( src cnt ) ADO I C@ SPIWRB DROP LOOP		--- now just send the bytes sequentially
     SPICE 
    ;


( ----------------------------------- REGISTER LEVEL INTERFACE -------------------------------- )

\ Use the top part of the 64K EEPROM to save IP settings
$FF00    ORG
4	DS @gateway
4	DS @sip
4	DS @subnet
4	DS @mac
4	DS @wcold
#32	DS @ports



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

--- current socket register address offset - set a default
$4000 == #SOCKET PRIVATE        
WORD socket

--- Set the socket number ( calculates address and sets as a SOCKET constant )
pub SKT
pub SOCKET ( socket -- )        DUP socket C! $40 + 8<< ' #SOCKET 1+ ! ;
pub SKT@                 socket C@ ;
pub @SOCKET                #SOCKET + ;

--- SOCKET REGISTERS ( -- addr )
pri sMODE        0 @SOCKET ;        --- mode
pri sCMD!        1 @SOCKET LC! ;    --- command
pri sINTS        2 @SOCKET ;        --- interrupts
pri sSTAT        3 @SOCKET ;        --- status 
pri sPORT        4 @SOCKET ;        --- 2 byte src port
pri sDHAR        6 @SOCKET ;        --- 6 byte dest hardware address
pri sDIP        $0C @SOCKET ;        --- 4 byte dest IP address
pri sDPORT      $10 @SOCKET ;        --- 2 byte dest port
pri sSSIZE      $12 @SOCKET ;        --- 2 byte dest max seg size
pri sPRO        $14 @SOCKET ;        --- protocol in IP raw mode

pri sRXMEM      $1E @SOCKET ;
pri sTXMEM      $1F @SOCKET ;
pri TXFREE@     $20 @SOCKET LW@ ;
pri TXREAD      $22 @SOCKET ;
pri TXWRITE     $24 @SOCKET ;
pri RXSIZE@     $26 @SOCKET LW@ ;
pri RXREAD      $28 @SOCKET ;
pri RXWRITE     $2A @SOCKET ;

--- Protocol modes
pri CLOSED	0 sMODE LC! ;
pub TCP		1 sMODE LC! ;
pub UDP		2 sMODE LC! ;
pri IPRAW       3 sMODE LC! ;
pri MACRAW      4 sMODE LC! ;
pri PPPoE       5 sMODE LC! ;

[PRIVATE
$8000            == TXBASE0
$07FF            == TXMASK0
$C000            == RXBASE0
$07FF            == RXMASK0
PRIVATE]


pub @TXBASE ( -- addr )
     TXBASE0
 pub @BASE ( addr0 -- addr )
     SKT@ #11 SHL +
     ;

--- common registers

( Set common registers and backup into high EEPROM )
pub wMODE ( mask -- )		0 LC! ;
pub GATEWAY ( addr -- )		DUP @gateway E! 1 L! ;
pub SUBNET ( mask -- )		DUP @subnet E! 5 L! ;
pub MAC ( high low  -- )        DUP @mac E! $0B L! 9 LW! ;
pub SIP ( long -- )		DUP @sip E! $0F L! ;


pri INTS@ ( -- ints )		$15 LC@ ;
pri INTMASK ( mask -- )		$16 LC! ;
pri RETRYTIME ( val -- )        $17 LW! ;
pri RETRYS ( cnt -- )		$19 LC! ;
pri RXSIZ ( mask -- )		$1A LC! ;     --- default sets 2K for each socket (%01010101)
pri TXSIZ ( mask -- )		$1B LC! ;


$17	== @RTR
$19	== @RCR



pri UIP ( ip -- )		$2A L! ;
pri UPORT ( port -- )		$2E LW! ;




( SOCKET COMMANDS - use currently select socket )
pub sOPEN			1 sCMD! ; 
pub sLISTEN			2 sCMD! ;
pub sCONNECT			4 sCMD! ;
pub sDISCON			8 sCMD! ;
pub sCLOSE			$10 sCMD! ;
pub sSEND			$20 sCMD! ;
pub sSENDMAC			$21 sCMD! ;
pub sSENDKEEP			$22 sCMD! ;
pub sRECV			$40 sCMD! ;


pri sCLOSED?			sSTAT LC@ 0= ;
pri sINACTIVE?			sSTAT LC@ $17 < ;
pri sESTAB?			sSTAT LC@ $17 = ;
pri sCLOSING?			sSTAT LC@ $18 $1B WITHIN ;    --- closing or wait closing
pri sCONNECTED?			sINTS LC@ &CON AND   &CON sINTS LC! ; --- Test and reset the connection interrupt;
pri sDISCON?			sINTS LC@ &DISCON AND -1 sINTS LC! ;


pub PORT! ( srcport -- ) --- save port config and set port        
     DUP SKT@ 2* 2* @ports + E! 
pub SetPORT
     sPORT LW!
     ;

--- default buffer sizes are 2K, leave it at that
$800    == WBUFSZ

{ Since the W5200 read and write index registers are unreadable until a connection has been established
or cannot be written incrementally until a send then these are buffered for when they become readable
} 

8 LONGS txwr PRIVATE                        --- tx write buffers for 8 sockets - longs to hold invalid flag

pub @txwr ( -- addr )       txwr SKT@ 2* 2* + ;

pri !TXWR    txwr BL $FF FILL ;                --- invalidate all txwr pointers (W5200 workaround)






LONG     txtime,txsize
BYTE     autosend                            // Flag to control whether LANSEND sends when it receives a LF or not

TIMER sendtimer PRIVATE


// Request WIZnet to send off current transmit data in buffer
pub ?SENDPOLL
    runtime @ txtime @ - 8 > 0EXIT                // 8ms timeout since last
pub ?SEND                                // check to see if anything still needs to be sent
     txsize @ 0EXIT                        // Exit if buffer empty
pub LANSEND
    &SENDOK sINTS LC!                        // Clear send interrupt
    @txwr W@ TXWRITE LW! sSEND                    // update TXWRITE register and command WIZnet to SEND
pri WAITSEND     
     txsize @ 0EXIT                         // don't bother if it's empty
    #10,000 sendtimer TIMEOUT                    // give it some time to send what it has
    BEGIN 
       sINTS LC@ &SENDOK AND                     // until sent - check SENDOK interrupt flag
       TXREAD LW@ TXWRITE LW@ = AND                // and the buffer is fully sent
         ( could also check other int flags for timeout )
       sendtimer TIMEOUT? OR                     // or until timeout  
     UNTIL 
    &SENDOK sINTS LC!                        // reset the sent interrupt flag
       txsize ~                             // reset txsize (buffer empty)
     ;


// Transmit up to one complete sector (512 bytes) or less (cnt)

// Update TXWRITE and send what we have in the buffer and waiting for completion
pri (LSEND) ( src cnt -- )
    sINACTIVE? IF 2DROP EXIT THEN			--- skip if socket is/has closed 
    @TXBASE @txwr W@ TXMASK0 AND + ( src cnt dst )      --- add in the current txbuffer write index
    SWAP DUP @txwr W+!					--- update txwr with count
    LWRITE ( hsrc wdst cnt -- )				--- Write the full count - won't wrap around
     txsize ~~						--- force WAITSEND to process (140926)
    LANSEND						--- send what we've got and wait for it
    ;

// SEND file 
pri LSEND ( src cnt -- )
     -1 sINTS LC!
    TXWRITE LW@ TXMASK0 AND OVER + WBUFSZ >		--- figure out if there is a wraparound
    IF
      WBUFSZ @txwr W@ TXMASK0 AND -			--- find 1st cnt      
      SWAP OVER - SWAP ( src cnt2 cnt1 )		--- adjust cnt for 2nd
      ROT 2DUP + SWAP ROT ( cnt2 src2 src cnt1 )
      (LSEND) SWAP
    THEN
    (LSEND)
    ;

//  Read from WIZnet buffer into file until buffer is exhausted - used by FTP STOR
pri LREADSKT ( dst -- )
    vwrite !
    BEGIN
      RXSIZE@ ?DUP
    WHILE ( cnt )
      RXREAD LW@ RXMASK0 AND ( cnt index )             // fetch receive read index for this socket
      RXBASE0 @BASE + ( cnt wizptr )                 // calc buffer address
      RXBASE0 @BASE WBUFSZ + ( cnt wizptr wizend )         // limit to end of buffer - can't wrap
      OVER - ( cnt wizptr rem )
      ROT MIN ( wizptr mincnt )
      vwrite @ SWAP ( wizptr filedst cnt )
      DUP >R
      LREAD vwrite ++                         // read WIZnet buffer directly into file and update vwrite+1
      R> RXREAD LW@ + RXREAD LW!                 // update read index in advance
      sRECV                             // signal that buffer up to READ index has been read
      #10 ms
    REPEAT
    ;   

--- CHARACTER MODE I/O ---

// send out a character through the WIZnet - either block mode or autosend
pub LANEMIT ( ch -- )
     #100 sendtimer TIMEOUT                    // retrigger timeout even in "block" mode
    @txwr @ -1 = IF TXWRITE LW@ @txwr ! THEN            // force an update (assumed valid) if the index is "invalid"
     @txwr W@ TXMASK0 AND                        // mask it according to buffer size (default 2K)
    @TXBASE +                            // calc write pointer
    OVER SWAP LC!                            // write character to buffer
      @txwr W++
     runtime @ txtime !                        // remember when the last char was sent
     txsize ++
    $0A = autosend C@ AND                    // SEND if this is an end of line and autosend is active
     txsize @ WBUFSZ $10 - > OR                     // AUTOSEND if buffer almost full.
      IF LANSEND THEN
    ;


pub LANKEY ( -- ch )
     RXSIZE@ 
     IF 
       RXREAD LW@ 
       RXBASE0 @BASE OVER RXMASK0 AND + LC@             // read a character from the receive buffer
       SWAP 1+ RXREAD LW! sRECV                     // update read index
     ELSE 
       keypoll W@ ?DUP IF CALL THEN                 // implement a keypoll for when LANKEY is doing nothing
       0                                 // return with a null character
     THEN 
    ;

( Redirect console output to the LAN )
pub LAN     
    ' LANEMIT uemit W! 
     ' LANKEY ukey W! 
    ;

( diagnostic to the terminal to reflect what is being typed to the LAN )
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
pub LCKEY ( -- ch )
     LANKEY KEY OR
     ;
}
}


pub LANCON     
    CON CR LAN
     ' LCEMIT uemit W! 
    ;






( Set the factory defaults on very first run - generate a random MAC in the 01.FF.xx.xx.xx.xx range )
pub WCOLD
    CR PRINT" Setting default IP configuration "
     myGW @gateway E!
     myIP @sip E!
     mySN @subnet E!
     RND @mac E!                     --- random MAC at first run, Need to have a unique ID    
     8 0 DO #80 I 2* 2* @ports + E! LOOP
     $A55A @wcold E!
     ;

\ Init the SPI for the WIZnet chip
pub !WIZIO
    !PCB
    wizpins SPIPINS                    --- Use SPI     
    &WNCK OUTCLR                    --- Clock is an output - leave low
    &WNDI OUTCLR                    --- MOSI is an output
    ON WRESET OFF WPWRDN OFF WRESET
     ;

--- Default OUI2 for generated MAC address
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



---  clear WIZnet transmit buffers (for diagnostics)
pri !TXBUFS     $8000 $4000 ADO 0 I L! 4 +LOOP ;

--- Init WIZ I/O and IP settings etc
pub !WIZ    !WIZIO #150 ms !TXBUFS !WIZIP !TXWR  ;





--- redirect memory fetch methods (used by DUMP) to WIZ chip 
pub WIZ    ' LC@ dmm W! ' LW@ dmm 2+ W! ' L@ dmm 4 + W! ;





$40 BYTES sktbuf             --- buffer socket registers here for a socket from the WIZnet

pri @SKTBUF ( offset -- addr )         sktbuf + ;


pri .IPX    DUP >B $30A .NUM "." EMIT 8>> ;
pri .IP ( off -- )
     DECIMAL 3 SPACES 
pub .IP1
     @SKTBUF U@ 
    .IPX .IPX .IPX .IPX DROP
    ;


pri .@SKTBUF    @SKTBUF
pri .PTR          C@++ 8<< SWAP C@ + ( $7FF AND ) $2410 .NUM "." EMIT ;

IFNDEF SWAPB
pri SWAPB ( word -- word2     \ Swap the bytes in a 16-bit word )
     DUP 8>> SWAP >B 8<< OR
     ;
}

pub .SOCKET ( n -- )
	DUP 8<< #SOCKET + sktbuf $30 LREAD
	CR "#" EMIT . SPACE .TIME
	0  @SKTBUF C@ ( PRINT"  MODE=" ) SPACE
	4 * " CLSDTCP UDP IPRWMACRPPP !06!!07!" + 4 CTYPE
	PRINT"  PORT#" 4 @SKTBUF W@ SWAPB $250A .NUM ";" EMIT 16 @SKTBUF W@ SWAPB $250A .NUM SPACE 
	PRINT"  TX" $22 .@SKTBUF $24 .@SKTBUF 
	PRINT"  RX" $28 .@SKTBUF $2A .@SKTBUF 
     ( PRINT" RXSZ=" $26 .@SKTBUF )
	PRINT" IR=" 2 @SKTBUF C@ .BYTE
	PRINT"  ST=" 3 @SKTBUF C@ DUP .BYTE 
\    pri .SSTAT ( byte -- )
	SWITCH SPACE
	0 CASE PRINT" closed     " BREAK
	$13 CASE PRINT" INIT       " BREAK
	$14 CASE PRINT" LISTEN     " BREAK
	$16 CASE PRINT" SYNRECV    "  $0C .IP BREAK
	$17 CASE PRINT" ESTABLISHED"  $0C .IP BREAK
	$18 CASE PRINT" FIN WAIT   "  $0C .IP BREAK
	$1C CASE PRINT" closed wait" BREAK
	$22 CASE PRINT" UDP OPEN   " BREAK
	$32 CASE PRINT" IPRAW OPEN " BREAK
     ;


pub ifconfig
pub .NET
    CR PRINT" ************ NETWORK STATUS ************ "
     CR PRINT" HARDWARE: " PCB$ PRINT$ PRINT"  using WIZnet W5200 "
     0 sktbuf $40 LREAD    \ read in common registers
    CR PRINT" LINK " 5 MASK $35 @SKTBUF SET? IF PRINT" *UP*" ELSE PRINT" DOWN" THEN  
    CR PRINT" CHIP VER  " $1F @SKTBUF C@ .DEC
    CR PRINT" SRC IP "    $0F .IP
     CR PRINT" MASK   "    5 .IP
     CR PRINT" GATEWAY"    1 .IP
    CR PRINT" MAC       "    9 @SKTBUF 6 ADO I C@ .BYTE PRINT" ." LOOP
pub .SOCKETS
    CR PRINT" *** SOCKETS *** "
     8 0 DO I .SOCKET LOOP
     CR
    ;

\ SOCKETS - W5200 has 8 sockets - define 4 of them
0    == NETMAN --- network management
1    == FTP
2    == FTPDAT
3    == TELNET
4    == HTTP --- uses sockets 4..7
" NETFTPDATTELWEBWEBWEBWEB" 0 STRING skt$


--- NOTE: Use WIZ DUMP or variation thereof instead of WDUMP



]~
END


