TACHYON
[~
IFDEF eprint
$8000 eprint !
}
FORGET +P8.fth
pub +P8.fth        ." P1432 +P8 HARDWARE DEFINITIONS 141118.0000 " ;

--- P1432 +P8 PCB + P1455 IoT5500 ---


( P8X32A PINOUTS )


#P1    |< == &WNDO             '' MISO from WIZNET
#P17    |< == &WNCS             '' WIZNET CS
#P18    |< == &WNCK             '' WIZNET SPI CLOCK
#P19    |< == &WNDI             '' MOSI to WIZNET
#P23    |< == &SFCS             '' Serial flash CS (WINBOND W25Q80 8Mbit Flash)
#P27    |< == &SDCS             '' SDCARD CS
#P24    |< == &SDDO             '' Data out from SDCARD
#P25    |< == &SDCK             '' SDCARD clocks (Shared with SCL) 
#P26    |< == &SDDI             '' Data to SDCARD (Shared with SDA)
#P16  |< == &WINT






&SDCS >| #24 SHL &SDDO >| 16 SHL OR &SDDI >| 8 SHL OR &SDCK >| OR        == SDC
&SFCS >| #24 SHL &SDDO >| 16 SHL OR &SDDI >| 8 SHL OR &SDCK >| OR        == SDD


pub LANLED                #P21 SWAP IF PINCLR ELSE PININP THEN ;
pub SDBSYLED            #P22 SWAP IF PINCLR ELSE PININP THEN ;
pub WRESET ( on/off -- )    #P0 SWAP IF PINCLR ELSE PINSET THEN  ;
pub WPWRDN ( on/off -- )    DROP ;



( PCB DEFINITIONS )
\ Do what we need to do to init the hardware on this pcb
pub !PCB
     &WNCS    OUTSET
    &SFCS OUTSET
    &SDCS    OUTSET
    ;
" P1432 +P8" 0 STRING PCB$
#1432     == PCB

]~
END
