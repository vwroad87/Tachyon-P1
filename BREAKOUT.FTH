TACHYON [~

FORGET BREAKOUT.fth
pub BREAKOUT.fth    PRINT" BREAKOUT GAME  using 32x15 VGA text 150625.1400 " ;

{ BREAKOUT for 32x15 VGA text 
Use VGA Explorer binary then load this source into it by copy and pasting through the terminal
Use Teraterm or minicom or some terminal that supports pasting and 10ms line delay.


NAMES:  $6ABF...715F for 1,696 bytes (+513)
CODE:   $0924...681A for 24,310 bytes (+1,193)
}

IFDEF HZ
10     == audio            --- square wave output audio

TIMER duration

--- init sound
pri !SOUND
    audio APIN
    MUTE
     0 duration TIMEOUT        --- setup duration timer
    ;
pri ?SOUND
     duration TIMEOUT? IF MUTE THEN
    ;

--- hitting a wall sound
pub BONK        
    audio APIN
    300 HZ 50 duration TIMEOUT
;
}
IFNDEF HZ    --- allow for compact build - skip sound 
pri  BONK ;
pri !SOUND ;
pri ?SOUND ;
}
--- palette to suit game
TABLE gamepal
---     RRGGBB    RRGGBB        
    %100000 | %000000 |        --- red on black
    %001000 | %000000 |        --- green on black
    %000010 | %000000 |        --- blue
    %111100 | %000000 |        --- yel
    %100010 | %000000 |        --- mag
    %001010 | %000000 |        --- cyan
    %010101 | %000000 |        --- gry
    %101010 | %000000 |        --- white

0        == red
1        == grn
2        == blu
3        == yel
4        == mag
5        == cyan
6        == gry
7        == wht    

3        == backwall        --- back of the brick wall - leave room for the ball to bounce behind

$7F00        == bram
$03FC        == bval

BYTE score,balls

pri BRICKS? ( -- cnt )
    score C~
     backwall cols * 2* screen + cols 4 * 2* 
     ADO I C@ 14 <> IF score C++ THEN 2 +LOOP
    ;
--- calculate how many bricks have been removed and display
pri .SCORE
    BRICKS?
    grn HUE cols 7 - 0 XY 
     VGA score C@ $30A PRINTNUM PRINT" /128"
    <CR> balls C@ . PRINT"  balls"
     ;

--- ball position variables
WORD    bx,by,abx,aby    
BYTE    bdir

--- Set the ball direction
pub BDIR! ( n -- )        $0F AND bdir C! ;

--- initialize the brick wall with 4 rows of random colored bricks/tiles from backwall (gap)
pub WALL
    0 backwall XY cols 4 * FOR RND 8 SHR 7 AND HUE 14 VCHAR NEXT
    ;


{ Here's an interesting one-liner that you can run immediately based on wall
!VGA BEGIN home cols rows * FOR RND 8 SHR HUE 14 VCHAR NEXT 200 ms ESC? UNTIL

!VGA BEGIN home cols rows * FOR RND 8 SHR DUP HUE 8 AND IF 14 ELSE BL THEN VCHAR NEXT 200 ms ESC? UNTIL

}



{ The ball is drawn with a single character but by using codes which force the driver to access RAM
for the font we can have finer movement by drawing a ball character dynamically in x 16x32 matrix
Use code $3FA to access table at $7E80
This routine is essentially the same as VCHAR but optimized for directly writing without scroll 
Execution time: 48.8us
}
pub VCHAR! ( ch -- )                --- 10-bit character
    DUP 1 AND color C@ 2* +           --- (color << 1 + c & 1 )
    2* 1+ 9 <<                    --- form color field
    SWAP 1 ANDN +                   --- merge 7 msb of data
    row C@ 5 << col C@ +               --- current screen position
     DUP 960 <
     IF 
       2* screen + W!                --- write to the screen word
      col C++                       --- increment column position
      ELSE 
      2DROP
     THEN
    ;


TIMER balldly                            --- timeout leads to next ball movement
WORD speed


{
--- plot ball as 2x2 block - 256x240
pub DRAWBALL ( x y -- )
    OVER 3 >> OVER 4 >> XY                     --- address the screen position for the tile - 17.2us
     bval VCHAR!                            --- maps to programmable char at $7E80 - 63.6us
     SWAP 7 AND 2* 2* $0A SWAP SHL                --- generate a dot in the correct x position - 7.8us
     bram 128 ERASE                        --- wipe the character clean - 64.6us
     ( y mask )
    SWAP >N 3 >> bram + ( mask addr )             --- calculate y position in character - 8.4us
\     SWAP OVER ! DUP 4 + 12 CMOVE                 --- store the mask in n consecutive longs - 15us
     2DUP ! 4 + !
    ;
pub NOBALL        
bx W@ 3 >> by W@ 4 >> XY
BL VCHAR! 
;
}

