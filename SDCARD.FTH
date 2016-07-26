TACHYON
[~
{ SD CARD TOOLKIT }
FORGET SDCARD.fth

pub SDCARD.fth    ." SD CARD Toolkit - 150827.0000 " ;

{
DESCRIPTION
These are the general routines used to initialize and the SD card and can also be used to load and save blocks directly. There are various tools plus the primitives which allow you to directly interact with the card and it's command set. This module forms the foundation on which other modules for virtual memory and file system relies.


NOTE: The card insertion method used here in CARD? is based on that mentioned in the official SD MEMORY CARD SPECIFICATIONS which detects the pullup that exists on the chip select of a memory card itself. This means that a "safety" pull-up is never required and the card detect will not work if one is used. It is perfectly safe to remove any resistor that has been added to pull-up the CS line after which the standard card detect method can be used.


CHANGELOG:
150827 Fixed SD methods - set constants when FILE is executed
150826 Improved XADR methods
141202 added default C:
     Added ?SPIO to save half the CMD execution time by caching this module and pin masks
     Increased &sdto timeout constant from 10,000 to 20,000 (~250ms)
141115 removed diagnostic utilites, added multiple cog access if run in it's own cog (sdtask set)
140121 modified for linked timer method
131114 tidied and trimmed source
131111 Standardized for hardware header support
     Make BUFFERS fully available for 4 sectors (multiple files open)
131105 Increased timeout from 5,000 to 10,000
131104 Added in basic virtual memory interface words
130723 Restructured the code, optimized SDPINS etc. inserted datasheet images
130717 Tidied up source
130303 Changed constant names to =constant rather than #constant as numeric preprocessor clashes
121226 Removed redundant [SPIO] references which were also slowing down access
121013 Modify to use BUFFERS (VM image)
120917 Added SPINNERET
120909 Added CARD detect redefinition vecotr "ucard"
120909 Added extra pin definitions for different boards
120903 Added pin redirection

MODULE INFO:
SMALL BUILD (not reclaimed)
NAMES:  $5D73...74EB for 6008 (0650 bytes added)
CODE:   $0000...3000 for 6280 (1456 bytes added)
CALLS:  0477 vectors free
RAM:    11635 bytes free


NAMES:  $5903...7309 for 6662 (0618 bytes added)
CODE:   $0000...38B6 for 7856 (1820 bytes added)
CALLS:  0405 vectors free
RAM:    8269 bytes free

TESTS:
Reading from the card:
4K LOAD takes 18.76ms
512 byte LOAD takes 2.55ms
}
[PRIVATE
{ NOTE: Pin defintions may be made at compile time or at runtime using SDPINS
If a header file is compiled beforehand then it should include these pin names as shown.
The card detect is via the SDCS which detects a card's "pullup" (do not use external pullups here!!!)
}
IFNDEF &SDCS
#P26    |<     == &SDCS            --- SDCARD CS
#P27    |<     == &SDDO            --- Data out from SDCARD
#P28    |<     == &SDCK            --- SDCARD clocks (Shared with SCL)
#P29    |<     == &SDDI            --- Data to SDCARD (Shared with SDA)
}

IFNDEF PCB
0		== PCB
" NOT DEFINED"	0 STRING PCB$
}

#512        == BLKSIZ PUBLIC  --- BLKSIZ is used because it is smaller & faster than a literal #512 - it is really constant


[PRIVATE            --- make the following definitions private until PRIVATE]
--- SD Tokens
$FE             == =dtk            --- data token for single block read/write
--- $FC         == =dtk1            --- data token for 1st block read/write
--- $FD         == =dtke            --- data token for last block read/write

( SD CARD REGISTERS )

#176 BYTES sdinfo
sdinfo         ORG            --- Use Tachyon reserved buffer space for SD card (normally at $7400)
#64            DS cid        --- Card ID
#64            DS csd        --- Card Specific Data
#4            DS ocr        --- Operating conditions register

--- #16            DS extbuf        --- temp buffer used for reporting functions
PRIVATE]

#4            DS sdpins
#4            DS sdsize
#4            DS sdwr PRIVATE
#4            DS sdrd PRIVATE
#2            DS ucard        --- user vector for special card detect routine
#2            DS sdbusy
#1            DS crc PRIVATE
#1            DS card?        --- card detect transition memory
#1            DS blklen
#1            DS sdhc PRIVATE

1            DS filesel        --- currently selected file 0..3

