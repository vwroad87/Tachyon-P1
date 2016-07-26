TACHYON [~

FORGET VGA.fth
pub VGA.fth    PRINT" VGA text driver 160725-2000" ;

{
changelog:
160725 - Updated for V3 and ROMs
Renamed CL to HUE
Collapsed some minor words
If SMALL is defined then demo and circuit commands are not compiled

}

16    == vgapins

BYTE color,row								--- current palette color, row and column
LONG col								--- use long for column position to allow signed value for offset

64 BYTES colors								--- color table used by video cog

TABLE vgapars PRIVATE
    0 ,                --- 0:status           ' 0/1/2 = off/visible/invisible - read-only
    1 ,                --- 1:enable           ' 0=off (disabled completely)
    vgapins 7 + ,             --- 2:pins           ' vga pin group 0,8, or 16.
    %1000 ,            --- 3:mode           ' %tihv = tile,interlace,hpol,vpol   write-only
    BUFFERS , colors ,        --- 4:screen 5:colors       ' pointers to screen (words) and colors (longs)
    32 , 15 ,            --- 6:cols 7:rows       ' horz and vert tiles (characters)
    1 , 1 ,            --- 8:hx 9:vx           ' horz and vert tile expansion
    0 , 0 ,            --- 10:ho 11:vo           ' horz and vert offset
    512 , 10 ,            --- 12:hd 13:hf           ' horz display ticks, front porch
    75 , 43 ,            --- 14:hs 15:hb           ' horz synch ticks, back porch
    480 , 11 ,            --- 16:vd 17:vf           ' vert display lines, front porch
    2 , 31 ,            --- 18:vs 19:vb           ' vert synch lines, back porch
    CLKFREQ 2 >> ,        --- 20:rate           ' tick rate (Hz)

--- address a vga parameter
pub @VP ( reg -- addr ) 2* 2* vgapars +  ;

pub screen		4 @VP @ ;
pub cols		6 @VP @ ;
pub rows		7 @VP @ ;

pub VGAORG ( buffer -- )	4 @VP ! ;


pub DISPLAY ( on/off -- )
     vgapins SWAP IF LOW ELSE HIGH THEN
     ;

--- test - reverses all colors
pub REVCOL    colors 64 ADO I @ INVERT I ! 4 +LOOP ;

TABLE palette
{
---     RRGGBB    RRGGBB
    %001000 | %000000 |        --- 0 green on black
    %101000 | %000000 |        --- 1 yel on black
    %111111 | %000001 |        --- 2 white on dark blue
    %111100 | %010100 |        --- 3 yel on tan
    %100000 | %000000 |        --- 4 red on black
    %001111 | %000101 |        --- 5 cyan on teal
    %110000 | %101010 |        --- 6 red on gray
    %101010 | %000100 |        --- 7 white on dark green
}
---     RRGGBB    RRGGBB
   %111100 | %000000 |        --- yel
   %001000 | %000000 |        --- green on black
   %110000 | %000000 |        --- red on black
   %000010 | %000000 |        --- blue
   %100010 | %000000 |        --- mag
   %001010 | %000000 |        --- cyan
   %110000 | %111111 |        --- red on white
   %111111 | %000000 |        --- white
}
0        == yel
1        == grn
2        == red
3        == blu
4        == mag
5        == cyn
6        == redwht
7        == wht

--- select the current drawing/font color
pub HUE ( color -- )        7 AND color C! ;

pub setcolors ( ptr -- )
    8 0 DO
\      DUP I 2* + W@ W>B 2* 2* SWAP 2* 2* SWAP
      DUP I 2* + C@ 2* 2*                --- fore
      OVER I 2* 1+ + C@ 2* 2*            --- back
      ( ptr fore back )
      OVER DUP 24 SHL SWAP 8 SHL +        --- fore << 24 + fore << 8
      OVER DUP 16 SHL + +            --- X
      ( ptr fore back col1 )
      colors I 2* 2* 2* + !            --- index every 2 longs/color

      SWAP DUP 24 << SWAP 16 << +
      ( ptr back col2 )
      SWAP DUP 8 SHL + +
      colors I 2* 2* 2* 4 + + !
    LOOP
    DROP
    ;