--- rebound translation table looks up the corresponding rebound direction ( 7 into left returns with 9 )
TABLE rebound
---    0   1   2   3   4   5   6   7   8   9
    0 | 7 | 8 | 9 | 6 | 5 | 4 | 1 | 2 | 3 |             --- bottom/top rebound
    0 | 3 | 8 | 1 | 6 | 5 | 4 | 9 | 2 | 7 |             --- left/right rebound

--- bounce the ball back
pub BOUNCE ( table-offset -- )
     rebound +                            --- lookup the table for the rebound action
     bdir C@ + C@ BDIR!                        
     BONK                                --- make a sound
    ;

--- read the contents of the screen cell/tile where the ball will be next
pri BALL@ ( -- word )
     bx W@ 2/ 2/ by W@ 3 >> cols * + 2* screen + W@
    ;

pri NEWBALL        
     0 BDIR! 
\\\ 64 2 <<  abx W! 60 2 << aby W!
64  bx W! 60  by W!
50 speed W! 1 BDIR! 
1500 balldly TIMEOUT                        --- delay serving 1st ball for 1.5secs
pub BALL
\\\     abx W@ 2 >> bx W! aby W@ 2 >> by W!            --- convert accumulated fractional x and y into ball x and y
    bx W@ cols 2* 2* MIN bx W!                     --- limit ball x
     by W@ rows 2* 2* 2* MIN by W!                --- limit ball y

    BALL@    >B BL "z" WITHIN NOT IF 0 BOUNCE EXIT THEN    --- bounce off special tiles (not blank or alphanumeric)
      by W@ rows 3 << 1- =>  IF 0 BOUNCE EXIT THEN        --- bounce off bottom
     by W@ 1 < IF 0 BOUNCE EXIT THEN                --- bounce off top
    bx W@ 0= IF 10 BOUNCE EXIT THEN                --- bounce off left wall
     bx W@ 2/ 2/ cols => IF 10 BOUNCE EXIT THEN        --- bounce off right wall
pub DRAWBALL ( -- )                            --- plot ball as 4x4 block - 185us
      wht HUE bx W@ by W@ 
    OVER 2/ 2/ OVER 2/ 2/ 2/ XY                 --- address the screen position for the tile - 17.2us
     bval VCHAR!                            --- maps to programmable char at $7E80 - 63.6us
     SWAP 3 AND 2* 2* 2* $AA SWAP <<                --- generate a dot in the correct x position - 7.8us
     bram 128 ERASE                        --- wipe the character clean - 64.6us
    SWAP 7 AND 4 << bram + ( mask addr )             --- calculate y position in character - 8.4us
     SWAP OVER ! DUP 4 + 12 CMOVE                 --- create the pattern
    ;


pub NOBALL        
bx W@ 2/ 2/ by W@ 3 SHR XY
BL VCHAR! 
;

--- setup constants for ball x and y movement increments which contain 2 fractional bits
1    == abxcon
1    == abycon
pri BALL+! ( x y -- )
     NOBALL
     by W+! bx W+!
    BALL
    ;

--- Check if ball is ready for next movement and proceed
pub ?BALL
    balldly TIMEOUT? 0EXIT                    --- ready yet?
    speed W@ balldly TIMEOUT                    --- yes, set next timeout period
    bdir C@ SWITCH                            --- proceed using the ball direction

    7 CASE abxcon NEGATE abycon NEGATE BALL+! BREAK
\    8 CASE NOBALL aby W-- BALL BREAK
    9 CASE abxcon abycon NEGATE BALL+! BREAK    
\    4 CASE NOBALL abx W-- BALL BREAK
\    6 CASE NOBALL abx W++ BALL BREAK
    1 CASE abxcon NEGATE abycon BALL+! BREAK
\    2 CASE NOBALL aby W++ BALL BREAK
    3 CASE abxcon abycon BALL+!  BREAK
    ;



BYTE px,py        --- paddle xy

$8E88        == mypad        --- two characters that make up the paddle
$2020        == nopad

pub PADDLE ( shape -- )
    yel HUE
    px C@ py C@ XY W>B VCHAR VCHAR        --- draw the paddle
    ;


--- PADDLE MOVEMENTS    
pub L    px C@ IF nopad PADDLE px C-- mypad PADDLE THEN ;
pub R    px C@ cols 2 - < IF nopad PADDLE px C++ mypad PADDLE THEN ;