4 BYTES wrflgs                 --- byte flag for each channel to indicate current sector buffer has been written to

wrflgs         == @WRFLG         --- make @WRFLG a constant byte address, one for each file (faster than bit ops)

--- Current sector loaded in SDBUFs for the 4 files possible
4 LONGS sectors PRIVATE    --- sector is the SD 4GB address shifted right by 9 bits - 512 BLKSIZe
sectors == _sector            --- fast access to current sector than sector @FILE

--- Sector CRCs
4 LONGS scrcs PRIVATE
scrcs == _scrc

BUFFERS == SDBUF        --- initial value for SDBUF which depends upon which file handle is selected

pub FILE ( index:0..3 -- )  \ Set the active file channel (0 ..3)
     3 AND DUP filesel C!                --- remember new selection
     DUP 4* sectors + ' _sector 1+ !        --- 150826 method to improve speed for XADR
     DUP 4* scrcs + ' _scrc 1+ !
     DUP wrflgs + ' @WRFLG 1+ !             --- set @WRFLG constant for faster operation
     9<< BUFFERS + ' SDBUF 1+ !         --- set SDBUF constant for faster operation
     ;

--- return the current file channel
pub FILE# ( -- file# )    filesel C@ 3 AND ;

{HELP @FILE ( addr -- addr+off )
returns the address offset into sector & sectcrc tables for active file channel
as set with    index FILE
e.g. val sector @FILE ! otherval sectcrc @FILE ! sector @FILE @
}
pub @FILE ( addr -- addr+off )
FILE# 4* +
     ;

--- Load default SD pins at compile time ( ce-miso-mosi-clk -- )
&SDCS >| #24 SHL &SDDO >| 16 SHL OR &SDDI >| 8 SHL OR &SDCK >| OR sdpins !


IFNDEF SDBSYLED
pub SDBSYLED     DROP ; --- dummy status LEDs if not defined
}
IFNDEF SDERRLED
pub SDERRLED    DROP ; --- dummy status LEDs if not defined
}

--- 141115 added command channel to allow SDCARD to run in it's own cog.

LONG sdsrc,sddst,sdres
BYTE sdcmd,sdtask
pri SDCMD
     BEGIN sdcmd C@ 0= UNTIL            --- another cog may be using this channel
      SWAP sddst ! SWAP sdsrc ! sdcmd C!
     BEGIN sdcmd C@ 0= UNTIL
     sdres @
     ;


ucard W~
--- Detect SD card presence - the CS line must not have a pullup on it (redundant and undesirable).
pub CARD?    ( -- flg ; Is SD card present? )
     sdtask C@ IF 0 0 "?" SDCMD EXIT THEN    --- replace direct access method with command channel if SDCARD.TASK is running
