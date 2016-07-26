TACHYON [~

FORGET C3.fth
pub C3.fth        ." C3 HARDWARE DEFINITIONS 150529.1130 " ;

{

MCP3202

}
--- PORT A HEADER
--- P0..P7		--- GP I/O and servos
#P0	== GP0
#P1	== GP1
#P2	== GP2
#P3	== GP3
#P4	== GP4		--- servo P4
#P5	== GP5		--- servo P5
#P6	== GP6		--- servo P6
#P7	== GP7		--- servo P7

--- COMPOSITE VIDEO ---
--- P12,13,143
#P12	== vidpins	--- 3-bits of composite signal

#P15	== vgasel	--- active low select connects status led pins to VGA

--- PORT B HEADER
--- P16..23		--- GP I/O and VGA
#P16	== vgapins


--- SPI SIGNALS ---
--- SS is generated through a counter+decoder
#P9	== MOSI
#P10	== MISO
#P11	== SCK
#P25	== SELCK	--- select clock
#P8	== SELCL	--- select clear

#P24	== AUDIO	--- duty-dac (pwm) audio
#P26	== PS2DAT
#P27	== PS2CLK


--- SPI Slave Select ---
{	0 = none
	1 = 32K SRAM BANK 0
	2 = 32K SRAM BANK 1
	3 = 1MB FLASH
	4 = MCP3202 2 channel 12-bit A/D
	5 = Micro SD card
	6 = SPI6 header
	7 = SPI7 header
}

BYTE ssch					--- last channel selected

{ Slave SPI Select by channel number 0..7
Note: limitation is the slow C3 hardware setup - having to reset the counter to deselect
and then having to count up again to select takes much longer than an Tachyon SPI access itself.
To deslect just select channel 0 or  OFF SS
}

pub SS ( ch -- )
	DUP ssch C@ = IF DROP EXIT THEN		--- skip if already selected
	DUP ssch C!				--- update channel latch
	8 LOW 8 HIGH				--- clear counter
	25 DUP LOW MASK @SCL COGREG!
	?DUP IF FOR CLOCK CLOCK NEXT THEN
;

--- predefined Slave SPI selects according to function
pub SRAM0	1 SS ;
pub SRAM1	2 SS ;
pub FLASH	3 SS ;
pub MCP3202	4 SS ;
pub C3SD	5 SS ;

pub !PCB
	0 SS
    ;
" C3 32209" 0		STRING PCB$
#32209		== PCB

]~ END
