TACHYON
[~

FORGET PAB.fth
pub PAB.fth		." Propeller Activity Board hardware definitions 150325.0000 " ;


( P8X32A PINOUTS )


( SD CARD )
#P25	|< == &SDCS             '' SDCARD CS
#P22	|< == &SDDO             '' Data out from SDCARD
#P23	|< == &SDCK             '' SDCARD clock 
#P24	|< == &SDDI             '' Data to SDCARD (MOSI) - CD pulls down

( ADC124S021 )
#P18	|< == &ADSI		'' ADC serial data in
#P19	|< == &ADSO		'' ADC serial data out
#P20	|< == &ADCK		'' ADC serial clock
#P21	|< == &ADCS		'' ADC chip select

#P26	== DA0			'' Audio DAC0 or sourced LED
#P27	== DA1


--- define masks for memory devices
&SDCS >| #24 SHL &SDDO >| 16 SHL OR &SDDI >| 8 SHL OR &SDCK >| OR		== SDC


--- Use one of the LEDs as an SD busy indicator
pub SDBSYLED			#P26 SWAP IF PINSET ELSE PINCLR THEN ;

--- This card detect method becomes the default used by SDCARD.fth
pub CARD? ( -- flg )
	&SDDI INPUTS		'' revert to input to sense CD switch
	&SDDI IN NOT
	&SDDI OUTSET		'' switch back to an output
	;


( PCB DEFINITIONS )
\ Do what we need to do to init the hardware on this pcb
pub !PCB
	&SDCS	OUTSET
	&ADCS	OUTSET
	;

( PCB IDENTIFICATION )
" Propeller Activity Board" 0 STRING PCB$
#32910 	== PCB

]~
END