pri _CARD?
     ucard W@ ?DUP IF JUMP THEN        --- use alternative card detect method if selected
    &SDCS OUTCLR                --- pulse low, float, check, return high
    &SDCS INPUTS                --- Float CS
    &SDCS IN                --- Is it still low or has it been pulled up (by the card's pullup)
    &SDCS OUTSET                --- force back to an inactive CE output
    ;


--- Fetch a byte from the SD (clock in 1's)
pri SD@ ( -- 8b )
    -1 RUNMOD >B
    ;
--- Write a byte to the SD
pri SD! ( 8b -- )
    16<< 8<< RUNMOD DROP
    ;


( SDRD and SCAN )
--- MAKE SURE THAT KERNEL 23140617 or greater is used
BYTE scanch
WORD scancnt,scanpos

--- Read in one block of 512 bytes from SD to dst
pri (SDRD) ( dst -- )
	--- BYTE scanch holds the char to scan for
	--- gives number of character matches found in WORD scancnt
	--- autoincrements on each call, use scancnt W~ to init to 0 if needed
	--- position of first match in WORD scanpos
	[SDRD] 1 COGREG@ OUTSET scanch C@
     ( dst char ) RUNMOD ( first cnt )            --- load the SDRD RUNMOD and run
	scancnt W+!					--- increment scancnt by last number of times scanch was found
	scanpos W@ 0= IF scanpos W! ELSE DROP THEN       --- on multi block reads capture first occurrence
	--- NOTE: use scanpos W~ to init
;

pri SD2@ ( -- word ) --- 16us
     SD@ 8<< SD@ OR
     ;
pri SD4@ ( -- long ) --- 26us
     BL @CNT COGREG! -1 RUNMOD
     8 @CNT COGREG!
     ;
--- Faster byte wide clocks (8/count)
pri SDCLK ( cnt -- )
    FOR SD@ DROP NEXT
    ;

#20,000 == &sdto				--- SD timout period - can be very long

--- do what needs to be done if the SD card is busy (LED etc) - can be rewritten
--- LEDs are defined in PCB header files
pri SDBUSY ( state -- )        sdbusy W@ ?DUP IF JUMP ELSE SDBSYLED THEN ;


--- Initialize the SD I/O and basic card
pub SDPINS ( ce-miso-mosi-clk -- --- set pins, save them for reboot and init with !SDIO see high level !SD )
    sdpins !					--- remember which pins were used for BACKUP
    sdtask C@ IF 0 0 "P" SDCMD EXIT THEN	--- replace direct access method with command channel if SDCARD.TASK is running
pri !SDIO					--- init SD pins
     sdpins @
    DUP #24 >> MASK ' &SDCS 1+ !		--- setup SDCS mask
    MODPINS
    ucard W~
    sdbusy W~

    [SPIO]
    1 ms
    &SDCS OUTCLR				--- select the card
    @MOSI COGREG@ OUTSET			--- Set MOSI high
     @SCK COGREG@ DUP OUTCLR			--- clock low (and as an output)
    #100 FOR DUP OUTSET DUP OUTCLR NEXT DROP
    &SDCS OUTSET
    16 SDCLK					--- 16 byte-wide clocking cycles
    &SDCS OUTCLR
    16 SDCLK
    &SDCS OUTSET
    ;

--- define drive select commands
IFNDEF SDC
&SDCS >| #24 SHL &SDDO >| 16 SHL OR &SDDI >| 8 SHL OR &SDCK >| OR == SDC
}

pub C:        SDC SDPINS ;

IFDEF SDD
pub D:        SDD SDPINS ;
}
IFDEF SDE
pub E:        SDE SDPINS ;
}
IFDEF SDF
pub F:        SDF SDPINS ;
}


( SD CARD RESPONSES )





( Response fetch )
pri RES@ ( -- res ) --- Continue reading until a response is received (with timeout)
    $FF &sdto 0					--- TIMEOUT PERIOD   $FF = timeout return value - 115ms
      DO SD@ DUP $FF <>				--- look for a response (non $FF)
        IF NIP LEAVE ELSE DROP THEN
      LOOP
    ;



--- 141202 - added ?SPIO to save 120us each CMD by checking to see if SPIO parameters need to be reloaded
[SPIO]
' RUNMOD COG@        == =SPIO PRIVATE    --- SPIO  signature

pri ?SPIO        ' RUNMOD COG@ =SPIO <> IF [SPIO] sdpins @ MODPINS THEN ;