BYTE vflg PRIVATE    --- 0:esc 7:nowrap
LONG vgaboot PRIVATE
-1 vgaboot !

--- Init the VGA interface if it hasn't been done yet
pub !VGA
    boot @ vgaboot @ <> 0EXIT            --- only load vga cog if needed
    boot @ vgaboot !
IFDEF V3
    vgapars 3 " VGA32x15" LOADCOG
}
IFNDEF V3
    4 @VP @ $200 + vgapars 2 COGINIT DROP        --- use COG #2 for VGA driver
}
    palette setcolors
pri clear
    $220
pri VFILL ( word -- )
    screen W!
    screen DUP 2+ rows cols * 1- 2* CMOVE
pri VHOME
    0 0
pub VXY    ( x y -- )
    row C! col !
    ;

pri scroll
    screen DUP cols 2* + SWAP rows 1- cols 2* * CMOVE
    rows 1- cols 2* * screen + cols 2* ADO $220 I W! 2 +LOOP
    ;

pri newline
    col ~
    row C++
    row C@ rows => IF scroll row C-- THEN
    ;



--- Display the VGA character and update position etc
pub VCHAR ( ch -- )
     col @ cols => IF $80 vflg SET? IF DROP EXIT ELSE newline THEN THEN       --- new line if needed (scrolls up if needed)
     DUP 1 AND color C@ 2* +           --- (color << 1 + c & 1 )
     10 <<                       --- form color field
     $200 +
     SWAP 1 ANDN +                   --- merge 7 msb of data
     row C@ cols * col @ +           --- write to the current screen position
      2* screen + W!
     col ++                       --- increment column position
     ;

pri vtab
    BEGIN BL VCHAR col @ 7 AND 0= UNTIL        --- spaces until the next tab slot
    ;

[PRIVATE
--- big font parameters ---
7    == fx
9    == fy
WORD    font
PRIVATE]


14    == bigch

--- Plot or unplot a point (tile) at current XY
pub PLOT        IF bigch ELSE BL THEN VCHAR ;
--- Use big digits on the display ( 0..9 ) - Usage: BIG 1234 PRINT

10 BYTES sp PRIVATE --- blank character

pri .font ( ch -- )
     $30 - DUP 0 9 WITHIN NOT IF DROP sp ELSE fy * font W@ + THEN
\    DUP $30 $3F WITHIN NOT IF DROP $3A THEN    --- replace out-of-range with blank
\    $30 - fy * font W@ + fy ADO
       fy ADO
      I C@ BL fx - REV fx 1+ FOR DUP 1 AND PLOT 2/ NEXT DROP
\      BL VCHAR fx 1+ NEGATE col +! row C++
     fx 1+ NEGATE col +! row C++
    LOOP
    fy NEGATE row C+! fx 1+ col +!
    ;

--- 5x7 dot matrix font for big digits 0..9 0123456789:;<=>?
TABLE font5x7 PRIVATE
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %01110 | %10001 | %10011 | %10101 | %11001 | %10001 | %01110 |    --- 0
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %00100 | %01100 | %00100 | %00100 | %00100 | %00100 | %01110 |    --- 1
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %01110 | %10001 | %00001 | %00010 | %00100 | %01000 | %11111 |    --- 2
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %11111 | %00010 | %00100 | %00010 | %00001 | %10001 | %01110 |    --- 3
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %00010 | %00110 | %01010 | %10010 | %11111 | %00010 | %00010 |    --- 4
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %11111 | %10000 | %11110 | %00001 | %00001 | %10001 | %01110 |    --- 5
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %00110 | %01000 | %10000 | %11110 | %10001 | %10001 | %01110 |    --- 6
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %11111 | %10001 | %00001 | %00010 | %00100 | %00100 | %00100 |    --- 7
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %01110 | %10001 | %10001 | %01110 | %10001 | %10001 | %01110 |    --- 8
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
    %01110 | %10001 | %10001 | %01111 | %00001 | %00010 | %01100 |    --- 9
     --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

