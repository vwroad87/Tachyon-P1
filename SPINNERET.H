TACHYON
[~
FORGET SPINNERET.fth
pub SPINNERET.fth        ." Spinneret + W5100 HARDWARE DEFINITIONS 131204.1200 " ;

{
DESCRIPTION
These are the header files that define the functions of the pins plus any other special functions needed for the QuickStart boards. Although these definitions are not strictly required they do simplify integration of the various Tachyon Forth modules which will be automatically configured to run on the QuickStart

VER:    Propeller .:.:--TACHYON--:.:. Forth V28160511.1400
FREQ:   80MHZ (PLLEN OSCEN XTAL1  PLL16X)
NAMES:  $4F95...71B2 for 8,733 bytes (+252)
CODE:   $0924...4993 for 16,495 bytes (+786)
CALLS:  182 vectors free
RAM:    1,538 bytes free
BUILD:  FIRMWARE BUILD DATE 000259:811687
BOOTS:  0
BOOT:   EXTEND.boot
POLL:   


MODULES LOADED: 
4681: EEWORDS.fth         TACHYON DICTIONARY WORDS in EEPROM 150724.1400 
3974: EASYFILE.fth        FAT32 Virtual Memory Access File System Layer V1.1 150213-1530 
33DC: SDCARD.fth          SD CARD Toolkit - 150827.0000 
327C: SPINNERET.fth       Spinneret + W5100 HARDWARE DEFINITIONS 131204.1200 
1A86: EXTEND.fth          Primary extensions to TACHYON kernel - 160515-1530

POLL:   



}

( P8X32A PINOUTS )
( PIN MASK NAME               HDR2X20     DESCRIPTION ) 
'' * WIZnet W5100 SPI *
#P3    |< == &WNCK             '' Pin 13    W5100 clock
#P0    |< == &WNDO             '' Pin 14    MISO from W5100
#P1    |< == &WNDI             '' Pin 15    MOSI to W5100
#P2    |< == &WNCS             '' Pin 16    W5100 chip select
#P12    |< == &WNcs             '' Pin     W5100 parallel chip select
'' * WIZnet W5100 control signals *
#P13    |< == &WNINT            '' Pin 26    W5200 Interrupt
#P14    |< == &WNRST            '' Pin 27    W5200 reset


'' * SD CARD SPI * 
#P16     |< == &SDDO             '' Pin 9    Data from SDCARD    S/D input
#P21     |< == &SDCK             '' Pin 10    SDCARD clock    S/D resistor
#P20    |< == &SDDI             '' Pin 11    Data to SDCARD
#P19    |< == &SDCS             '' Pin 12    SDCARD chip select (cut pullup for card detect)

#P23    |< == LED               '' Pin     LED


pub WRESET ( on/off -- )    NOT &WNRST OUT ;
pub WPWRDN ( on/off )        DROP ;


( S-35390A RTC )


$60    == @rtc        \ S-35390A RTC "8-bit" I2C ADDRESS - modified with sub-address C2C1C0 for command (rather non-I2C)

DOUBLE rtcbuf 

\ Read first 8 timekeeping bytes of RTC into rtcbuf - L
pub RDRTC
    I2CSTART @rtc 5 + I2C!                        \ sub-address RTC date and time (7 byte seqential read YMDWHMS)
    7 FOR 0 I2C@ #24 REV rtcbuf 1- IX + C! NEXT         \ read 7 bytes but write to buffer in reverse order SMHWDMY
    1 I2C@ DROP                                \ one dummy nak read
    I2CSTOP
    ;   
\ Write first 8 timekeeping bytes of RTC from rtcbuf
pub WRRTC
    I2CSTART @rtc 4 + I2C!                        \ sub-address RTC data and time (7 byte sequential write)
    7 FOR rtcbuf 1- IX + C@ #24 REV I2C! NEXT                \ Write year first
    I2CSTOP
    ;
pub TIME@ ( -- $hhmmss ) \ read time in bcd format
    RDRTC rtcbuf @ 
    ;
pub DATE@ ( -- $yymmdd ) \ read international date in bcd format
    RDRTC rtcbuf 4 + @ 
    ;
pub TIME! ( $hh.mm.ss -- ) \ write time in bcd format
     0
pri RTC!
    rtcbuf + ! WRRTC
    ;
\ Usage: $130630 DATE! \ set the date to the 30th June 2013
pub DATE! ( $yy.mm.dd -- )
    4 RTC!
    ;

pub .TIME         TIME@ L>W .BYTE ." :" W>B .BYTE ." :" .BYTE ;
\ Print date in international format YYYY/MM/DD (otherwise 1/12/2013 could be 1st of December or 12th of January)
pub .DATE        DATE@ L>W ." 20" .BYTE ." /" W>B .BYTE ." /" .BYTE ;        
pub .DT        .DATE SPACE .TIME ;    




pub SW2? ( -- flg )
     LED INPUTS LED IN LED OUTPUTS 
     ;
\ Do what we need to do to init this pcb
pub !PCB
     LED OUTSET 
    ;
" SPINNERET" 0 STRING PCB$
#32203     == PCB


]~
END