--- check to see if the ball has hit the paddle and which change it's direction based on the edge hit
pub ?PADDLE
    mypad PADDLE
    ;

pri NEWPADDLE        rows 1- py C! 15 px C! mypad PADDLE ;


IFNDEF TEXTBOX
--- general-purpose TEXTBOX function - to be added into VGA.fth
pub TEXTBOX ( color str x y -- )
    wht HUE OVER 1- OVER 1- XY 3RD LEN$ 1+ 3 BOX
     XY SWAP HUE VGA PRINT$
    ;
}


pub GAMEOVER            red " GAME OVER" 11 8 TEXTBOX ;

pub NEWGAME
     VGA CLS NEWPADDLE NEWBALL WALL
     7 0 XY 2 HUE PRINT"  TACHYON BREAKOUT "
     3 balls C! score C~
    ;
{
pub GAMESTATS
    CR PRINT" Ball at " bx W@ . SPACE by W@ .
     PRINT" - direction/speed =" bdir C@ . SPACE speed W@ .
    ;
}

--- game control keys ---    
pub GAMEKEY
    SWITCH
    "Z" CASE L BREAK
    "X" CASE R BREAK
    "R" CASE REVERSE BREAK
    "+" CASE speed W-- BREAK
    "-" CASE speed W++ BREAK
    "B" CASE NOBALL NEWBALL BREAK
    $0D CASE NEWGAME BREAK
    SWITCH@ "0" "9" WITHIN IF SWITCH@ BDIR! BREAK
\    ^D CASE CON GAMESTATS CR CONSOLE BREAK
    $1B CASE GAMEOVER CON CONSOLE BREAK
    ;

IFNDEF SMALL
pub SPLASH
      VGA CLS
     --- draw boxes within boxes
     7 0 DO I I XY 7 I - HUE 30 I 2* - 15 I 2* - BOX 50 ms LOOP
     7 7 XY VGA PRINT" TACHYON  BREAKOUT"
     1 second 8 FOR REVERSE 100 ms NEXT
     10 FOR home cols rows * FOR RND 8 SHR DUP HUE 8 AND IF 14 ELSE BL THEN VCHAR NEXT 100 ms NEXT
    ;
}
IFDEF SMALL
pri SPLASH ;
}

pub ACTION
     130 score C@ - 3 / speed W!                --- make it speed up proportionaly to the score
      KEY UPPER GAMEKEY
     ?BALL 
     ?PADDLE
     ?SOUND
     .SCORE
     score C@ 128 = IF NEWGAME THEN                --- testing: start a new game 
     ;

pub BREAKOUT
     !VGA !SOUND
    gamepal setcolors
     2 seconds SPLASH                         --- wait for VGA monitor to stabilize then SPLASH screen
    NEWGAME                            --- start a new game
pub RESUME
    30 FLOAT
     VGA 
     BEGIN
       ACTION
    AGAIN
;    

\ { --- to run this in it's own cog 

FORGET BREAKOUT

$80 BYTES bregs
8 LONGS gstk

BYTE nkey
: NK        nkey C@ nkey C~ ;
: NULLIO    ' NK ukey W! NULLOUT ;
pub BREAKOUT
     gstk SP! !SP !RP
     $24 bregs $80 CMOVE
     bregs 7 COGREG!
    NULLIO
    !VGA
    gamepal setcolors
    NEWGAME                            --- start a new game
    BEGIN
      ACTION
    AGAIN
;    

pub GAME    $7F80 SP! ' BREAKOUT 3 RUN ;

--- dump screen to serial

: LOOK
    2 SPACES "_" cols EMITS
    @VGA rows cols * 2* ADO
      CR PRINT"  |" I cols 2* ADO
        I C@ I 1+ C@ 2 >> 1 AND OR
        DUP BL < IF DROP "=" THEN
        DUP $F0 > IF DROP "*" THEN
        DUP $7E > IF DROP "-" THEN
        EMIT
      2 +LOOP 
    PRINT" |  "
    cols 2* +LOOP
    CR PRINT"  |" "_" cols EMITS "|" EMIT
    ;
: SPY    CLS $0C EMIT BEGIN HOME LOOK KEY $0D = UNTIL ;


}

{ Edit this online at:
https://docs.google.com/document/d/1qThzvhYGafeseKTnCaH1OMZC-dFfy0mKKE-DXlCpBfg/edit?usp=sharing

or open read-only at:
https://docs.google.com/document/d/1qThzvhYGafeseKTnCaH1OMZC-dFfy0mKKE-DXlCpBfg/pub

}
END