pub 5X7  5 7 font5x7
pub bigfont ( x y table -- )
     font W! ' fy 1+ ! ' fx 1+ ! ' .font uemit W!
     ;
ALIAS 5X7 BIG



--- dot matrix font for big digits 0..9 0123456789:;<=>?
TABLE font7x9 PRIVATE


\    %CHAR= 0
    %0111110 |
    %1000001 |
    %1000011 |
    %1000101 |
    %1001001 |
    %1010001 |
    %1100001 |
    %1000001 |
    %0111110 |

\    %CHAR= 1
    %0001000 |
    %0011000 |
    %0101000 |
    %0001000 |
    %0001000 |
    %0001000 |
    %0001000 |
    %0001000 |
    %0111110 |

\    %CHAR= 2
    %0111110 |
    %1000001 |
    %0000001 |
    %0000010 |
    %0011100 |
    %0100000 |
    %1000000 |
    %1000000 |
    %1111111 |

\    %CHAR= 3
    %0111110 |
    %1000001 |
    %0000001 |
    %0000001 |
    %0011110 |
    %0000001 |
    %0000001 |
    %1000001 |
    %0111110 |

\    %CHAR= 4
    %0000010 |
    %0000110 |
    %0001010 |
    %0010010 |
    %0100010 |
    %1000010 |
    %1111111 |
    %0000010 |
    %0000010 |

\    %CHAR= 5
    %1111111 |
    %1000000 |
    %1000000 |
    %1111100 |
    %0000010 |
    %0000001 |
    %0000001 |
    %1000010 |
    %0111100 |

\    %CHAR= 6
    %0011110 |
    %0100000 |
    %1000000 |
    %1000000 |
    %1111110 |
    %1000001 |
    %1000001 |
    %1000001 |
    %0111110 |

\    %CHAR= 7
    %1111111 |
    %1000001 |
    %0000010 |
    %0000100 |
    %0001000 |
    %0010000 |
    %0010000 |
    %0010000 |
    %0010000 |

\    %CHAR= 8
    %0111110 |
    %1000001 |
    %1000001 |
    %1000001 |
    %0111110 |
    %1000001 |
    %1000001 |
    %1000001 |
    %0111110 |

\    %CHAR= 9
    %0111110 |
    %1000001 |
    %1000001 |
    %1000001 |
    %0111111 |
    %0000001 |
    %0000001 |
    %0000010 |
    %0111100 |

pub 7X9   7 9 font7x9 bigfont ;