{HELP SDCS ( on/off -- ) SD chip select method to allow for Parallax C3 board.
Direct chip select timing: 15.8us ON, 15us OFF
IF PC = 32209 = C3 PCB: 72.2us ON, 21.2us OFF

}
pub SDCS ( on/off -- )
     PCB 32209 = IF			--- C3 PCB? (32209 = Parallax part#)
       8 LOW 8 HIGH IF 5 FOR 25 DUP HIGH LOW NEXT THEN
     ELSE
       IF &SDCS OUTCLR ELSE &SDCS OUTSET THEN
     THEN
;


( Issue a command to the SD card )
pub CMD    ( data cmd -- res )		--- Send the command to the SD card and read result - 108us
    ?SPIO 0 COGREG@ OUTCLR
    SD@ DROP				--- extra clocks
     ON SDCS				--- Select the card
    $3F AND $40 OR SD!			--- send the command
    BL @CNT COGREG!			--- 32-bit transfer
    RUNMOD DROP				--- send data
    8 @CNT COGREG!			--- back to 8-bit transfers
    crc C@ SD!				--- dummy checksum ( is valid for initializing)
    RES@				--- fetch the response
    ;

--- Send an ACMD to the card and return with response
pub ACMD ( data acmd -- res )
     0 #55 CMD DROP CMD
     ;
pri STAT@ ( -- stat )
     0 #13 CMD RES@ 8<< OR
     ;

pub SDERR? ( -- flg ; return SD bit flag errors)
    0 _CARD? 0= 1 AND OR		--- b0 = card detect error
    sdrd @ 0= 2 AND OR			--- b1 = read failure
    sdwr @ 0= 4 AND OR			--- b2 = write failure
    ocr @ 0= 8 AND OR			--- b3 = card error
    ;
pri MARKER? ( marker -- flg ; Find SD marker and return true before timeout )
    &sdto BEGIN OVER SD@ <> WHILE 1- DUP 0= IF NIP EXIT THEN REPEAT
    2DROP TRUE
    ;

pri SDDAT! ( adr -- ; Wait for read token and read SD data into buffer )
    =dtk MARKER? IF 16 ADO SD@ I C! LOOP 3 SDCLK ELSE DROP THEN
    ;






TIMER sdtimer PRIVATE

--- In SPI Mode, only the OCR, CSD and CID registers are accessible.
pri ?SDTIMEOUT        sdtimer TIMEOUT? IF FALSE R> DROP EXIT THEN ;

--- Initialise the SD card (with timeout)
pub !SD ( -- ocr|false ; Initialise the SD card in SPI mode and return with the OCR )
     sdtask C@ IF 0 0 "Z" SDCMD EXIT THEN
pri _!SD
    ON SDBSYLED OFF SDERRLED
    ocr ~
    cid 16 ERASE csd 16 ERASE
     0 FILE
    SDBUF BLKSIZ 2* 2* ERASE		--- erase all 4 file buffers
     sectors 16 -1 FILL			--- force an invalid sector (nothing cached)
\    sdpins @ _SDPINS                   --- reload SDPINS in case this is a reboot & !SDIO
     !SDIO
    _CARD?
    IF
      #1000 sdtimer TIMEOUT
      $95 crc C!
        BEGIN ?SDTIMEOUT 0 0 CMD 1 = UNTIL
      $87 crc C!
           BEGIN ?SDTIMEOUT $1AA 8 CMD 1 = UNTIL
       SD4@ $1AA =
      IF
          BEGIN ?SDTIMEOUT $4000.0000 #41 ACMD 0= UNTIL
          BEGIN ?SDTIMEOUT 0 #58 CMD 0= UNTIL
         SD4@ DUP ocr !
        DUP
         IF
           0 #10 CMD 0= IF cid SDDAT! THEN
           0 9 CMD 0= IF csd SDDAT! THEN
         THEN
      ELSE
        FALSE
      THEN
    ELSE
      FALSE
    THEN
    &SDCS OUTSET
     OFF SDBSYLED
     DUP 0= SDERRLED                --- indicate an error visually if enabled
    ;

--- 141114 deprecated card info diagnostics

{ *** BLOCK BUFFERS *** }

--- card has been prep'd for read  - proceed and read a block of data
pub SDRDBLK ( dst -- crc )            --- dst is the HUB address of an SD buffer, SDBUF  gives active one
    (SDRD)                    --- special fast read module
    [SPIO]                    --- switch back to standard SPI mode (for commands etc)
    SD2@                        --- read crc
    31d MASK OR                    --- force crc as TRUE flag (msb set)
    ;


pri PROCESS_TOKEN    ( dst token -- crcflg )
     =dtk = IF SDRDBLK EXIT THEN        --- read a block of data
    2DROP                        --- drop token and dst
    2 SDCLK STAT@ DROP            --- discard cycles
    &SDCS OUTSET
    FALSE
    ;




--- SD CARD READ BLOCK - measured 2.3ms to 6ms on 4GB Sandisk
pub SDRD    ( sector dst -- crc | false ; Read sector from SD into dst )
     sdtask C@ IF "R" SDCMD EXIT THEN
pri _SDRD
    ON SDBUSY
    SWAP #17 CMD ( data cmd -- res )    --- read block command
      IF
        DROP FALSE                --- didn't like that command - discard dst & return false
      ELSE
        RES@ PROCESS_TOKEN            --- process read token and read block
       THEN
    OFF SDCS                --- release the SD card
    OFF SDBUSY
    DUP sdrd !                   ---  save crc/flg
    ;


{HELP SDWR ( src sect -- flg )
Write to a sector in the SD card - measured 2.84ms on 4GB SanDisk
Testing 32k write: LAP 0 FILE@ 9 >> 64 ADO DUP I SDWR DROP BLKSIZ + LOOP LAP .LAP 274.111ms ok
}
pub SDWR    ( src sect -- flg ; Write from src to xdst in the SD )
     sdtask C@ IF "W" SDCMD EXIT THEN
pri _SDWR
    ON SDBUSY
    OFF SDCS 1 SDCLK                 --- finish off previous
     ON SDCS 3 SDCLK                --- Prep card
    #24 CMD ( src res )                --- write block command
    0=
      IF
         3 SDCLK =dtk SD!
        BLKSIZ [SDWR] RUNMOD            --- Write sector
        [SPIO]                    --- switch back to normal SPI mode
        0 MARKER? $FF MARKER? AND
        ELSE FALSE
      THEN
    OFF SDCS
    OFF SDBUSY
    DUP sdwr !
[SPIO]
    ;

--- --- --- --- --- --- --- ------ --- --- ------ ------ --- --- ------ --- --- ---



PRIVATE]


