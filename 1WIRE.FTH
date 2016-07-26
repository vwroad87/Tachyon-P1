TACHYON [~ DECIMAL

    FORGET 1WIRE+.fth
pub 1WIRE+.fth                ." 1-wire interface + support & diagnostics 150520:0000 PBJ,MJB" ;

{
The 1-Wire interface is implemented in bytecode so it does not require a special cog to handle the timing. 
Testing has been done on DS1820+ and DS2450S+ chips as well as others
CHANGELOG:
150520 - Merged MJBs code and enhanced
121025
Fixed bugs in routines
Added strong pullup after writing to provide power for parasitic devices
Add some of Brian Riley's code
Allow for redirection of DQ line

Google pub doc is at https://docs.google.com/document/d/1wJSI3-ozTeEEtfLECTXEzE20lFyVLavdwmCv_z7Ftg0/pub
}

--- I/O DEFINITIONS ---

BYTE 1Wpin

pri 1W.PIN@                    1Wpin C@ MASK ;

--- Set the pin to be used by the 1-wire bus
pub 1W.PIN ( pin# -- )            1Wpin C! ;

#P14 1W.PIN                        --- set a default


--- RESET 1-WIRE BUS ---


pub 1W.RESET ( -- ack )        
        1W.PIN@ OUTCLR 1 ms
    1W.PIN@ INPUTS 60 us
        1W.PIN@ IN 0= 400 us
        ;

     --- 1-wire read and write ---


--- Write lsb to 1wire bus and shift data right
pub 1W.BITWR ( iomask dat -- iomask dat/2 )
    OVER OUTCLR                    --- pulse low for 1us
    SHROUT 60 us                    --- output next data bit then shift data right + min cycle
    OVER OUTSET                    --- Force line high at end of slot (rather than float)
    ;


pub 1W.BITRD ( iomask dat -- iomask dat+ )
    OVER OUTCLR OVER INPUTS                --- pulse line low for 1us then float
    8 us SHRINP                    --- assemble another bit by right shifting
    50 us    ( MJB )
    OVER OUTSET                    --- Force line high at end of slot (rather than float)
    ;
    
--- Transmit 8-bit lsb first
pub 1W! ( dat -- )
    1W.PIN@ SWAP                   --- mask and data ( iomask dat )
      8 FOR 1W.BITWR NEXT               --- write 8 bits lsb first
    2DROP                       --- discard mask and used data
    ;
--- Receive 8-bit data lsb first
pub 1W@ ( -- dat )
    1W.PIN@ 0                        --- initial mask and data ( iomask dat )
      8 FOR 1W.BITRD 45 us NEXT
    NIP 24 SHR                        --- right justify ( dat )
    ;

--- Get bytes from bus and print as hex bytes
pub .1W ( cnt -- )    FOR 1W@ .BYTE SPACE NEXT ;
--- send read ROM command code
pub READROM        $33 1W! ;  
--- send skip ROM command code
pub SKIPROM        $CC 1W! ;  
--- command to match an ID to a specific device
pub MATCHROM        $55 1W! ;  
--- commands all Temp sensors to start measurement (750 ms)
pub CONVERTT        $44 1W! ;  
--- read scratchpad
pub READSCR        $BE 1W! ;  
--- reset, skip ROM for single sensor on bus only THEN prepare for next command
pub 1WSCMD        1W.RESET DROP SKIPROM   ;   

--- DIAGNOSTIC ---
--- read and print 8 byte ROM code
pub RDROMH        1W.RESET DROP READROM 8 .1W ;
--- reset, skip ROM, read and print Scratchpad 9 bytes
pub RDSCRH        1WSCMD  READSCR 9 .1W ;      




        --- Device specific ---
        
--- read first 2 bytes from scratchpad and assemble to temperature value on TOS ( binary, low nibble is fraction )    
pub TEMP@ ( -- temp )                       
    READSCR        
    1W@ 1W@ B>W
    ;
                                        
pub .TEMP ( temp -- )
    DUP $0F AND SWAP 4 SHR           --- put whole degrees in one long and fraction in another
    $830A .NUM                    --- print whole number signed
    "." EMIT                    --- print decimal point
    100 * 4 SHR               --- turn binary bits to 100ths
    2 PRINTDEC
    ." 'C  "
    ;

{        
\ 18B20 diagnostic routines
: SHOWTEMP ( reads and displays a single DS18B20 alone on a 1-W bus )
                1WSCMD CONVERTT 750 ms
                1WSCMD TEMP@ DUP CR .TEMP
                 SPACE 4 SHR 0 DO ." *" LOOP
                ;
: SHOWSP ( reads annd displays a single DS18B20  SCRATCHPAD alone on a 1-W bus )
                1WSCMD CONVERTT 750 ms
                1WSCMD RDSCRH
                ;

: SHOWTEMPS                BEGIN SHOWTEMP 2 seconds KEY UNTIL ;

}

{
DESCRIPTION
Maxim 1-wire ROM Search algorithm
straight forward implementation
per AN937 "Book of iButton Standards", figure 5-3
for TACHYON Forth 2014 by Markus Baer aka MJB @ parallax forums,
inspired by am-forth implementation by Bradford J. Rodriguez.
}

{ if you need it ...
: 1W.!N ( xN .. x1 N -- ) FOR 1W! NEXT ;       \ send N characters/bytes from stack
: 1W.@N ( N -- x1 .. xN ) FOR 1W@ NEXT ;       \ fetch N characters/bytes to stack

: 1W..ROM RDROMH ;  \ print 1Wire single device ROM code
}

IFNDEF BIT! pub BIT! IF SET ELSE CLR THEN ; }

 
BYTE 1W.lastdisc        --- used as byte variable to hold last discrepancy
BYTE 1W.doneflag   
BYTE 1W.rombit            --- used as byte variable, 1..64
BYTE 1W.discmark

--- buffer for one ROM-ID  1W.romid ( 8 byte array )
8 BYTES 1W.romid

--- set the bit 1..32 given by 1W.rombit in buffer 1W.romid to flag value f
pri 1W.!rombit ( f -- )
    1W.rombit C@ 1- 8 U/MOD ( -- f bit# byte# )
    1W.romid + ( f bit# addr )
    SWAP MASK SWAP  ( f  bitmask addr )
    ROT BIT!
;

---  fetch the bit 1..32 given by 1W.rombit from buffer 1W.romid to flag f
pri 1W.@rombit ( -- f \ f is 0 or non-0 not necc. 1 )
    1W.rombit C@ 1- 8  U/MOD ( -- bit# byte# )
    1W.romid + C@ ( -- bit# byte )
    SWAP MASK ( -- byte bitmask )
    AND
;

--- single bit operations to read and write 1-wire bus
pri 1W.BIT@ ( -- bit )    1W.PIN@ 0 1W.BITRD NIP 0<> 1 AND  ;            --- gives bit as 0 or 1
pri 1W.BIT! ( bit -- )    1W.PIN@ SWAP 0<> 1W.BITWR 2DROP ;            --- takes bit as 0 or 1

{ for test
pri .rombit ( bitnumber -- ) 1W.rombit C! 1W.@rombit . ; \ print 1W.rombit value
pri .RB ( -- ) 1W.@rombit . ;
pri .romid ( -- ) 1W.romid 8 ADO  I C@  .  SPACE LOOP ;
}




--- SEARCH ROM ROUTINES ---



BYTE 1Wcnt    
LONG 1Waddrs

--- clear variables used in search
pri 1W.NEWSEARCH ( --  )   
    1W.lastdisc C~
    1W.doneflag C~    
    1 1W.rombit C!
    1W.romid 8 ERASE
    1Wcnt C~
    ;

--- search for one additional device. Returns 0 if done or 1 if more to come. see 1W.SCAN
pri 1W.SEARCHROM ( -- f  )
    0 ( default return value )  ( 0 )
    1W.doneflag C@ IF 1W.doneflag C~ EXIT THEN    ( leaves 0 )
    1W.RESET IF                            --- presence signal detected?
        1 1W.rombit C!                        --- yes: set ROM bit index to 1
        1W.discmark C~                        --- set discrepancy marker to 0
        $F0 1W!                            --- send search command on bus
        BEGIN
            1W.BIT@ 1W.BIT@ 2* +    ( 0 BA )            --- 2 bits A & B  in bit pos 0 AND 1         
            DUP 3 =               ( 0 BA flag )
            IF ( bitA = bitB = 1?)            
                DROP
                1W.lastdisc C~                    --- clear
                EXIT                ( leaves 0 )
            ELSE                    ( 0 BA )
                ?DUP 0=             ( 0 BA false  |  0 true )
                IF ( bitA = bitB = 0?)                ( 0 )
                    1W.rombit C@ 1W.lastdisc C@ =   ( 0 flag )
                    IF  1 1W.!rombit                ( 0 )
                    ELSE 1W.rombit C@ 1W.lastdisc C@ >  ( 0 flag )
                        IF  0 1W.!rombit
                            1W.rombit C@ 1W.discmark C!  ( 0 )
                        ELSE 1W.@rombit 0= IF 1W.rombit C@ 1W.discmark C! THEN  ( 0 )
                        THEN   ( 0 )
                    THEN    ( 0 )
                ELSE        ( 0 BA )
                    1 AND ( bit A value , bit B is inverse so we don't need it )                
                    1W.!rombit    ( 0 )
                THEN
            THEN    ( 0 )
            1W.@rombit     \ gives 0 or 1 as logical values instead of 0 -1        
            1W.BIT!        ( send ROM bit to bus )
            1W.rombit C@
            1+ DUP
            1W.rombit C!    ( 0 1W.rombitVal ) \ increment 1W.rombit index
        64 > UNTIL   \ check > 64      ( 0 )
        1W.discmark C@
        DUP 1W.lastdisc C!        ( 0 discmark  )
        IF 1+ ( set result to true ) ELSE 1 1W.doneflag C! THEN     ( 0 )
    ELSE ( no presence signal )
        1W.lastdisc C~   \ set 0
    THEN
;

--- calc the CRC given start and length of string/bytes. If string includes the CRC the result is 0 for OK
pub CRC8 ( str cnt -- crc )
     0 ROT ROT
     ADO
       I C@ SWAP
        8 FOR
         2DUP XOR 1 AND
          ROT 2/ ROT 2/ ROT IF $8C XOR THEN
       NEXT
        NIP
     LOOP
     ;
     
     
     

pub .FAMILY ( code -- )
    SWITCH
    ."  = "
    1   CASE ." 2401 SERIAL ID" BREAK
    9   CASE ." 2502 1k AO MEMORY" BREAK
    $28 CASE ." 18B20 THERMOMETER" BREAK
    $20 CASE ." 2450 QUAD ADC" BREAK
    SWITCH@ ." #" .BYTE
    ;

--- Demonstrates how to use SEARCHROM to find all attached devices and store them in table 1Wdevs
40 8 * BYTES 1Wdevs                        --- prepare for 40 devices here, change as appropriate
    
--- scan for any devices on 1-wire bus and store them in table 1Wdevs
pub 1W.SCAN ( -- )  
   1W.NEWSEARCH
   1Wdevs 1Waddrs  !                    --- begin at start of  table
   0
   BEGIN
      1+
      CR 1W.PIN@ >| ." P" $20A .NUM ." -" DUP $20A .NUM ." :  "
      1W.SEARCHROM ( -- flg )
      ." DEVICE# "
      1W.romid 1+ DUP U@ SWAP 4 + U@ 
     .WORD ." ." .LONG
     SPACE 1W.romid C@ .FAMILY
      1W.romid 8 CRC8 IF CR ." CRC mismatch above" THEN
      1W.romid 1Waddrs @ 8 CMOVE               
     --- SEARCHROM could be optimized to store directly to table,
     --- by making 1W.romid a CONST pointing to the table entry and changing it for each run
      8 1Waddrs +!                       --- increment the address to store by 8 bytes
   0= UNTIL
   DROP
;


{ some demo / test  code
pub 1Wdevs  \ print the table of 1Wdevs discovered by 1W.SCAN ( if table is not full )
    1
    1Wdevs
    CR
    BEGIN     \ BEGIN condition WHILE code REPEAT
     DUP
     C@ WHILE  ( 1 1Wdevs ) \ works only if there is at least one element in table which is 0ed
            SWAP DUP .BYTE ":" EMIT SPACE 1+ SWAP
            DUP  .1W.romid
            8 +
    REPEAT
    DROP
;

pub 1W..1WdevsT  \ print the table of 1Wdevs discovered by 1w.scan in Table format for inclusion in Tachyon code
    1Wdevs
    CR ." TABLE 1W.my1Wdevs" CR
    BEGIN   \ BEGIN condition WHILE code REPEAT
     DUP C@
    WHILE  ( 1 1Wdevs )
            SPACE
            DUP 8 ADO ." $" I C@ .BYTE ."  | " LOOP CR  \ ADO ( from cnt -- )
            8 +
    REPEAT
    DROP
;
\ print the discovered 1Wire-IDs
1W..1Wdevs
\ print the table of 1Wdevs discovered by 1w.scan in Table format for inclusion in Tachyon code
1W..1WdevsT

}

pri @rom    1- 3 SHL + ;

--- 1 Wire Multibus CoMmanD  takes the address of a ROM code and performs a matchROM command
pub 1W.MCMD  ( -- )  1W.RESET DROP MATCHROM   ;       --- reset and send Match ROM command

--- address sensor with 64-bit rom code given at addr then ready for next command
pub 1W.MATCH ( addr -- )  
    1W.MCMD  8 ADO I C@ 1W! LOOP   
;
--- reset and send Skip ROM command
pub 1W.SKIP ( -- )  1W.RESET DROP SKIPROM   ;   


     --- DS18B20 diagnostic routines ---

--- reads and displays a DS18B20 on a multibus. n is the index into the table of devices 1Wdevs
--- 1Wdevs table of discovered 1W devices with SEARCHROM
pub 1W.SHOWTEMPM ( tableaddr n --      )
    @rom
    DUP 1W.MATCH CONVERTT 750 ms
    1W.MATCH TEMP@ .TEMP
    ;
                
--- reads and displays a DS18B20 SCRATCHPAD on a multibus n is the index into the table of devices 1Wdevs
--- 1Wdevs table of discovered 1W devices with SEARCHROM
pub 1W.SHOWSPM ( tableaddr n -- )
    @rom
    DUP 1W.MCMD CONVERTT 750 ms
    1W.MCMD RDSCRH
    ;
                
--- for sensor# from I = 1 to n from ROM-Code table given show the temp readings cyclically until key pressed                
pub 1W.SHOWTEMPSM ( tableaddr n -- )
    CR
    BEGIN
      1 OVER ADO  \ from 1 to n
        OVER I 1W.SHOWTEMPM SPACE
      LOOP  
      CR 2 seconds
      KEY
    UNTIL
    2DROP
    ;
    
    

{    the generated table ready to paste into Tachyon again
TABLE 1W.my1Wdevs
 $28 | $09 | $6C | $CD | $04 | $00 | $00 | $82 |
 $28 | $F7 | $E6 | $BF | $04 | $00 | $00 | $3A |
 
1W.my1Wdevs 2 1W.SHOWTEMPSM   \ show the temperature for my 2 sensors

\ next line works directly after romsearch from found IDs
\  1Wdevs  2 1W.SHOWTEMPSM

1Wdevs  2 1W.SHOWTEMPSM
+023.00'C   +023.18'C
+023.00'C   +023.18'C
+023.31'C   +023.18'C
+024.00'C   +023.18'C
+024.50'C   +023.18'C
+025.00'C   +023.18'C
+025.37'C   +023.18'C
+025.81'C   +023.18'C
+026.12'C   +023.18'C
+026.18'C   +023.25'C
+026.25'C   +023.75'C
+026.06'C   +024.18'C
+025.87'C   +024.62'C
+025.75'C   +025.06'C
+025.62'C   +025.31'C
 ok
 1Wdevs  1 1W.SHOWTEMPSM
 
 : bb 1W.SCAN 1Wdevs SWAP 1W.SHOWTEMPSM ;
 : bbb 1 bb ;
 
 \ Temp measurement GUI

pub TEMPGUI ( nSensors -- )
    VCLS 1+
    BEGIN
        HOME
        DUP 1 DO
            ERLINE I .DEC SPACE
            1Wdevs I 1W.SHOWTEMPM CR
        LOOP
\        KEY? AND    \ AND required, since KEY? ( -- key flag )
        KEY
    UNTIL
    2DROP
;
 
22 TEMPGUI

pub TEMPGUI2 ( nSensors -- )
    VCLS 1+
    BEGIN
        HOME
        --- for all sensors start the temperature conversion, this requires power to the sensors, parasitic will not work.
        DUP 1 DO       
            1Wdevs I
                @rom   \ calculate start of ROM code to address
                1W.MATCH CONVERTT    \ start temp measurement
        LOOP               
               750 ms
        --- now get the measured temperature value from each sensor
        DUP 1 DO   
            ERLINE I .DEC SPACE
            1Wdevs I @rom
              1W.MATCH TEMP@ .TEMP
            CR
        LOOP
\        KEY? AND    \ AND required, since KEY? ( -- key flag )
        KEY
    UNTIL
    2DROP
;
    
}

{ Scan for 1-wire devices on all pins with pull up resistor and report  }
pub ls1w
     CR ." Scanning for 1-Wire devices from P0 to P27"
0 28 ADO I PINLOAD?  "U" = IF I 1W.PIN 1W.SCAN THEN LOOP
;


IFDEF EXPLORER
: lshw1w        lshw CR ls1w CR ;
AUTORUN lshw1w
}

{
scan reveals device used in Dell laptop power supply
ls1w
Scanning for 1-Wire devices from P0 to P27
P11-01:  DEVICE# 0000.03C3.6AB8  = 18B20 THERMOMETER
P11-02:  DEVICE# 0000.03B2.CB9D  = 18B20 THERMOMETER
P11-03:  DEVICE# 0000.06D6.3C3C  = 2401 SERIAL ID
P23-01:  DEVICE# 0000.06D6.535E  = 2401 SERIAL ID
P23-02:  DEVICE# 0000.36A5.EE5A  = #09 ok

Connect and ADC to the bus

Scanning for 1-Wire devices from P0 to P27
P11-01:  DEVICE# 0000.03C3.6AB8  = 18B20 THERMOMETER
P11-02:  DEVICE# 0000.03B2.CB9D  = 18B20 THERMOMETER
P11-03:  DEVICE# 0000.06D6.3C3C  = 2401 SERIAL ID
P23-01:  DEVICE# 0000.000C.00DA  = 2450 QUAD ADC
P23-02:  DEVICE# 0000.06D6.535E  = 2401 SERIAL ID ok
}


]~ END

?BACKUP