TABLE font6x8 PRIVATE

    ---  @0 '0' (5 pixels wide) */
    %00001110 | ---  ###
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00001110 | ---  ###

    ---  @8 '1' (5 pixels wide) */
    %00000100 | ---   #
    %00001100 | ---   ##
    %00000100 | ---   #
    %00000100 | ---   #
    %00000100 | ---   #
    %00000100 | ---   #
    %00000100 | ---   #
    %00001110 | ---  ###

    ---  @16 '2' (5 pixels wide) */
    %00001110 | ---  ###
    %00010001 | --- #   #
    %00000001 | --- #
    %00000010 | ---  #
    %00000100 | ---   #
    %00001000 | ---    #
    %00010000 | ---     #
    %00011111 | --- #####

    ---  @24 '3' (5 pixels wide) */
    %00001110 | ---  ###
    %00010001 | --- #   #
    %00000001 | --- #
    %00000110 | ---  ##
    %00000001 | --- #
    %00000001 | --- #
    %00010001 | --- #   #
    %00001110 | ---  ###

    ---  @32 '4' (5 pixels wide) */
    %00000010 | ---  #
    %00000110 | ---  ##
    %00001010 | ---  # #
    %00010010 | ---  #  #
    %00011111 | --- #####
    %00000010 | ---  #
    %00000010 | ---  #
    %00000010 | ---  #

    ---  @40 '5' (5 pixels wide) */
    %00011111 | --- #####
    %00010000 | ---     #
    %00010000 | ---     #
    %00011110 | ---  ####
    %00000001 | --- #
    %00000001 | --- #
    %00010001 | --- #   #
    %00001110 | ---  ###

    ---  @48 '6' (5 pixels wide) */
    %00000110 | ---  ##
    %00001000 | ---    #
    %00010000 | ---     #
    %00011110 | ---  ####
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00001110 | ---  ###

    ---  @56 '7' (5 pixels wide) */
    %00011111 | --- #####
    %00000001 | --- #
    %00000010 | ---  #
    %00000010 | ---  #
    %00000100 | ---   #
    %00000100 | ---   #
    %00001000 | ---    #
    %00001000 | ---    #

    ---  @64 '8' (5 pixels wide) */
    %00001110 | ---  ###
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00001110 | ---  ###
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00001110 | ---  ###

    ---  @72 '9' (5 pixels wide) */
    %00001110 | ---  ###
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00010001 | --- #   #
    %00001111 | --- ####
    %00000001 | --- #
    %00000010 | ---  #
    %00001100 | ---   ##

pub 6X8   6 8 font6x8 bigfont ;




pri VCTL ( ctl -- )
    SWITCH
    1 vflg SET? 0= IF                       --- force as data?
      $1B CASE 1 vflg SET BREAK                    --- ESC will accept next byte as data
      $01 CASE vhome BREAK
      $09 CASE vtab BREAK
      $08 CASE col @ IF col -- THEN BREAK
      $0D CASE col ~ BREAK
      $0A CASE newline BREAK
      $0C CASE clear BREAK
      $10 $17 SWITCH@ WITHIN IF SWITCH@ HUE BREAK        --- codes $10..$17 select a color
     $18 CASE $80 vflg CLR BREAK                --- wrap
     $19 CASE $80 vflg SET BREAK                --- no word wrap
    THEN
    SWITCH@ VCHAR 1 vflg CLR                    --- treat as data then
    ;

pub VEMIT ( ch -- )
    DUP BL < IF VCTL ELSE VCHAR THEN
    ;


--- make the VGA display the current output device
pub VGA        !VGA ' VEMIT uemit W! ;




--- BOX DRAWING USING GRAPHICS FONTS ---

    --- Line drawing using Turtle graphics ---

BYTE tdir        --- state of last turtle direction

pri L1
    tdir C@ SWITCH
    8 CASE row C++ $9E VCHAR BREAK
    2 CASE row C-- $9C VCHAR BREAK
    $90 VCHAR
    ;
pub LEFT        FOR L1 4 tdir C! -2 col +! NEXT ;

pri R1
    tdir C@ SWITCH
    2 CASE row C-- $9D VCHAR BREAK
    8 CASE row C++ $9F VCHAR BREAK
    $90 VCHAR
    ;
pub RIGHT        FOR R1 6 tdir C! NEXT ;

pri U1
    tdir C@ SWITCH
    6 CASE col -- $9C VCHAR BREAK
    4 CASE $9D VCHAR BREAK
    $91 VCHAR
    ;
pub UP        FOR U1 8 tdir C! col -- row C-- NEXT ;

pri D1
    tdir C@ SWITCH
    6 CASE $9E VCHAR BREAK
    4 CASE $9F VCHAR BREAK
    $91 VCHAR
    ;
pub DOWN        FOR D1 2 tdir C! col -- row C++ NEXT ;

--- Draw a box at current XY using text symbols for lines via turtle commands
pub BOX ( width height -- ) OVER RIGHT DUP DOWN SWAP LEFT UP 1 RIGHT ;