( Virtual memory addressing is suitable for addressing the first 4GB of the memory )

HELP: SECTOR ( sect -- )
Read the sector into the SDBUF
takes around 1.9ms, 2.55ms
}
pub SECTOR ( sect -- )
     DUP _sector !                     --- update sector pointer for this file channel
     SDBUF SDRD _scrc !
     ;

pri ACTIVE? ( -- flg )
     _scrc @ $8000.0000 <>
     ;


pub WRSECT ( -- flg ) ( write the current sector back to the storage media )
     SDBUF _sector @ SDWR
    ;

pub FLUSH   ( Write the sector buffer if it has been modified )
     @WRFLG C@
     IF WRSECT DROP @WRFLG C~ THEN
    ;

IFNDEF 9BITS pub 9BITS $1FF AND ; }

{
Translate a virtual address into a HUB RAM address - may have to flush and read a sector
15.8us if cached, else around 2ms average

V2.7 150826 just uses 9BITS and preset constants for 18.2us
$8000 0 LAP DO I XC@ DROP LOOP LAP .LAP 817.786ms ok
64 0 LAP DO I SECTOR LOOP LAP .LAP 128.475ms ok

V2.8 160508 now has 8>> and 8<< to avoid slow stack push and pops - down to 14us
$8000 0 LAP DO I XC@ DROP LOOP LAP .LAP  760.208ms ok

A 512 byte sector takes 2ms on the average to read into memory
}
pri XADR! ( xaddr -- addr )
     @WRFLG C~~
pub XADR ( xaddr -- addr )				--- make sure sector is loaded into SDBUF and return with physical address
    DUP 9>> _sector @ <>				--- same sector - buffered already?
    IF							--- No
	FLUSH						--- make sure any writes to the current buffer are flushed
        DUP 9>> SECTOR				--- get sector into SDBUF if not already there
    THEN
    9BITS SDBUF +    ( 4.6us )				--- return with physical address
    ;


--- cached timing = 16.4us or ~2ms to buffer sector
pub X@ ( xaddr -- long )                    --- read a long from virtual memory address xaddr
     XADR @
     ;
pub X! ( long xaddr -- )                    --- write a long to virtual memory address xaddr
     XADR! !
    ;
--- Execution time if cached = 43.6us or 2.8ms non-cached
pub XC@ ( xaddr -- byte )                    --- read a byte from virtual memory address xaddr
    XADR C@
    ;
pub XC! ( byte xaddr -- )                    --- write a byte to virtual memory address xaddr
    XADR! C!
    ;

pub XW@ ( xaddr -- word )                    --- read a byte from virtual memory address xaddr
    XADR W@
    ;


--- DUMP MEMORY ACCESS METHOD MODIFIER
--- Usage: 0 $200 SD DUMP

pub SD         ' XC@ dmm W! ' XW@ dmm 2+ W! ' X@ dmm 4 + W! ;


{

--- 141114 - examining methods of multiple cog access with SDFS running in it's own cog
pri SDCMD:
     SWITCH
     "R" CASE sdsrc @ sddst @ _SDRD sdres ! BREAK
    "W" CASE sdsrc @ sddst @ _SDWR sdres ! BREAK
    "Z" CASE _!SD sdres ! BREAK
     "P" CASE !SDIO BREAK
     "?" CASE _CARD? sdres ! BREAK
     "?" sdres !    --- unknown command
     ;

8 LONGS sdstk
pub SDCARD.TASK
     !RP sdstk SP! !SP
     sdtask C~~                --- indicate SD task is running for auto command channel
     BEGIN
       sdcmd C@ ?DUP IF SDCMD: sdcmd C~ THEN
     AGAIN
     ;
}



]~   --- end of load symbols
END