--- general-purpose TEXTBOX function - box in current color and text in specified color
--- Usage: red " HELLO WORLD" 10 3 TEXTBOX
pub TEXTBOX ( color str x y -- )
    OVER 1- OVER 1- vxy 3RD LEN$ 1+ 3 BOX
    vxy SWAP HUE VGA PRINT$
    ;


{
--- EXTRAS ---


    --- simple logic analyser ---

BYTE lacur
TABLE waves    $81 | $82 | $85 | $86 |
pub .LA    ( long -- )    BL 0 DO I lacur C@ = IF 2 ELSE 7 THEN HUE DUP 30 SHR 3 AND waves + C@ VCHAR 2* LOOP DROP ;

--- simple logic analyser display - usage: $4000 14 LA or vhome $4000 14 LA
pub LA ( addr longs -- )    2* 2* ADO I @ .LA 4 +LOOP CON ;

pub LADEMO
    17 lacur C!
    VGA 2 HUE CLS VGA PRINT"     TACHYON LOGIC ANALYSER     "
    0 2 vxy 7 HUE $FF80 12 LA
    VGA 4 HUE 13 1 DO 0 I 1+ vxy I $10 PRINTNUM LOOP
    1 1 vxy 1 HUE 30 14 BOX
    CON
    ;


TIMER demotime

pub DEMO1
    VGA CLS
    --- draw boxes within boxes
    7 0 DO I I vxy 7 I - HUE 30 I 2* - 15 I 2* - BOX LOOP
    7 7 vxy VGA PRINT"   TACHYON FORTH  "
    CON
    ;


    --- CIRCUIT COMPONENTS  ---

: DIODE            $A6 VCHAR $A7 VCHAR ;
: NPN            $1C VCHAR $1E VCHAR ;
: PNP            $1C VCHAR $1F VCHAR ;
: PHOTO            $1D VCHAR $1E VCHAR ;
: INDUCTOR             $B7 VCHAR $B8 VCHAR ;
: WIRE ( type -- )    $90 + VCHAR ;
: LED            $A6 VCHAR $A8 VCHAR ;
: CAP            $AB VCHAR ;
: RESISTOR            $BD VCHAR $BE VCHAR ;
: PORT ( dir -- )     1 AND $BA + VCHAR ;
: GND            $18 VCHAR ;
: VCC            $17 VCHAR ;

pub DEMO3
    VGA CLS 7 HUE
    3 1 vxy PRINT" TACHYON FORTH"
    2 0 vxy 14 3 BOX

    --- box within a box
    14 3 vxy 2 HUE 4 4 BOX
    6 HUE
    15 4 vxy 2 2 BOX
    --- 2 big digits
    4 HUE 19 0 vxy BIG 28 . VGA

    --- draw a circuit
    0 3 vxy 1 HUE VCC
    CR 13 WIRE 0 WIRE RESISTOR 0 WIRE LED 0 WIRE 11 WIRE 0 WIRE 1 PORT PRINT" rst"
    CR 0 PORT 0 WIRE RESISTOR 0 WIRE CAP 0 WIRE NPN
    CR TAB GND

    --- display all Parallax font characters and colors
    0 7 vxy  0 HUE $100 0 DO I HUE I VCHAR LOOP
    CON
    ;

byte demo#
pub DEMO0
    demotime TIMEOUT? 0EXIT
    2000 demotime TIMEOUT
    demo# C@ SWITCH
    demo# C++
    0 CASE DEMO1 BREAK
    1 CASE LADEMO BREAK
    2 CASE DEMO3 BREAK
    demo# C~            --- reset sequence but let it time out normally
    ;

pub DEMO
    PRINT" Demonstration of VGA 32x15 Text and \"graphics\" "
    keypoll W@ IF keypoll W~ ELSE ' DEMO0 keypoll W! THEN
    ;
}

{ BUILD INFO
SMALL BUILD
NAMES:  $6CC0...715F for 1,183 bytes (+384)
CODE:   $0924...6371 for 23,117 bytes (+1,216)
}

]~ END

?BACKUP

