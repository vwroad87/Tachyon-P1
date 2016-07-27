TACHYON

( DEFAULT IS NOW SMALL - NEED TO DEFINE EXPLORER or INCLUDE for more  )



( DEFAUULT BUILD IS SMALL SO BE SURE TO "CREATE EXPLORER" BEFOREHAND IF YOU WANT EVERYTHING )
( Use latest V2,9 kernel or greater )
{
( general set of includes when building an expanded TF with filesystem. )
: INCLUDE
\  .......TICASS.ARR.MSSNHP_PCLOM.....
\  .......ETNDAT.NET.APEUEW-IHORA.....
\  .......RCTCNR.SPC.PRRMXM_NRCGT.....
\  33_2222222222_1111111111_0000000000
\  10_9876543210_9876543210_9876543210
  %00_0000101001_1110010100_1101100000
;
}
}

{ INCLUDE MODULE NOTES

typical inlcude for larger systems

: INCLUDE
\  .......TICASS.ARR.MSSNHP_PCLOM.....
\  .......ETNDAT.NET.APEUEW-IHORA.....
\  .......RCTCNR.SPC.PRRMXM_NRCGT.....
\  33_2222222222_1111111111_0000000000
\  10_9876543210_9876543210_9876543210
  %00_0000101001_1110010100_1101100000
;


current list of modules
#0
#1
#2
#3
#4
#5 MODULE: MATHS_FUNCTIONS
#6 MODULE: FIXED_POSITION_VARIABLES
#7 MODULE: LOCAL_VARIABLES
#8 MODULE: CHARACTER_OUTPUT
#9 MODULE: PIN_I/O_OPERATIONS
#10 MODULE: PWM
#11 MODULE: HEX FILE LOAD & DUMP
#12 MODULE: NUMBER_PRINT_FORMATING
#13 MODULE:  PBASIC_STYLE_SERIAL_I/O
#14 MODULE:   EXAMINE_SPECIAL_PURPOSE_REGISTERS
#15 MODULE:   Memory Map Reporting
#16
#17
#18 MODULE: COMPILER REPORTING
#19 MODULE: ANSI_TERMINAL
#20 MODULE: STRINGS
#21 MODULE: SAN_FILTER
#22 MODULE: MCP3208_8_channel_ADC
#23 MODULE:   COUNTERS
#24 MODULE: INTERTASK_COMMUNICATIONS
#25 MODULE: TERSE COMMAND MODE
#26
#27
#28
#29
#30
#31


}

IFDEF EXTEND.fth
 COLD ( force a clean system as EXTEND.fth should be added first )
}


1 flags CLR 		\ don't echo while loading - more advanced filter set later
IFNDEF EXPLORER
pub EXTEND.fth		." Primary extensions to TACHYON kernel"
}
IFDEF EXPLORER
pub EXTEND.fth		." Tachyon Forth Propeller hardware debugger and explorer"
}
."  - 160721-2200" ;





DECIMAL
{ BASIC CODE which is NOT optional   } \ therefore not in a module:

pub @NAMES (   -- addr \ put the address of the names register on the stack )
 	names W@
	;

{ HELP @HATR ( -- atrptr )
Return with the pointer to the latest header attribute
}
pri @HATR
	@NAMES C@++ +
 	;

pub IMMEDIATE ( --   \ Set the "immediate" tag of the latest name in the dictionary )
 	BL @HATR SET
	;
IMMEDIATE
IFNDEF UNSMUDGE
pub UNSMUDGE ( --   )
 	$40 @HATR CLR
	;
IMMEDIATE
}

pub PRIVATE 	( -- )	       8 @HATR SET ;
pub PUBLIC	( -- ) 	8 @HATR CLR ;

\ 140827 Added ALIAS which also copies the attributes and bytecode - no extra vectors or code used
pub ALIAS ( <old> <new> -- )  IMMEDIATE
	[COMPILE] NFA' [COMPILE] GRAB C@++ + [COMPILE] CREATEWORD @HATR 3 CMOVE
;

ALIAS { HELP:
ALIAS { {HELP		\ preferred form to be compatible with Kernel source compiled through Prop Spin compiler

\ Same as NOP but high-level defs can be used as vectors, but kernel bytecodes such as NOP can't
pub NOOP ( --  \ do nothing - vectorable ) ;

pub OK ( on/off -- \ enable/disable OK prompts including the autospace )
	IF 0 ELSE ' NOOP THEN prompt 2+ W!
 	;

IFNDEF BIT!
pub ECHO ( on/off --  \ set the ECHO flag on/off for controlling output )
 	1 flags ROT
pub BIT! ( mask addr set/clr -- )
 	IF SET ELSE CLR THEN
 	;
}
IFDEF BIT!
pub ECHO ( on/off --  \ set the ECHO flag on/off for controlling output )
 	1 flags ROT BIT!
 	;
}

\ Strip out annoying linefeeds from the output during a source code load
pri LEMIT   	DUP $0A <> IF 8 REG W@ ?DUP IF CALL ELSE (EMIT) THEN ELSE DROP THEN ;

\ start of load symbol - suppress console interaction
pub [~
	OFF ECHO OFF OK
	uemit W@ 8 REG W! ' LEMIT uemit W!
\	ukey W@ 0= IF $7F00 rx W@ - rx 2+ W! THEN
	;

\ end of load symbol - reenable interactive console
pub ]~  		ON ECHO ON OK 8 REG W@ uemit W! ;

[~			\ Now run in quiet mode with no echo and LF suppression



\ ******************* TACHYON FORTH KERNEL EXTENSIONS + I2C BUS ROUTINES *********************


\ Create a dummy word to ignore form feed characters - renamed to the ^L control character
pub a	; $0C @NAMES 1+ C!

{ maybe a module with debug tools and maybe a second with interactive terminal words -
would be great to put somewhere near the end of the file to optionally load in }

IFDEF EXPLORER
\ if you later decide you need a private word for debugging etc.
\ use this before issuing RECLAIM to keep the word around accessible
pub UNPRIVATE ( <word> -- )  8  [COMPILE] NFA' [COMPILE] GRAB DUP C@ + 1+ CLR ;
IMMEDIATE
}
{ \ meanwhile kernel version is already public - no need for this any more
\ Now redefine pub to enforce a non-private attribute - so disable kernel version first
0 NFA' pub 1+ C!		\ disable kernel version of pub

: pub			[COMPILE] : PUBLIC ; IMMEDIATE
}

\ Set the default for all names to PRIVATE
pub [PRIVATE		8 flags SET	;
pub PRIVATE]	 	8 flags CLR	;



pub ... 	( --  \ separator for readability ) ; IMMEDIATE
ALIAS ... ok	\ To be able to copy&paste from the terminal including "ok" responses

\ Commenting aliases - a bit of flexibility to make comments stand out besides the \ and ( ) methods
ALIAS \ \\\		\ normally used to disable a section of code
ALIAS \ //		\ alt C++ style comment
ALIAS \ ---		\ spaces out the comment from the code. --- ----- use space + more dashes for more spacing


\ Aliases for readability (and preferred over easily obscured traditional dot forms)
ALIAS . PRINT
ALIAS ." PRINT"
ALIAS OFF NO			--- using NO instead of OFF can read better (i.e. OFF PUMP or NO WATER)
ALIAS TRUE YES

ALIAS [COMPILE] [C]

ALIAS ; RETURN
ALIAS FOR TIMES
{ Add plain as day words such as TIMES instead of FOR etc.
Use it like this:

#P28 == LED    // assign port pin as the LED

pub BLINKY
    10 TIMES
      LED HIGH
      100 ms
      LED LOW
      100 ms
    NEXT
    RETURN

}

--- V2.10 corrects terminology where BFA is the byte field address in the header and CFA is always the code field itself
IFNDEF NFA>CFA
ALIAS BFA>CFA >PFA
}
IFDEF NFA>BFA
\ ALIAS NFA>CFA	NFA>BFA
: NFA>CFA	BEGIN C@++ $7F > UNTIL ;
}





{HELP CREATE$ ( str -- )
Create a new header in the dictionary
}
pub CREATE$ ( str -- )
 	DUP LEN$ DUP @word 1- C! @word SWAP CMOVE (CREATE)
 	;

{ MJB
each variable in memory takes the bytecode for var plus the size.
since the content is aligned to the content size some memory is lost
bytes following each other take 2 bytes memory each, alignment is no issue
words following each other need 3 bytes plus 1 byte wasted
longs following each other take 5 byte + 3 bytes wasted
so if you want to optimize before a long var there might be room for a free byte var

PBJ: If you want contiguous mixed variables it is best to use the ORG and DS words which allocate space in the ORG
region for "Data Storage". The "variable" name is actually a constant that points to this data area.
}
pub AVAR ( size align -- \ Create a variable of 1,2 or 4 bytes etc )
 	[COMPILE] GRAB						\ grab anything that has been entered earlier
 	"," delim C!						\ allow for comma delimited list
 	BEGIN
	  codes W@ OVER 1- ANDN OVER 1- + codes W!		\ align to a byte before
 	  [COMPILE] CREATE 					\ compile a VARB bytecode just before storage area
 	  OVER IF OVER FOR 0 [COMPILE] C, NEXT	THEN		\ zero the variable area
 	  delim 1+ C@ "," <> 					\ check for comma seperated lists of names
  	UNTIL
 	2DROP BL delim C!
 	;
IMMEDIATE
}
\ Define common variable sizes

pub DOUBLE		8 4 [COMPILE] AVAR ; IMMEDIATE
pub LONG		4 4 [COMPILE] AVAR ; IMMEDIATE
pub WORD		2 2 [COMPILE] AVAR ; IMMEDIATE
---
pub BYTE		1 1 [COMPILE] AVAR ; IMMEDIATE

\ Usage:  #256 LONGS pwmmap
pub LONGS	( n <name> -- )	[COMPILE] GRAB 4* 4 [COMPILE] AVAR ; IMMEDIATE
pri WORDS:	( n <name> -- )	[COMPILE] GRAB 2* 4 [COMPILE] AVAR ; IMMEDIATE
--- always align start of bytes array as a long
pub BYTES	( n <name> -- )	[COMPILE] GRAB 4 [COMPILE] AVAR ; IMMEDIATE


\ TABLE creates a long align structure which returns the address at runtime but does not allocate any memory yet
pub TABLE ( <name> --  | -- addr ) IMMEDIATE
	0 4 [COMPILE] AVAR
 	;

{
TABLE creates a long align structure which returns the address at runtime but does not allocate any memory yet
pub TABLE ( <name> --  | -- addr ) IMMEDIATE
	codes W@ 3 ANDN 3 + codes W!		'' align to a byte before a long address
 	[COMPILE] CREATE
 	;
}
pub CONSTANT IMMEDIATE
 	[COMPILE] GRAB
 	[COMPILE] TABLE			'' create and step back to override VARB
	-1 ALLOT
	' 0 1+ [COMPILE] BCOMP		'' compile a CONL instead (!!!! must be 23140602 kernel or later )
  	codes W@ 1+ !
 	4 ALLOT
 	;

ALIAS CONSTANT ==

pub !!SP		!SP $DEADBEEF ;	--- Init the datastack but leave a $DEADBEEF marker on it for stack debug

0 @	== 	CLKFREQ			--- Create a constant for CLKFREQ rather than accessing location 0 (corruption)


IFDEF V3
$28	==	_con
}
IFNDEF V3
$20	==	_con
}

BYTE pstkwr
8 LONGS pstk
{HELP PUSH ( n -- )
PUSH value onto global stack
}
pub PUSH	pstkwr C@ $1F AND pstk + ! 4 pstkwr C+! ;
pub POP		-4 pstkwr C+! pstkwr C@ $1F AND pstk + @ ;


LONG radix			\ 4 level deep radix stack
pub RADIX ( base -- \ Set number base )
 	?DUP IF base C! THEN
 	;
pub >RADIX ( base -- \ backup and set number base )
 	radix @ 8<< base C@ + radix ! RADIX
 	;
pub RADIX> ( -- \ restore previous radix )
 	radix @ DUP RADIX 8>> radix !
 	;


pri nout	DROP ;
pub NULLOUT	( -- \ set EMIT to discard characters like \dev0 )
	' nout uemit W!
 	;


\ almost all of the above is BASIC non optional, so should go before the optional modules, maybe some words from further down as well MJB.


\ minimal overhead EXTEND module loader

LONG mod2load  		\ collects the bitfield of the modules to be loaded

LONG modloaded 		\ collects the bitfield of the modules that have been loaded
0 modloaded  !

}

\ until the module loader is functional, all potential modules are set active
-1 mod2load  !
{
If we have defined a MODULES constant before loading EXTEND.fth then use it for mod2load
Usage:   : INCLUDE 7 MASK #24 MASK OR #17 MASK OR #13 MASK OR #18 MASK OR #15 MASK OR #14 MASK OR INVERT ;
alt - : INCLUDE !SP #7 #24 #17 #13 #18 #15 #14 #10 #21 #22 0 DEPTH 1- FOR SWAP MASK OR NEXT INVERT ;
alt - define INCLUDES in kernel: INCLUDES 1,2,3,4,5,6,8,9,11,12,16,19,20,23,25,26,27,28,29,30,31
alt = there must be a better way
So INCLUDE would NOT load those specified modules due to the INVERT mask
}
IFDEF INCLUDE
INCLUDE mod2load !
}

\ used to define the module table below
: SETMOD ( id <name> -- ) BL names W@ C@++ +
 SET \ IMMEDIATE   \ the <name> is only for comment purposes and ignored
    [COMPILE] GRAB					\  make id available on stack
    mod2load @ OR mod2load !				\  set the id bits in mod2load
    [COMPILE] \						\  consume and ignore the module <name> from the input line
    ;



\  now mod2load contains the mask for all EXTEND modules to be loaded


pri MODULE: ( modulenumber0..31 <modulename> )  \  the module name is just consumed and discarded
   [COMPILE] GRAB    					\ put the module number on the stack
\    GETWORD              				\  the module name is just consumed and discarded
   DUP MASK DUP mod2load @ AND
 	IF modloaded @ OR modloaded !  \ SET	\ load the module by just executing the definitions
\	  uemit W@ CON
	  PRINT"      INCLUDING #"
 	  DECIMAL SWAP . SPACE
 	  BEGIN KEY DUP $0D <> WHILE EMIT REPEAT 		\ treat anything that follows on this line as a comment (but echoed)
	  8 FOR SPACE NEXT EMIT
	  CR
\	uemit W!
	ELSE 2DROP [COMPILE] {     			\ else treat the block as a { } comment, similar to IFDEF  ... }
 	THEN ;
IMMEDIATE

{ usage:

#10 MODULE: PWM
 	\ module goes here
}  \ ends the module

}







#9 MODULE: PIN_I/O_OPERATIONS
( PIN I/O OPERATIONS )

IFNDEF P@ --- allow for removal of seldom used P@ and P! from kernel
pub P@ 	$1F2 COG@ ;
pub P!	$1F4 COG! ;
}

pub PIN! ( state pin -- )
 	MASK
'' Set one or more pins to high or low state
pub OUT ( state pinmask -- )
 	DUP OUTPUTS SWAP SHROUT 2DROP
 	;
'' Read a single input pin

pub PIN@ ( pin -- state )
 	MASK
pub IN ( pinmask -- state )
	P@ AND 0<>
 	;


\ pub HIGH? ( pin -- flg )	PIN@ ;
ALIAS PIN@ HIGH?
pub LOW? ( pin -- flg )		HIGH? 0= ;


\ Read input pins and right justify and mask - #P8 4 PINS@ - reads P8..P11 as a nibble
pub PINS@ ( pin for – n )
 	P@ ROT SHR SWAP MASK 1- AND
 	;

\ Build up a mask using a starting pin number and the number of consecutive pins
\ Useage:  #16 8 MASKS CONSTANT dbus
pub MASKS ( pin cnt -- mask )
	0 ROT ROT ADO I MASK OR LOOP
	;

pub PINS! ( data pin for -- )
	ROT 3RD SHL  ( pin for data<<pin )		--- shift data into correct position
 	ROT ROT MASKS ( data<<pin mask )		--- create mask
 	OUTCLR OUTSET
 	;


} \ end of   #9 MODULE: PIN_I/O_OPERATIONS







{HELP COGREG! ( dat index -- )
Each Tachyon cog has an set of registers for setting up masks etc which are used in repetitive operations.
These are referred to as COGREGs.
}
pub COGREG! ( dat index -- )
 	COGREG COG!
 	;
{HELP COGREG@ ( index -- dat )
Each Tachyon cog has an set of registers for setting up masks etc which are used in repetitive operations.
These are referred to as COGREGs.
}
pub COGREG@ ( ix -- dat \ fetch dat long from COG register with index ix )
 	COGREG COG@
 	;

\ WAITPxx instructions also capture the CNT into COGREG0 or 1
pub WAITPNE ( mask -- \ wait until pins are not equal to mask, then capture counter onto COGREG0 )
	3 COGREG! (WAITPNE)
 	;
pub WAITPEQ ( mask -- \ wait until pins are equal to mask, then capture counter onto COGREG1 )
	3 COGREG! (WAITPEQ)
 	;


( COUNTER )

IFDEF SPR@
pub CNT@		1 SPR@ ;
}
IFNDEF SPR@
pub CNT@		$1F1 COG@ ;
}

pub J 		3 LSTACK COG@ ;
pub K 		5 LSTACK COG@ ;
pub IX		0 LSTACK COG@ ;


IFNDEF LEAVE
\ make the loop index = to the limit so that it will leave on the next LOOP
pub LEAVE
	IX 1- 1 LSTACK COG!
	;
}

{HELP UNLOOP
Break out of a loop - uses a special loop index and loop branch stack
This was changed from BREAK to UNLOOP as BREAK is now a word used in CASE structures
}
pub UNLOOP  ( -- \ exit from loop )
 	L> L> 2DROP BRANCH> R> 2DROP
 	;

IFNDEF BOUNDS
\ Format a start and cnt into a to and from for DO (not required for ADO)
pub BOUNDS ( addr cnt -- to from )
 	OVER + SWAP
 	;
}

pub MIN ( n1 n2 -- n3 ) --- signed minimum of two items
 	OVER OVER > IF SWAP THEN DROP
 	;
pub MAX ( n1 n2 -- n3 ) --- signed maximum of two items
 	OVER OVER > IF SWAP THEN NIP
 	;

--- cacluate an average while maintaining fractional parts and return the average
--- Usage: 1000 <myvar> AVG
pub AVG ( val var -- avg )
	DUP @ 2/ 2/ ROT SWAP -
	OVER +! @ 2/ 2/
	;

IFNDEF >VEC
pub >VEC
    DUP 1+ C@ 4* XCALLS + SWAP C@ ' CALL 3 + -
    3 XOR SWAP OVER 1 AND 2* + SWAP 2 AND IF $400 + THEN
    ;

}
\ Convert the CFA (tick address) into a pointer to the name string
pub PFA>NFA ( pfa -- name )
	@NAMES 1+
	BEGIN
	  DUP NFA>CFA >PFA 3RD = IF NIP EXIT THEN
	  NFA>CFA 3 +
	  DUP C@ 0=
 	UNTIL
	2DROP 0
	;
ALIAS PFA>NFA >NAME ( cfa -- name$ )
pub CFA>NFA ( cfa -- nfa

````

( CONVERSION )

\ Conversion between longs, words, bytes

IFDEF BITS
pub >W ( long -- word  \ extract lower word from long )  		16 BITS ;
}
IFNDEF BITS
pub >W ( long -- word  \ extract lower word from long )
	16
pub BITS ( n1 bits -- )		MASK 1- AND ;
}


IFNDEF >B
pub >B ( long -- byte  \ extract lower byte from long )  		$FF AND ;
pub >N ( long -- byte  \ extract lower nibble from long )  		$0F AND ;
}
pub L>W ( long - loword hiword \ split long into 2 words ) 		DUP >W SWAP 16>> ;
pub W>B ( word - lobyte hibyte \ split word into 2 bytes ) 		DUP >B SWAP 8>> >B ;

pub W>L ( loword hiword -- long \ merge to words to long )		16<< OR ;
pub B>W	( lobyte hibyte -- word \ merge to bytes to word )		8<< OR ;
pub B>L ( lobyte byte2 byte3 byte4 -- long \ merge 4 bytes to long )	B>W >L B>W L> W>L ;

\ Increment and decrement variables at address
pub ++ ( longAddr --  \ increment long )				1 SWAP +! ;
pub -- ( longAddr --  \ decrement long )				-1 SWAP +! ;
pub W++ ( wordAddr -- \ increment word )				1 SWAP W+! ;
pub W-- ( wordAddr -- \ decrement word )				-1 SWAP W+! ;
pub C++ ( byteAddr -- \ increment byte )				1 SWAP C+! ;
pub C-- ( byteAddr -- \ decrement byte )				-1 SWAP C+! ;

\ Clear and set variable at address
pub ~   ( longAddr -- \ clear long )					0 SWAP ! ;
pub ~~  ( longAddr -- \ set long   )					-1 SWAP ! ;
pub W~  ( wordAddr -- \ clear word )					0 SWAP W! ;
pub W~~ ( wordAddr -- \ set word   )					-1 SWAP W! ;
pub C~  ( byteAddr -- \ clear byte )					0 SWAP C! ;
pub C~~ ( byteAddr -- \ set byte   )					-1 SWAP C! ;

IFDEF EXTRAS
pub SWAPB ( word -- word2 	\ Swap the bytes in a 16-bit word )
 	DUP 8>> SWAP >B 8<< OR
;

pub LBIT! ( mask addr state -- 	\ Set or clear the bits of a long in memory that match the bit mask. )
	>L SWAP OVER @ L> IF OR ELSE SWAP ANDN THEN SWAP !
;

pub LONGFILL ( addr cnt longval -- 	\ Fill longs at addr for long cnt with longval )
 	3RD !			\ Store long at start address
	OVER 4 +		\ Set destination as next long address
 	SWAP 1- 4*	\ Adjust to byte count less the first long
	CMOVE			\ and copy over and over itself
	;
   }


#8 MODULE: CHARACTER_OUTPUT
( CHARACTER OUTPUT )

pub KEY@ ( -- keycode )		lastkey C@ ;

pub KEY! ( keycode -- )		lastkey 1+ C! ;

\ Wait for a period and if no key is received then return with a null
\ wait timer = wait*42us so #225 = 10ms
pub WAITKEY ( wait -- key )
	lastkey C~
 	  BEGIN KEY@ 0= OVER 0<> AND WHILE 1- REPEAT
 	KEY
 	;

pub <CR>  ( --  \ send a CR = $0D to output ) 	$0D EMIT ;

pub TAB   ( --  \ send a TAB = $09 to output ) 	9 EMIT ;

pub ESC? ( -- flg \ true if an escape has been pressed )
 	KEY@ $1B =
	;

pub GETLINE ( buf -- len )
    DUP BEGIN 0 OVER C! WKEY DUP $0D <> WHILE OVER C! 1+ REPEAT DROP SWAP -
    ;


\ Use alternative name to avoid conflict with FTP commands, also ensure controls are converted to spaces
pub CTYPE ( str cnt -- \ Type out the string for cnt characters )
 	ADO I C@ BL MAX EMIT LOOP
  	;

\ ALIAS CTYPE TYPE

pub SPACES ( cnt -- \ print many spaces )
 	BL SWAP
pub EMITS ( ch cnt -- \ emit the same character many times )
	?DUP IF FOR DUP EMIT NEXT THEN DROP
 	;




} \ end of   #8 MODULE: CHARACTER_OUTPUT


#7 MODULE: LOCAL_VARIABLES


( LOCAL VARIABLES )
{ Saving stack parameters to local variables can simplify the stack manipulation required
A specified number of parameters are removed and copied to the local variables area but first the
existing local variables are pushed up so that they are saved and can be restored with a RELEASE
To simplify the use of these variables any direct reference to them will automatically fetch the contents
rather than cluttering the code with @ after each instance.
Example of using LOCALs:
pri (RECT)
	X4 X3 X2 HLINE
	X4 X3 X1 1- + X2 1- HLINE
	X4 X2 + 1- X3 X1 VLINE
	X4 X3 X1 VLINE
	;
\ Draw a rectangle
pub RECT ( x1 y1 width height -- )
        ( X4 X3 X2    X1 )
	4 LOCAL (RECT) 4 RELEASE
}
\ space for up to 16 locals
16 LONGS locals

pri @X ( index -- )					4* locals + ;
pub X1  ( -- local1 \ push local 1 on the stack )	locals @ ;
pub X2  ( -- local2 \ push local 2 on the stack )	1 @X @ ;
pub X3  ( -- local3 \ push local 3 on the stack )	2 @X @ ;
pub X4  ( -- local4 \ push local 4 on the stack )	3 @X @ ;

pub LOCAL ( n -- \ pop the n top stack elements to the local space, TOS => X1, TOS+1 => X2 .. )
	locals OVER @X 3RD 4* $40 SWAP - <CMOVE 0 DO I @X ! LOOP
;
pub RELEASE ( n -- \ remove n elements from locals, of no longer used )
	DUP @X locals ROT 4* $40 SWAP - CMOVE
;

locals $40 ERASE			\ Clean out the locals (easier for debugging)

} \ end of    #7 MODULE: LOCAL VARIABLES

#6 MODULE: FIXED_POSITION_VARIABLES

( FIXED POSITION VARIABLES )
{ Create fixed variables by borrowing from assembler syntax using an origin and specify number of bytes for each variable
This allows us to work from a fixed area in RAM and the variables end up being defined as constants.
Usage:
	$4000 ORG
	2	DS readptr		\ allocates 2 bytes for readptr at $4000
	2	DS writeptr		\ allocates 2 bytes for writeptr at $4002
	#64	DS mybuffer		\ allocates 64 bytes for mybuffer at $4004

or
	TABLE myvars #64 6 * ALLOT	\ allocate long aligned memory for 6 sets of 64 bytes
	myvars ORG				\ work from the start of the table
	#12	DS name
	4	DS offset
	\ etc

Test it out:
myvars . 2E30 ok
offset . 2E3C ok
}

LONG _org
pub ORG ( addr -- ) --- move addr to org variable as base address for DS and DS+ operations
	_org !	;


pub DS+  ( bytes -- ) --- allocate bytes without naming
	_org +! ;

pub DS ( bytes <name> -- )		--- allocate bytes and assign it the <name> literal following the DS word
	[COMPILE] GRAB			--- get the bytes
	_org @				--- get org, which is the start of this new variable
	SWAP _org +!			--- increment org by bytes length of this variable as base for next variable
	[COMPILE] CONSTANT		--- and compile the old org value into a constant named <name>
	;
IMMEDIATE				--- this needs to be done at compile time so make DS IMMEDIATE


{HELP The CONSTANT word is redefined to == to reduce the clutter and increase readability (IMO)
Since CONSTANT is an immediate word it is forced to compile with [COMPILE]
At some point the == word may work differently from CONSTANT by forcing the compilation of the literal constant
rather than the call to the definition. This is in part to allow constants to be defined simply for compilation
without consuming runtime memory
}
\ pub ==					[COMPILE] CONSTANT ; IMMEDIATE



IFDEF EXPLORER
( SPR COG REGISTERS )
	$1F0 ORG

0	DS SPR
1	DS PAR
1	DS CNT
1	DS INA
1	DS INB
1	DS OUTA
1	DS OUTB
1	DS DIRA
1	DS DIRB
1	DS CTRA
1	DS CTRB
1	DS FRQA
1	DS FRQB
1	DS PHSA
1	DS PHSB
1	DS VCFG
1	DS VSCL


\ Store data in the SPR (original version did not add offset)
pub SPR! ( data offset -- )
	SPR + COG!
 	;

    }
}  \  end of  #6 MODULE: FIXED_POSITION_VARIABLES

( MATHS FUNCTIONS )
--- basic maths functions - always load
pub U>    SWAP U< ;

pub /  ( n1 n2 -- n3 ) 					\ 18us signed divide (org 47us) vs 10us U/
  	OVER ABS OVER ABS U/ 				\ perform unsigned division
 	ROT ROT XOR -NEGATE				\ now get signs set result accordingly
 	;

pub UM*/ ( u1 u2 u3 -- Du1*u2/u3 )
 	ROT ROT UM* ROT UM/MOD64 ROT DROP
 	;


{HELP MOD ( n1 modulus -- rem )
Extract the remainder after division of n1 by modulus
Usage: 1234 10 MOD . 4 ok
}
pub MOD ( n1 mod -- rem )
 	U/MOD DROP
 	;

LONG (rnd)  PRIVATE
CNT@ (rnd) ! 				\ seed it at compile time

\ COMMENT: RND ( -- n )  Generate a 32-bit pseudo-random number enhanced with the system counter
pub RND ( -- n    \ 32 bit pseudo random number enhanced with system counter )
\ to seed with custom value use  “seed (rnd) !”
 	(rnd) @ DUP #13 SHL XOR
 	DUP #17 SHR XOR
 	DUP 5 SHL XOR
 	CNT@ * DUP (rnd) !			\ randomize the result as well using the system CNT
 	;

{
loop:
y = y – 1/16 * x
x = x + 1/16 * y

pub Minsky ( xOld yOld step -- xNew yNew )
	  >L SWAP OVER IX SAR - SWAP ( xNew yOld )
	  OVER L> SAR + ( xNew yNew )
	;
}
( MORE OPERATORS )
pub ALIGN ( address align -- val00  \ given align = 2^n set the n-1 lowest bits to 0
						\ align the address to a ‘align’ bytes border
\ n = 0 is byte align, n = 1 is word align, n = 2 is long align )
	1- SWAP OVER + SWAP ANDN ;
	;

LONG ulong PRIVATE
pub U!	( long addr --  \ Unaligned store long )
	SWAP ulong ! ulong SWAP 4 CMOVE
	;
pub U@	( addr -- long \ Unaligned fetch long )
	ulong 4 CMOVE ulong @
	;
ALIAS SHR >>
ALIAS SHL <<
ALIAS MASK |< ( bit -- mask 	\ SPIN syntax for MASK, bit is the 0-based position of the only one bit to set )

pub >| ( mask -- bit   	\ give the 0-based position of the highest bit set )
 	BL 0 DO 2/ DUP 0= IF DROP I LEAVE THEN LOOP
 	;

pub =>	( n1 n2 -- flg  \ true if n1 is equal to or greater than n2 )
1- > ;
pub <=	( n1 n2 -- flg  \ true if n1 is smaller than or equal to n2 )
	SWAP => ;


pub @.	( longAddr --  \ Fetch long and print number )
	@ U. ;

--- redefine ms and us to suit clkfreq
pub ms
 	?DUP 0EXIT CLKFREQ #1000 / UM* DROP DELTA
 	;


{ doesn't appear to be used anymore
16 == indent
pub .HEAD ( str -- \ Print the string as a header on a new line and space up to column 16 )
 \ or per user settings
 \ change the constant indent to your indent level
DUP #100 < IF ' indent 1+ ! ELSE CR DUP PRINT$ LEN$ indent SWAP - SPACES THEN
;
}

pub DPL ( -- n )	\ Return with number of decimal places
 	digits 1+ C@ DUP IF digits C@ SWAP - THEN
 	;
\ Flag next number print routine to use leading spaces instead of leading zeros
pub LSP 	4 flags SET ;


#5 MODULE: MATHS_FUNCTIONS

pub % ( val % -- val2 )		* 100 / ;
--- 8-bit binary percentage so that 256 %% = 100 %
pub %% ( val bin% -- val2 )	SWAP 1+ * 8>> ;

( RANDOM NUMBER GENERATOR )


\ Return with a random number between the specified limits from min to max-1
pub GETRND ( max min -- n )
	SWAP OVER - RND 2/ SWAP MOD SWAP +
 	;

{HELP ROUND
Round a number to the nearest rounding value
Usage: 474 10 ROUND -> 470
474 5 ROUND -> 475
}
pub ROUND ( n1 rounder -- n1rnd )
 	SWAP OVER U/MOD 				--- now round it off to the nearest 0.25MHZ
 	SWAP 2* 3RD => 1 AND + *
	;

pub /ROUND ( val1 divisor -- val2 	\ Scale down a value by a divisor but round it up
                                    \ if the remainder is => half the divisor
                                    \ Usage:4567 100 /ROUND . 46           )
   DUP >L U/MOD
   SWAP L> 2/ > IF 1+ THEN
   ;


IFDEF EXTRAS


pub COS ( angle -- cosine     		\ the angle is in radians scaled to ?? bits ?? )
     $800 +
pub SIN ( angle -- sine 			\ the angle is in radians scaled to ?? bits ?? )
    DUP $1000 AND SWAP                     \ test quadrant 3|4
    DUP $800 AND IF NEGATE THEN            \ test quadrant 2|4 and negate if true
    $7000 OR 2* W@                         \ lookup word from sin table
    SWAP IF NEGATE THEN                    \ if quadrant 3|4, negate sample
    ;


--- Powers
pub SQR  ( value -- value*value )
 	DUP *
 	;
pub POW ( n pwr -- n^pwr )
	1 SWAP FOR OVER * NEXT NIP
	;

IFDEF [SQRT]
--- RUNMOD version also loads the module - just use RUNMOD inside of loops
pub SQRT	[SQRT] RUNMOD ;
}



{
Square root method based on this Tristan Muntsinger algorithm which uses multiplication:
	unsigned int c = 0x8000;
	unsigned int g = 0x8000;

	for(;;) {
    	if(g*g > n)
        	g ^= c;
    	c >>= 1;
    	if(c == 0)
        	return g;
    	g |= c;
	}

Timing:
1234 DUP * LAP SQRT LAP .LAP SPACE .  296.800us 1234 ok
200000000 LAP SQRT LAP .LAP SPACE .  300.200us 14142 ok
355.000000 113 / LAP SQRT LAP .LAP SPACE .  294.600us 1772 ok
}
IFNDEF SQRT
pub SQRT ( n -- sqrt )
    $8000 DUP ( n c g )
    BEGIN
      DUP DUP * 4TH >   		--- if (g*g > n)
    	  IF OVER XOR THEN   		--- g ^= c
      SWAP 2/ ( n g c )   		--- c >>= 1
      ?DUP   				--- while c <> 0
    WHILE
      SWAP ( n c g ) OVER OR   	--- g |= c
    REPEAT
    NIP   				 	--- leave only g on stack
    ;
}

IFDEF c ( c added 150526 to fetch carry in lsb from last +/- op)
pub UM+ ( dbl n -- dbl ) ROT + c 1 AND ROT + ;


--- UMSQRT square root of long with scaled double to 5 decimal places 88.8us
pub UMSQRT ( n - dbl.5 ) DUP SQRT DUP DUP * ROT SWAP - 50000 3RD */ SWAP 100000 UM* ROT UM+ ;
}

3.14159265	== PI

pub CIRC ( radius -- circumference )
 	2* 355 113 */
 	;

--- calculate the hypotenuse
--- 14 25 LAP HYPOT LAP .LAP  360.000us ok
pub HYPOT ( A B -- hypot )
 	DUP * SWAP DUP * + SQRT
 	;
--- return with the hypot as a double scaled to 5 decimal places
pub DHYPOT ( A B -- hypot.nnnnn )
 	DUP * SWAP DUP * + UMSQRT
 	;

{ Quick hypotenuse calculation - longerside + shorterside*⅜
Error is less than 6.78% max - 3% mean error
Execution time: 14.4us
}
pub QHYPOT ( A B -- hypot )
 	2DUP < IF SWAP THEN
 	DUP 2* + 3 SHR +	\ *3/8
 	;

{ TEST: HYPOT function

pub HDEMO ( addr -- )
	$40 DECIMAL
 	ADO I W@ $7FFF AND I 2 + W@ $7FFF AND
	  CR OVER .DEC TAB DUP .DEC
 	  TAB PRINT" APPROX HYPOT=" 2DUP HYPOT DUP 0 REG ! .DEC TAB
 	  PRINT" HYPOT = " ^2 SWAP ^2 + SQR DUP .DEC
	  DUP 0 REG @ - ABS #10000 * SWAP /
 	  TAB PRINT" ERROR=" <# # # "." HOLD #S #> PRINT$ ." %"   \ calulate % error scaled to 2 decimal places
 	4 +LOOP
	;
}
}
}  \ end of  #5 MODULE: MATHS_FUNCTIONS

( NUMBER PRINT FORMATING )
#12 MODULE: NUMBER_PRINT_FORMATING
\ Check and insert separators (subfunction of .NUM)
pri (SEP)
	 I IF 1 REG C@ $40 AND 0EXIT
 	 base C@ #10 =
	   IF I 3 MOD 0= IF "," HOLD THEN				\ Process decimal numbers with a decimal point
	   ELSE I 4 MOD 0= IF "_" HOLD THEN				\ or else use underscore for a separator
	   THEN
	 THEN
	;
{ Usage: - testing
	WORD sep
pri InitSep ( digits base -- digits base )
	DUP #10 = IF $2C03 sep W! THEN
	DUP ":" = IF DROP #10 $3A02 sep W! THEN
	DUP "/" = IF DROP #10 $2F02 sep W! THEN
}

pri (.NUM) ( n val -- )
	<# 5 BITS ?DUP 						--- If there is a count (b4..b0) specified then lock to that
	  IF DUP #31 = IF 1+ THEN 0 DO (SEP) # LOOP		--- fixed width also 31(max) indicates 32 binary digits
	  ELSE BL 0 DO (SEP) # DUP 0= IF LEAVE THEN LOOP	--- variable width, don't print lz
	  THEN
	0 REG C@ ?DUP IF HOLD THEN
	#> PRINT$
	;
{HELP PRINTNUM ( number format -- )
Format the number as to it's base, the number of digits, whether it's signed, and should it have separators
This is a very versatile print number routine and can be incorporated into other print words
A single word is passed with options:
b07..00 = base
b12..08 = digits
b13	 = use spaces in place of leading zeros
b14	= force separators (decimals have a , every 3 places while others have a _ every 4 places)
b15	= force sign (always + or - depending upon the number)
Usage:
 	$C00A will force separators, sign, no leading zeros (0 digits), and a base of 10
i.e.	0 @ $C00A .NUM +80,000,000 ok
	$4810 will force separators, no sign, and 8 digits with a base of 16
i.e.	0 @ $4810 .NUM 04C4_B400 ok
}
pub PRINTNUM  ( number sign+sep+6BitForDigits+8BitForBase -- \ format number according to format spec )
	W>B SWAP
\	InitSep
	>RADIX
	0 REG C~							--- clear prefix for sign
	DUP 1 REG C!							--- save sign+sep+digits byte
 	DUP BL AND IF LSP THEN					--- select leading zero suppression
	DUP $80 AND							--- signed?
 	  IF OVER 0<
 	    IF "-" ELSE "+" THEN
 	    0 REG C!
 	  THEN
 	(.NUM)
	RADIX>
	;

--- deprecated name - prefer PRINTNUM for readability
ALIAS PRINTNUM .NUM


pub .DP ( dblnum decimals --- )
 	DUP >L 1 SWAP FOR #10 * NEXT UM/MOD64
 	<D> $400A PRINTNUM
 	L> ?DUP IF "." EMIT 8<< $0A + PRINTNUM THEN
	;

pub .DECX ( number -- \ Print a formatted decimal number with 4 digits )
 	4
pub PRINTDEC ( number n -- \ Print a formatted decimal number with at least n digits )
 	8<< $400A OR PRINTNUM
 	;


pub .INDEX	( -- \ Print the current loop index on a newline )
 	CR I .WORD PRINT" : "
 	;
pub .ADDR ( addr -- \ print address plus : )
	CR $4810 .NUM PRINT" : "
 	;
pub U.N ( data digits -- \ Print the unsigned number with the specified number of digits )
 	<# FOR # NEXT #> PRINT$
 	;

} \  end of   #12 MODULE: NUMBER_PRINT_FORMATING

{ built full version into kernel so DEBUG uses this too
1 NFA' .S ?DUP IF 1+ C! THEN
pub .DS
	."  Data Stack (" DEPTH $A .NUM ." ) "
 	DEPTH 0EXIT
 	#10 >RADIX
 	16 COGREG@ 8 + DEPTH 2* 2* OVER + ( stkptr end )
 	BEGIN CR "$" EMIT DUP @ DUP .LONG ."  - " PRINT 4 - 2DUP 4 -  = UNTIL 2DROP
 	RADIX>
 	;
}

16 BYTES NUM$
: NUM>STR ( num -- str )
	<# #S #> NUM$ 16 CMOVE
	NUM$
	;


CLKFREQ #1,000,000 / == #us
--- microsecond timing - trimmed to compensate down to 21us including stack parameter
--- So 21 us = 21 us but anything less will just exit early with 11us
pub us   	DUP #21 < IF DROP EXIT THEN #us UM* DROP #1610 - DELTA ;



--- CONSOLE EMIT uses the (EMIT) opcode to bit-bash serial data using
--- a txpin mask at COGREG 6 and baudrate at COGREG 5
pub SERIAL ( baud pin -- )
	MASK DUP OUTSET 6 COGREG! CLKFREQ SWAP / 5 COGREG!
	;


\\\ pub CONIO \ Change input and output device back to the default CONSOLE
\\\ 	0 ukey W!
pub CON
       _con @ 30 SERIAL		--- reset serial transmit parameters in case they've been changed
       uemit ~			--- reset emit and key vectors
       ;
ALIAS CON CONIO			--- * needs to be deprecated after revisions

LONG consav PRIVATE
--- switch I/O to console but save current device
pub [CON	uemit @ consav ! CON ;
--- retyrn from console and restore previous device
pub CON]	consav @ uemit ! ;




{ DUMP LISTING REDIRECTION
Dump words typically dump memoru which in the case of the Propeller is the hub RAM (&ROM)
However the dump read methods may be redirected to specific forms of memory, some being:
SD, WIZnet, SPI Flash, etc
If a dump memory modifier is used it will automatically revert back to RAM
}
3 WORDS: dmm	--- dump methods for C@ W@ @

--- define vectorable versions of memory fetches
pri _C@ C@ ; pri _W@ W@ ; pri _@ @ ;

--- Select RAM as the memory for DUMP methods
pub RAM	' _C@ dmm W! ' _W@ dmm 2+ W! ' _@ dmm 4 + W! ;
RAM

BYTE bdw PRIVATE --- controls word length of dump listing (bytes,words,longs)
1 bdw C!

pri (BDW)
	bdw C@ SWITCH
	2 CASE dmm 2+ W@ CALL .WORD BREAK
 	4 CASE dmm 4 + W@ CALL .LONG BREAK
 	dmm W@ CALL .BYTE
	;
pub BDUMP ( addr cnt buffer -- \ Dump listing from a buffer but use source addresses )
	4 REG ! SWAP 8 REG !
	0 SWAP ADO
	  I 8 REG @ + .ADDR
	  16 0
	  DO
	    I 3 AND 0=
	    I 7 AND 0= + NEGATE SPACES
	    I J + 4 REG @ + (BDW)
	    SPACE bdw C@
	  +LOOP
	  2 SPACES
	  I 4 REG @ + 16 ADO I dmm W@ CALL DUP BL $7E WITHIN 0= IF DROP "." THEN EMIT LOOP
	16 +LOOP
 	1 bdw C! RAM				--- reset defaults for byte wide and RAM
	;


pub DUMPL ( addr cnt -- ) 	4 bdw C!
pub DUMP ( addr cnt -- ) 	OVER BDUMP ;
pub DUMPW ( addr cnt -- ) 	2 bdw C! DUMP ;
#64 == dwidth
pub DUMPA
 	ADO CR I .LONG ." : " I dwidth ADO I dmm W@ CALL DUP BL $7E WITHIN IF EMIT ELSE DROP ." ." THEN LOOP
 	dwidth +LOOP
 	;

--- QUICK DUMP 32 bytes
pub QD ( addr -- )		BL DUMP ;

IFDEF EXPLORER
pub .RETSTK
	STACKS 4 + #22 CR ." RETURN STACK" COGDUMP
	;
   }


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

#19 MODULE: ANSI_TERMINAL
( ANSI )
{ SECTION: Minimal ANSI terminal controls
Minicom, Teraterm, and even Hyperterminal support ANSI control sequences.These are just the basics.
}

0	== black
1	== red
2	== green
3	== yellow
4	== blue
5	== magenta
6	== cyan
7	== white

pub ESC ( ch -- )		$1B EMIT EMIT ;
pri ESCB ( ch -- )		"[" ESC EMIT ;

pub PEN ( col -- )		"3"
pri COL ( col fg/bg -- )	ESCB "0" + EMIT "m" EMIT ;
pub PAPER ( col -- )	"4" COL ;

{ optional - normally not supported
pri ESCH ( ch -- )		"#" ESC EMIT ;
pub DHT			"3" ESCH ;
pub DHB			"4" ESCH ;
pub NARROW			"5" ESCH ;
pub WIDE			"6" ESCH ;
}

pri .PAR			SWAP #10 .NUM EMIT ;
pri CUR ( cmd n -- )		"[" ESC SWAP .PAR ;
pub XY ( x y -- )		";" SWAP CUR "H" .PAR ;

pub HOME			"H" ESCB ;

pub CLS				$0C EMIT HOME
--- Erase the screen from the current location
pub ERSCN			"2" ESCB "J" EMIT ;
--- Erase the current line
pub ERLINE			"2" ESCB "K" EMIT ;


pub CURSOR ( on/off -- )	"?" ESCB ." 25" IF "h" ELSE "l" THEN EMIT ;

pub PLAIN			"0"
pri ATR ( ch -- )		ESCB "m" EMIT ;
pub REVERSE			$37 ATR ;
pub BOLD			$31 ATR ;

pub MARGINS ( top bottom -- )	$5B ESC SWAP ";" .PAR "r" .PAR ;


{
VT100     1B 5B 3F 31  3B 32 63
MINICOM   1B 5B 3F 31  3B 32 63
VT102     1B 5B 3F 36  63
Esc[?1;Value0c


}
IFDEF EXPLORER
8 BYTES ansi
pub ANSI? ( -- code )
 	"c" ESCB ansi 8 ERASE
	ansi 8 ADO #1000 WAITKEY I C! LOOP
 	ansi @ $313F5B1B = IF ansi 5 + C@  ELSE FALSE THEN
 	;
    }

}  \  end of    #19 MODULE: ANSI_TERMINAL


\ Define COGREG constants for most SPI operations
4 CONSTANT @CNT
0 CONSTANT @SCK
1 CONSTANT @MOSI
2 CONSTANT @MISO
3 CONSTANT @CE
-6 CONSTANT @SCL		\ Clock mask for I2C


--- create a MASK of LSByte where bit n is set if 0 <= n < 32, else return 0
pri MASK? ( n -- mask )		>B DUP BL < IF MASK ELSE DROP 0 THEN ;

[PRIVATE
\ Define COGREG constants for most SPI operations based on kernel code, usually not for RUNMODs
\ COGREGS for RUNMODS are 0 up
\ -6 CONSTANT @CLOCKPINS
-5 CONSTANT @SPISCK
\ -4 CONSTANT @SPIOUT
\ -3 CONSTANT @SPIINP
\ -2 CONSTANT @SPICE
\ -1 CONSTANT @SPICNT
PRIVATE]

{ Kernel I/O mask registers used by Kernel SPI words

clockpins		long 0			' I/O mask for CLOCK instruction
spisck		long 0			' I/O mask for SPI clock
spiout		long 0			' I/O mask for SPI data out (MOSI)
spiinp		long 0			' I/O mask for SPI data in (MISO)

spice		long 0			' I/O mask for SPI CE (not really required unless we use CE instr)
spicnt		long 0			' bit count for variable size Kernel SPI

' Registers used by PASM modules to hold parameters such as I/O masks and bit counts etc
REG0		long 0
REG1		long 0
REG2		long 0
REG3		long 0
REG4		long 0
}

--- Set the SPI pins using a long as 4 octets = &ce.miso.mosi.clk  as this allows passing a single long
pub SPIPINS ( ce.miso.mosi.clk --- )
 	@SPISCK
pub SETPINS ( mask dst -- )  ( ~190us)
 	8 OVER 4 + COGREG!				--- set default count
 	4 ADO
 	  DUP MASK? IX I - 2 > IF DUP OUTCLR THEN 	--- make sck and mosi outputs
 	  I COGREG! 8>>
 	LOOP
        @SPISCK 3 + COGREG@ OUTSET			--- 160506 make CE a high output
 	DROP
 	;
pub MODPINS  	@SCK SETPINS ;



IFDEF (OPCODE)
--- V2.4 allows opcodes to be created and run just like constants
--- Usage: 	$24FF6210 OPCODE ROL16
---		12345678 ROL16 . 56781234
NFA' (OPCODE) NFA>CFA C@ == (op)			--- avoide compiled NFA's as dictionary changes will affect them

pub OPCODE IMMEDIATE
 	[COMPILE] GRAB					---  grab number out of compiled code (execute)
 	codes W@ 4 + 3 ANDN 1- codes W!
 	[COMPILE] CREATE
 	-1 codes W+!
 	(op) codes W@ C!
 	codes W@ 1+ !
 	5 ALLOT
	 ;
}

IFDEF OPCODE
STACKS == tos						--- cog address of top of stack
$38BC_0000 tos 9 << + tos 1+ +  OPCODE SAR ( n bits -- res bits )


' AND COG@ $1FF AND 9 << $38FC.0010 OPCODE SARX			--- find address of tos and form opcode with default #16
pub SAR  ( n bits -- result \ arithmetic shift right )
 	' SARX 1+ C! SARX
	;
}

IFNDEF SAR
pub SAR ( n bits -- result \ arithmetic shift right )
 	$38FF6800 + PASM DROP
 	;
}

}
IFDEF EXPLORER

( SYSTEM CLOCK MODES )
( Forum link )

---	    0    C    7    C   0    0   0   0
	%000011_0001_1111_000000000_000000000 STACKS 9 SHL + OPCODE (CLKSET)

pub CLK ( multiple0..4 -- )
 	3 + 4 C@ 7 ANDN OR
 pub CLKSET ( n -- )
 	DUP 4 C!
	(CLKSET) 2DROP
	;
pub RCFAST	0 CLKSET ;
pub RCSLOW	1 CLKSET ;
}


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

( COG TASK CONTROL )


{
Run a task in the specified cog (assumes Tachyon is preloaded and has not been assigned yet (IDLE)
Usage: 	' <mytask> >PFA 4 RUN
NOTE: V2 changes ' to return with the actual PFA (most sensible), so it's: ' <mytask> 4 RUN
V2.0 120915+ now uses 8 bytes per task rather than 2. The run address is not cleared. Use ATN for commands.

8 bytes/task RUN[2] FLAG[1]

TASK REG
0 RUN
2 FLAG
3
4 ATN
6 ENQ


}

--- Find the next available cog that's free to run a task - ready and in IDLE
pub TASK? ( -- task )
	8 BEGIN 1- DUP TASK @ $1.0000 = OVER 0< OR UNTIL
	;


pub RUN ( pfa cog -- | USAGE: ' MYTASK TASK? RUN )
 	DUP 0 7 WITHIN IF TASK W! ELSE CR PRINT" Error - cog out of range " THEN
 	;
\ Set starting address of a task's registers
pub TASKREGS ( addr -- )		7 COGREG! ;


IFDEF EXPLORER


pub .TASKS ( -- \ List tasks )
	8 0 DO
	  I TASK 2+ C@ DUP
 	    IF   .INDEX I TASK W@ ?DUP
 	      IF >NAME DUP PRINT$ BL SWAP LEN$ - SPACES
 	      ELSE PRINT" IDLE" #28 SPACES
 	      THEN
	    THEN
	  I COGID = DUP
	    IF   .INDEX PRINT" CONSOLE" #25 SPACES THEN
	  OR IF I TASK DUP W@ .WORD SPACE 2+ 6 ADO I C@ .BYTE SPACE LOOP THEN
	  LOOP
	;

ALIAS .TASKS lscogs

( INTERTASK COMMUNICATIONS )
#24 MODULE: INTERTASK_COMMUNICATIONS

}
( To listen for a command )
--- ATN? ( -- cmd )
--- read in a command from the tasks variable and return with it and also clear the tasks variable
\ read in a 16 bit command from the tasks variable and return with it and also clear the tasks variable )
pub ATN@ ( -- cmdWord )
 	COGID TASK 4 + DUP W@
 	SWAP W~		\ Clear the command (ack)
 	;
( To send a response )
pub ENQ! ( dataWord -- \ send a 16 bit response to the command )
	COGID TASK 6 + W!
	;

( To talk to tasks in other cogs )
pub ATN! ( cmdWord cog -- \ Send a 16 bit command to another task )
	TASK 4 + W!
	;
}
( To listen to tasks in other cogs )
pub ENQ@ ( cog -- dataWord \ fetch the 16 bit response to the command and acknowledge )
	TASK 6 + DUP W@
 	SWAP W~		\ clear data (ack)
	;


}    \  end of      #24 MODULE: INTERTASK_COMMUNICATIONS

   }

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

#20 MODULE: STRINGS

( Create a string variable/constant and allocate max bytes for it to allow appending )
--- Create a string constant and specify size of string allocation else use 0 = default
pub STRING ( str maxsize --  )
	[COMPILE] GRAB								\ "uncompile" str and max and push onto stack
	?DUP 0= IF DUP LEN$ 1+ THEN SWAP					\ Use LEN$ if maxsize = 0
	codes W@ 4 ALIGN codes W! ALLOCATED ( size str )    		\ Set new code pointer to long boundary
 	HERE 5 + OVER LEN$ 1+ <CMOVE					\ Move compiled string out of the way
 	$80 HERE C! DUP HERE 1+ C! HERE 4 + LEN$ HERE 2+ C!		\ Insert header info
	3 ALLOT [COMPILE] CREATE						\ Insert bytecode (also adds a redundant EXIT)
	HERE 1+ DUP LEN$ 1+ OVER 1- SWAP CMOVE				\ Shift the string back into the correct position
	HERE 3 - C@ ALLOT								\ Read max and allot that for the string data
 	DROP										\ string len left on stack ???
	;
IMMEDIATE

\ Create a NULL$ constant

BYTE NULL$    NULL$ C~

{ Copy one string to another (store)
Usage:
" NOW IS THE TIME" $20 STRING A$
NULL$ $20 STRING B$
A$ B$ COPY$
}
pub COPY$ ( str1 str2 -- \ copy str1 to str2 )
	OVER LEN$ 1+ CMOVE
 	;

ALIAS COPY$ $!			\ Just an alias plus I like to think of this as "string store" analogous to ! operation

{ Append a string
Usage: " MY NAME IS " $20 STRING NAME
" PETER" NAME APPEND$
NAME PRINT$ MY NAME IS PETER ok
}
pub APPEND$ ( str1 str2 -- \ append str1 at the end of str2 )
	DUP LEN$ + COPY$
	;
{ Append a character to a string and null terminate
Usage:
"*" NAME +CHAR  ok
NAME PRINT$ MY NAME IS PETER* ok
}
pub +CHAR ( ch str2 -- \ add a character to a string )
	DUP LEN$ + OVER 1+ C~ C!
	;
pub MID$ ( str offset len -- str \ extract the substring of str starting at offset len chars long )
	>L + L>

pub LEFT$ ( str len -- str \ Destructive LEFT$ - uses same string )
	OVER + C~
	;
pub RIGHT$ ( str len -- str \ give a copy of the rightmost len chars of str )
	OVER LEN$ SWAP - +
	;
pub ERASE$ ( str -- \ Fully erase the string - reads max len from header )
	DUP 3 - C@ ERASE
	;
pub LOCATE$ ( ch str -- str \Locate the first ch in the string and return else null )
	0 SWAP DUP LEN$ ADO OVER I C@ = IF DROP I LEAVE THEN LOOP
	NIP
	;

pub $=
pub COMPARE$ ( str1 str2 -- flg \ Compare two strings for equality )
	OVER LEN$ OVER LEN$ =
	IF
	DUP LEN$
	ADO C@++ I C@ <> IF DROP 0 LEAVE THEN LOOP
	0<>
	ELSE 2DROP FALSE
	THEN
	;

pub UPPER ( char -- uppercaseChar  \ convert char to uppercase )
	DUP "a" "z" WITHIN IF BL - THEN
 	;

pri >UPPER  ( str1 --  ) --- Convert lower-case letters to upper-case
	DUP LEN$ ADO I C@ UPPER I C! LOOP
	;

pub >CSTR 				@word $! @word LEN$ @word 1- C! @word 1- ;

pub FIND ( str -- cfa )			>CSTR @NAMES FINDSTR DUP IF NFA>CFA >PFA THEN ;
pub CALL$				FIND ?DUP IF CALL THEN ;

CR ( #################################################################### )

}   \   end of   #20 MODULE: STRINGS


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

#21 MODULE: SAN_FILTER

IFDEF EXPLORER

pub NORMALIZE ( data   bits low high -- result )
	4 REG ! 0 REG !                             --- store low and high to register variables
	0 SWAP                                      --- Init temp
	FOR  ( data temp )                          --- Execute loop for number of bits of resolution
	  2*                                        --- temp<<1
	  0 REG @ 4 REG @ + 2/ ( data temp mid )    --- calc new mid
	  DUP 4TH >                                 --- Compare mid > data
 	    IF 4 REG ! ELSE 0 REG ! 1+ THEN         --- Set new low or high and track
	NEXT
	NIP                                         --- discard original data
	;


}
}    \  end  of   #21 MODULE: SAN_FILTER


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

IFDEF EXPLORER
#22 MODULE: MCP3208_8_channel_ADC
( MCP3208 8 channel ADC )

{ 8 channel 12-bit ADC interface for MCP32O8
Code size = 87 bytes including init and pin reassignment words
SPI speed set for 2MHz
}


{ pub MODPINS ( ce.miso.mosi.clk --- )
example pins
#12    	|< CONSTANT =mcp            	\ Select mcp3208 chip
#09    	|< CONSTANT =sck            	\ SCK mask
#11    	|< CONSTANT =mosi            	\ MOSI
#10    	|< CONSTANT =miso            	\ MISO data
&cs.mi.mo.ck
&12.10.11.09 MODPINS

}

\ Init the ADC using the pins specified
pub !ADC ( &cs.mi.mo.ck -- )    	\ long encoded pin descriptor
	DUP MODPINS            	\ set pin masks
	24 SHR HIGH   		 --- make cs a high output
 	[MCP32]   		 --- load the module
	;

ALIAS RUNMOD ADC@ ( ch -- data )


pub ADCBUF ( buffer -- )	\ Read all 8 ADC channels into specified word buffer
	8 0 DO I ADC@ OVER I 2* + W! LOOP DROP
	;

\ Convert the ADC ouptut to a scaled voltage reading - 2.5V = 2500
pub VOLTS@ ( ch -- volts.00 )	\ Read back the pin as a voltage scaled to 2 decimals
	ADC@ #3300 * #12 SHR
	;

IFDEF EXPLORER
\ Setting pins: &04.02.03.01 !ADC
\ List all 8 channels like a bar graph
pub lsadc

 	8 0
 	  DO CR I .BYTE ." : " I ADC@ DUP .DEC SPACE 5 SHR 1+ FOR "*" EMIT NEXT LOOP
 	;

\ Read the voltage from a pin scaled to 2 decimals - assumes vref = 3.3V
}
      }
}   \   end of    #22 MODULE: MCP3208_8_channel_ADC




--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

pub seconds ( n1 -- )
 	1000d * ms
 	;

ALIAS seconds second

( DICTIONARY LIST )

pri LISTKEY ( flg -- flg+ )
KEY@ DUP
IF
  DUP BL = IF DROP WKEY $1B = OR EXIT THEN
  DUP $1B = IF 2DROP TRUE THEN
THEN
DROP
;

IFDEF EXPLORER
\ Control filters for WORDS listing
16 BYTES matchstr


\ Usage: MATCH SD WORDS  to list all words beginning with SD
pub MATCH
	matchstr 16 ERASE matchstr 1+
	BEGIN WKEY DUP EMIT DUP BL <> WHILE OVER C! 1+ 1 matchstr C+! REPEAT
	2DROP
	;
IMMEDIATE


BYTE _any PRIVATE
_any C~
\ List any words which have ANY such character in them
pub ANY		WKEY DUP EMIT _any C! ;
IMMEDIATE

pri MATCH? ( name -- name flg )
	DUP matchstr C@++		( name matchstr+ matchchar )
        ADO C@++ I C@ <>
          IF DROP FALSE LEAVE THEN
        LOOP  				\ exits with either the current address (as an implied TRUE) or an explicit FALSE
	_any C@
 	IF OVER 1- C@++
 	  ADO I C@ _any C@ = IF TRUE OR THEN LOOP
 	ELSE matchstr C@ 0= OR
 	THEN
;

{
Dictionary entries: - cnt,string,atrs,bytecodes
@NAMES 10 DUMP
63A1: 04 43 4F 4C 44 82 B9 BB 04 42 4F 4F 54 82 BA BB    .COLD....BOOT...
      cnt<string   >atr codes
}
\ List only the most current words up to the first module name encountered
pub MY
	" .fth" 0 REG 4 CMOVE			\ signal listing to stop once a ".fth" module name is encountered
	;


{
hd	= |<7		'indicates this is a an attribute (delimits the start of a null terminated name)
sm	= |<6		'smudge bit - set to deactivate word during definition
im	= |<5		'lexicon immediate bit

pr	= |<3		'private (can be removed from the dictionary)

' code attributes	00 = single bytecode, 02 = XCALL bytecode (2 bytes), 03 = WCALL bytecode (3 bytes)
sq	= |<2		'indicates the bytecode is a sequence of two instructions (as opposed to an XCALL+)
xc	= |<1		'XCALL bytecode
ac	= xc+|<0	'WCALL - 2 byte address - interpret header CFA as an absolute address
}

\ 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F


WORD _atr		\ attribute mask byte to list and atrribute match byte
_atr C~~		\ list all by default
_atr 1+ C~
pub LIKE
 	_atr C~~ [COMPILE] NFA' [COMPILE] GRAB
 	DUP IF C@++ + C@ _atr C~ THEN _atr 1+ C!
;
IMMEDIATE
}


pri .ATRS ( atr -- )
 	8 0 DO DUP 7 I - MASK AND IF " hsi-p2xc" I + C@ ELSE "." THEN EMIT LOOP
	DROP
{
	2 SPACES >N 2* 2*
 	\ 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
 	" codercalpub wcal4   5   codx7   pri$pricpri priwpri4pri5prx$pri7" + 4 CTYPE
}
	SPACE
	;

BYTE lpace PRIVATE

NFA' EMIT NFA>CFA C@ == =X
NFA' flags NFA>CFA C@ == =R

pri .BC2 	SPACE DUP 2+ C@ .BYTE DROP ;
pri .NAME: ( @atr -- )
 	DUP 1+ C@ SWITCH
 	=X     CASE PRINT" XCALL " .BC2 BREAK
 	=X 1 - CASE PRINT" YCALL " .BC2 BREAK
 	=X 2 - CASE PRINT" ZCALL " .BC2 BREAK
 	=X 3 - CASE PRINT" VCALL " .BC2 BREAK
	=R     CASE PRINT" REG   " .BC2 BREAK
 	DUP C@ $28 ANDN
 	$83 =    IF PRINT" CALL16" DROP 3 SPACES BREAK
 		      PRINT" CODE  " .BC2
	;

pri .NAME ( nfa+1 -- nfa2+1 )
	5 REG C@ 0=
  	IF --- if format = 0 then list all
 	    CR 8 REG DUP W++ W@ .DEC ." :  "				--- line count
 	    DUP .WORD SPACE DUP NFA>CFA	( nfa cfa )			--- print NFA (header)
 	    DUP >PFA .WORD SPACE					--- print PFA (code)
	    DUP 1- .NAME:

	    SPACE
	    DUP 1- C@ .ATRS						--- List the attribute flags ( cnt,string,atrs,bytecode1,bytecode2)
 	    SWAP PRINT$ ( cfa )						--- Print the name of the word
	ELSE								--- only print the name
 	  DUP NFA>CFA
 	  ( cfa )							--- Print the name of the word
 	  SWAP DUP PRINT$
 	  5 REG C@ "W" = IF #20 ELSE 1 THEN				--- spacing between words, wide or single space
 	  DUP 4 REG C+!
	  SWAP LEN$ DUP 4 REG C+! - 1 MAX SPACES
 	  4 REG C@ #79 > IF CR 4 REG C~ THEN
 	THEN
 	lpace C@ ms
	;

pri .WORDS
 	CR PRINT"        NFA  CODE EXT      ATRS  def  NAME "
 	CR "-" #40 EMITS
	0
pri (WORDS) ( format -- )
 	lpace C~ 8 REG W~						--- init pace delay and word count
 	delim 1+ C@ 9 = IF #20 lpace C! THEN				--- WORDS <TAB> mode can use spacebar to pause/cont
  	4 REG C~ 5 REG C! 						--- REG4 = xpos, REG5 = format
	@NAMES 1+
	CR
--- list the words in the selected formated until end or escape
pri (.WORDS)
	BEGIN
IFDEF EXPLORER
        MATCH? OVER DUP LEN$ + C@ DUP _atr C@ AND SWAP _atr 1+ C@ = OR AND
    }
	  IFNDEF EXPLORER TRUE }						--- The SMALL build does not have any fancy match features
	    IF .NAME ELSE NFA>CFA THEN
	  3 +				( nfa )				--- point to next name string which is 3 bytes after previous bytecodes
	  DUP C@ 0= 							--- end of this word list?
 	  DUP IF SWAP 1+ DUP C@ 0= ROT AND THEN				--- double null is end of dictionary
 	  OVER 1- DUP C@ 3 - + U@ 4 REG C@ = OR				--- test? (forget)
 	  6 REG W@ 1 = OR 6 REG W--					--- simple counter to limit list
	  LISTKEY
	UNTIL
	DROP
	0 REG ~
IFDEF EXPLORER
	matchstr 16 ERASE _any C~
}
	;



--- quick and recent words list
pub QW  		$80 6 REG W!
--- quick words list
pub QWORDS		"Q" (WORDS) ;
--- wide words
pub WWORDS		"W" (WORDS) ;

--- for interactive use directly followed by CR/TAB - if BLANC follows an array of WORD is created
pub WORDS IMMEDIATE
 	delim 1+ C@ BL = IF [COMPILE] WORDS: EXIT THEN			--- if something is following this then use the "N WORDS array"
 	.WORDS								--- detailed format, print headers
	;





IFDEF EXPLORER
\ List any help information available for the word, else just the normal WORDS info
pub HELP ( <name> -- ) IMMEDIATE
 	4 REG ~
 	[COMPILE] NFA' ?DUP IF [COMPILE] GRAB 1+ .NAME DROP ELSE NOTFOUND  THEN
;


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---


\ Revector the old word to the new word so that all compiled references will point to the new word.
\ very useful for debugging or for redefining a compiled word.
pub REVECTOR ( <old> <new> -- ) IMMEDIATE
  	[COMPILE] NFA' [COMPILE] GRAB NFA>CFA >VEC
 	[COMPILE] ' [COMPILE] GRAB SWAP W!
	;

   }

pri (STRIP) ( nameptr -- nameptr+ )
     	    CR ." Removing " DUP 1+ PRINT$			\ Ok, strip it out
 	    DUP DUP C@ 4 + ( nameptr cnt )
          DUP >L @NAMES +
	    @NAMES ROT SWAP - ( newnames len )
   	    @NAMES ROT ROT <CMOVE
   	    L> DUP names W+! +   	 			\ add to names pointer and to current pointer for next word
 	;

\ Strip a single header from the dictionary
pub STRIP IMMEDIATE	[COMPILE] NFA' [COMPILE] GRAB (STRIP) DROP ;
{
limit names
@names old@names - = size
old@names size
}
pri (RECLAIM) ( limit -- ) --- Strip private headers from dictionary up to limit address
	@NAMES DUP >L
	BEGIN
  	  DUP C@++ + ( nameptr atrptr )
  	  C@ 8 AND							--- Test to see if this is private
  	    IF (STRIP) ELSE C@++ + 3 + THEN				--- strip header or proceed to next
	  2DUP U<
 	  OVER C@ 0= OR
	UNTIL
	2DROP CR ." Reclaimed " @NAMES IX - DUP 0 PRINTDEC ."  bytes "	--- Report results
	L> SWAP ?DUP IF ERASE ELSE DROP THEN				--- Clear the reclaimed area (not needed)
	;

pub FORGET ( <name> -- ) IMMEDIATE
 	[NFA']									\ find the NFA of the word
pub (FORGET) ( nfa -- )
	?DUP
 	IF
	  DUP NFA>CFA >PFA SWAP
        BEGIN
    	    @NAMES NFA>CFA >PFA codes W!   					\ release code space
    	    @HATR $83 <> IF @HATR 1+ >VEC W~ THEN				\ release vector
    	    @HATR 3 + names W!   		 				\ release name space
    	    DUP @NAMES <
        UNTIL
        DROP
	XCALLS BEGIN DUP @ 1+ WHILE DUP W@ 3RD => IF 0 OVER W! THEN 2+ REPEAT	\ clear all vectors from here on inc. "private"
	2DROP
        codes W@ here W!							\ update
      ELSE
        SPACE @word PRINT$ PRINT"  not found "				\ non-fatal warning
      THEN
 	;

--- keep this word from being reclaimed by making it public
pub KEEP ( <name> -- )	IMMEDIATE
 	[NFA'] ?DUP IF 8 SWAP C@++ + CLR THEN
 	;

{ Create a defintion that becomes a module header
pub MODULE ( <name> -- ) IMMEDIATE
 	[NFA'] DUP (FORGET)							\ Forget any previous versions
	(CREATE) (:)
 	;
}

( LIST MODULES )
{HELP .MODULES
Modules are marked by the use of a word at the start of the module which is suffixed as ".fth"
The default word action should be to print a description of the module and it's version and date
The MODULES word lists out all these .fth words and also executes each one
}
pri (.MODS) 	--- common sub used by .SDMOD in SDWORDS.fth
	BEGIN
 	  DUP C@
 	WHILE
 	  DUP C@ 4 > 								--- name must be longer than 4 chars
	  IF DUP C@ 3 - OVER + U@ " .fth" U@ = 				--- is the end of the name = ".fth" ?
 	    IF
 	      DUP NFA>CFA >PFA DUP >L CR .WORD PRINT" : "		--- print its CFA code address (old PFA)
 	      DUP 1+ DUP PRINT$ LEN$ #20 SWAP - SPACES			--- display the module name and try to line up the description
 	      L> CALL								--- execute the .fth word to display it's message
	    THEN
	  THEN
 	  C@++ + 3 +
	REPEAT
	DROP
;
pub .MODULES
 	CR PRINT" MODULES LOADED: "
	@NAMES (.MODS)
 	CR
	;
}

IFNDEF .MODULES
: .MODULES ;
}


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

#13 MODULE:  PBASIC_STYLE_SERIAL_I/O


( PBASIC STYLE SERIAL I/O )
\ baudcnt is a task register so each cog can have it's own baudrate (if used)
pub SERBAUD ( baud -- \ Set the baudrate for SEROUT and SERIN for each COG individually )
 	CLKFREQ SWAP / DUP baudcnt W!
 	2/ 200 - baudcnt 2+ W!					--- [4.8us] serup half-bit delay with high speed compensation
 	;
#9600 SERBAUD


{HELP SEROUT
Bit-bashed Serial output - transmit asynchronous data
Fixed start bit timing
Code size: 42 bytes
Tested to 820,000 baud
}
pub SEROUT ( dataByte pin -- \ send data byte to pin at rate set with SERBAUD )
	MASK DUP OUTSET  				\ ensure pin is an output (very first time perhaps)
	SWAP 2*					\ Include start bit (0)
	baudcnt W@ DELTA				\ setup delay and wait
	WAITCNT SHROUT
	WAITCNT SHROUT
	WAITCNT SHROUT
	WAITCNT SHROUT
	WAITCNT SHROUT
	WAITCNT SHROUT
	WAITCNT SHROUT
	WAITCNT SHROUT
	WAITCNT SHROUT
	WAITCNT DROP OUTSET			\ final stop bit
	;

{HELP SERIN ( pin -- data )
Receive 8-bit serial data from pin. Will block until data received.
This version is optimized to return with the data from the middle of the last data bit but
it will check to ensure that it does not start until the line is idle
}
pub SERIN ( pin -- data \ receive 8 bit serial data from pin at rate set with SERBAUD, blocks )
	MASK DUP 3 COGREG!					--- [5.8us]
 	baudcnt 2+ W@					--- [4.8us] serup half-bit delay with high speed compensation
	(WAITPEQ)						--- [0.4us+] make sure we are not detecting the last data bit - wait for stop
	(WAITPNE) DELTA 					--- wait for start bit then wait haf bit time
	 0							--- [5.4us] setup pin mask and inital data to SHRINP 8 data
	baudcnt W@ DELTA 					--- delay to sample 1 bit later in 1st data bit
	SHRINP WAITCNT
	SHRINP WAITCNT
	SHRINP WAITCNT
	SHRINP WAITCNT
	SHRINP WAITCNT
	SHRINP WAITCNT
	SHRINP WAITCNT
	SHRINP							--- last data bit
	NIP #24 SHR						--- right justify 8-bit data
;
{
BYTE serpin
pri (SEROUT)	serpin C@ SEROUT ;
pub SERIAL	serpin C! ' (SEROUT) uemit W! ;
}

}  \ end of  #13 module:  PBASIC_STYLE_SERIAL_I/O


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---


#14 MODULE:   EXAMINE_SPECIAL_PURPOSE_REGISTERS
IFDEF EXPLORER
( EXAMINE SPECIAL PURPOSE REGISTERS )


pub lsregs
 	PRINT"  COG #" COGID $0A .NUM PRINT"  registers"
pub .SPRS ( -- \ Dump the cog's SPRs with labels in both HEX and BINARY )
        16 0 DO CR I $1F0 + "$" EMIT .WORD PRINT" : "
        I 4* " PAR CNT INA INB OUTAOUTBDIRADIRBCTRACTRBFRQAFRQBPHSAPHSBVCFGVSCL" + 4 CTYPE
        PRINT"  = $" I $1F0 + COG@ DUP $4810 .NUM     DROP \ PRINT"    %" $5F02 .NUM
        LOOP
;
pri .PIN
 	MASK AND 0<> 1 AND IF "H" ELSE "L" THEN EMIT
;

pub PINLOAD? ( pin# -- flg \ check if a pin is pulled down, up or highZ = floating )
	OUTA COG@ >R DIRA COG@ >R
	DUP HIGH DUP MASK INPUTS #100 us DUP PIN@		\ returned to low if pulled down
	0= "D" AND
	OVER LOW OVER MASK INPUTS #100 us SWAP PIN@		\ returned to high if pulled up
	"U" AND OR
 	R> DIRA COG! R> OUTA COG!
	DUP 0= IF DROP "X" THEN
;


pub .PINLOAD
 	SPACE
 	PINLOAD? SWITCH
 	"D" CASE PRINT" down " BREAK
 	"U" CASE PRINT" up   " BREAK
		 PRINT" float"
;


TABLE signature 16 ALLOT
signature 		== iosig
signature 8 +	== i2csig


{HELP SignIO
Each pin can have a 2-bit signature indicating up/down/float
I/O direction is irrelevant for this test as it assumes all pins will be inputs until it is known what they are
To simplify the encoding firstly one long will hold the up/down states for each I/O and
another long will indicate float or
}
pub SignIO
 	iosig 8 ERASE
 	0 #30 ADO I PINLOAD? DUP "U" = IF I MASK iosig +! THEN "D" = IF I MASK iosig 4 + +! THEN LOOP
;


{HELP lsio
List I/O pin states as input/output and whether the pin is connected to a pullup/pulldown or floating.
Even if it's an output it will test the loading so that if it is connected to an LED that is pulled up then
this would report as an output with pullup.
}
pub lsio
	PRINT"  PORT PINS"
	OUTA COG@ DIRA COG@ ( out dir )						--- save I/O states
	CR "+" EMIT "-" BL EMITS "+" EMIT
	P@ DIRA COG@ 	( port dir )
	16 0
	DO
	  CR PRINT" P" I $20A .NUM 						--- display Port number
 	  DUP I MASK AND 								--- test for input/output
	    IF PRINT"  out" ELSE PRINT"  inp" THEN 				--- display inp or out
	  SPACE OVER I .PIN 							--- display pin state H or L
 	  I .PINLOAD									--- display load as up/down/float
 	  PRINT"  ||"								--- over to right hand section
--- RIGHT SIDE
	  #31 I - DUP #30 < IF .PINLOAD SPACE ELSE DROP 7 SPACES THEN
 	  OVER #31 I - .PIN
	  DUP #31 I - MASK AND
	    IF PRINT"  out P" ELSE PRINT"  inp P" THEN
	#31 I - $20A .NUM
	LOOP
	CR "+" EMIT "-" BL EMITS "+" EMIT
	2DROP
 	$4000.0000 OUTA COG!								--- ensure all pins are inputs to build I/O sig
 \	SignIO
 	DIRA COG! OUTA COG!								--- restore I/O states
	;


    }
}   \ end of  #14 MODULE:   EXAMINE_SPECIAL_PURPOSE_REGISTERS


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

NFA' *end* STREND 3 + == (end)

#15 MODULE:   Memory Map Reporting
IFDEF EXPLORER
pri (MAP)
	DUP 0= IF DROP PRINT" .." EXIT THEN
	DUP $FF = IF DROP PRINT" ##" EXIT THEN
	.BYTE
	;
LONG blksz PRIVATE
\ Map memory in 256 byte chunks by OR'ing bytes and printing byte result/256 bytes
pub .BLOCK ( src cnt blksz -- )
	PLAIN
	DUP ."  x" $0A .NUM
	blksz !
	SWAP OVER ADO
	  CR I .WORD PRINT" : "
	  I OVER blksz @ 4 SHL MIN ADO
	    0 I blksz @ ADO I C@ + LOOP 8>> (MAP) SPACE
	  blksz @ +LOOP
	blksz @ 4 SHL +LOOP DROP
	;

pub .MAP
	CR BOLD PRINT" REGISTERS" 0 REG $100 16 .BLOCK
	CR BOLD PRINT" VECTORS" XCALLS BEGIN DUP @ 1+ WHILE 4 + REPEAT XCALLS - XCALLS $800 #64 .BLOCK
	CR BOLD PRINT" KERNEL CODE" ' EMIT ' EXTEND.fth OVER - $100 .BLOCK
	CR BOLD PRINT" CODE" ' EXTEND.fth HERE OVER - $100 .BLOCK
	CR BOLD PRINT" SPARE @" PLAIN @NAMES HERE DUP .WORD - PRINT" : for " 0 8<< $C00A OR PRINTNUM
	CR BOLD PRINT" DICTIONARY" @NAMES (end) OVER - $100 .BLOCK
	CR BOLD PRINT" SPARE @" PLAIN BUFFERS (end) DUP .WORD PRINT" : for " - 0 8<< $C00A OR PRINTNUM
	CR BOLD PRINT" BUFFERS" BUFFERS $800 #64 .BLOCK
	CR BOLD PRINT" RX BUFFER" BUFFERS $800 + $200 #64 .BLOCK
	CR BOLD PRINT" HUB STACK" 16 COGREG@ $8000 OVER - 16 .BLOCK
	CR 	;
    }
    }

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

( I2C BUS )
{ SECTION: I2C BUS INTERFACE
I2C bus routines are bit-bashed and run at a bus speed of 400kHz.
This is a standard single master with no clock stretching used
It is recommended that the EEPROM I2C bus lines be used as I2C is meant to be a shared bus.
142 CODE BYTES, 94 NAME BYTES
}


\ I/O "Constants" - variable to allow for redirection and direct use (rather than @ )
#P28 |< 	== SCL
#P29 |< 	== SDA


BYTE i2cflg

pub EEPROM ( -- \ Assign the default Prop's EEPROM pins )
	#P29 #P28

\ Specify which pins to use for the I2C bus (default is the P29 and P28
pub I2CPINS ( sda scl -- \ Assign the pins to use for the I2C bus )
	|< ' SCL 1+ !
	|< ' SDA 1+ !
	;


SCL SDA +	== I2C
{ I2C START CONDITION also makes I2C pins outputs
 SCL --------------_______
 SDA ---__________________
}
pub ?I2CSTART
 	BEGIN i2cflg C@ 0= UNTIL
pub I2CSTART
\	SDA INPUTS SCL OUTSET					--- 7.2us
	I2C OUTSET
 	SCL @SCL COGREG!					--- 9.4us setup clock
	SDA OUTCLR 1 i2cflg C! SCL OUTCLR			--- 12.6us
	;

{ I2C STOP CONDITION also releases I2C lines
 SCL XX-------==
 SDA XX___----==
}
pub I2CSTOP
	SDA OUTCLR SCL OUTSET BL DROP SDA OUTSET			--- Patch 140319 - leave SDA as a high output (in case it's shared)
 	1 us I2C INPUTS						--- free up I2C lines
 	0 i2cflg C!						--- i2c bus free
	;

--- Write a byte to the I2C bus and return with the ack flag
--- This routine runs at an I2C speed of 400kHz
--- 38.4us
pub I2C!? ( data -- flg )					--- write a byte to the I2C bus and return with the ack  0=ack	)
	#24 REV							--- put into lsb first format for SHROUT
	SDA DUP OUTSET SWAP					--- data masks
	8 FOR
	  SHROUT						--- Shift out next data bit
	  CLOCK NOP CLOCK

	  NEXT							--- loop
	DROP DUP INPUTS						--- Float SDA
	CLOCK IN 0<> CLOCK					--- ack clock
	;

\ Write to the I2C bus but ignore the ack
\ This version has a faster cycle time as it clocks but does not check for ack
\ 32.4us
{
pub I2C! ( data -- 						\ write a byte to the I2C bus but ignore the ack )
	#24 REV						\ put into lsb first format for SHROUT
	SDA DUP OUTSET SWAP					\ data masks
	8 FOR							\ start loop for 8 times
	  SHROUT						\ Shift out next data bit
	  CLOCK NOP CLOCK
	  NEXT							\ loop
	DROP INPUTS						\ Float SDA
	CLOCK NOP CLOCK					\ dummy ack clock
	;


	SHROUT CLOCK SHRINP CLOCK

	CLOCK LOW - CLOCK HIGH - CLOCK LOW
	 OUTPUT   -   INPUT
}
--- write a byte to the I2C bus but ignore the ack
pub I2C! ( data -- )
	#24 REV                    		\ put into lsb first format for SHROUT
	SDA DUP OUTSET SWAP               \ data masks
	SHROUT CLOCK CLOCK
  	SHROUT CLOCK CLOCK
  	SHROUT CLOCK CLOCK
  	SHROUT CLOCK CLOCK
  	SHROUT CLOCK CLOCK
  	SHROUT CLOCK CLOCK
  	SHROUT CLOCK CLOCK
  	SHROUT CLOCK CLOCK
	DROP INPUTS                    	\ Float SDA
	CLOCK CLOCK                		\ dummy ack clock
	;


pub ackI2C@
 	0
pub I2C@	( ack -- data \ Fetch a byte from the I2C bus - mirror ack signal 0 in = 0 out ) \ 36.6us
	SDA DUP INPUTS 0  ( ack iomask dat )
	  8 FOR CLOCK SHRINP CLOCK NEXT
	ROT 0= IF OVER OUTCLR THEN
 	CLOCK NOP CLOCK SWAP INPUTS
	BL REV						--- flip 8 msbs of long back into 8 lsbs
 	;

pub FI2C@
	SDA DUP INPUTS 0  ( iomask dat )
	  CLOCK SHRINP CLOCK				--- input data while clock is low
	  CLOCK SHRINP CLOCK
	  CLOCK SHRINP CLOCK
	  CLOCK SHRINP CLOCK
	  CLOCK SHRINP CLOCK
	  CLOCK SHRINP CLOCK
	  CLOCK SHRINP CLOCK
	  CLOCK SHRINP CLOCK
	  OVER OUTCLR
	CLOCK CLOCK SWAP INPUTS
	BL REV						--- flip 8 msbs of long back into 8 lsbs
	;


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

( EEPROM )
BYTE eeadr PRIVATE
--- EEPROM addressing - select default device and write 16-bit address
--- Updated to take an address >64K and automatically select the next device

pub @EE ( addr -- flg ) --- use full 32-bit address to select a device and issue the lower 16-bit address to it
    I2CSTOP
    L>W 2* $A0 + DUP eeadr C!                --- calculate the device address with base $A0 (8-bits)
    I2CSTART I2C!?                           --- send the device address
    OVER 8>> I2C!?                         --- send the 16-bit memory address (msb)
    OR SWAP I2C!? OR                         --- send the lsb and return with a combined ack flag.
    ;

--- Switch EEPROM to read mode
pub EERD ( -- flg  )
	I2CSTART eeadr C@ 1+ I2C!?
	;
--- revision 140602 - Added timeout loop counter to prevent hanging
pub @EEWAIT ( adr --  )
  	#200 BEGIN 1- OVER @EE 0= OVER 0= OR UNTIL 2DROP
	;
--- Store byte to EEPROM
pub EC! ( byte addr -- )
 	@EEWAIT I2C! I2CSTOP
 	;
--- Fetch byte from EEPROM
pub EC@ ( addr -- byte )
 	@EEWAIT EERD DROP
 	1 I2C@ I2CSTOP
 	;
pub EW! ( word addr -- ) \ Store a non-aligned word in EEPROM
 	@EEWAIT W>B SWAP I2C! I2C! I2CSTOP
  	;
--- Fetch a word from EEPROM
pub EW@ ( addr -- word )
 	@EEWAIT EERD DROP
 	ackI2C@ 1 I2C@ B>W I2CSTOP
	;

--- Fetch a long from EEPROM
pub E@ ( addr -- long )
 	@EEWAIT EERD DROP
 	ackI2C@ ackI2C@ B>W ackI2C@ 1 I2C@ B>W I2CSTOP
 	W>L
 	;
pub E! ( long addr -- ) \ Store a non-aligned long in EEPROM - 395us
 	@EEWAIT L>W SWAP W>B SWAP I2C! I2C!
 	W>B SWAP I2C! I2C! I2CSTOP
  	;

pri ENDRD ( --  \ read last byte [no ack] and stop )
 	1 I2C@ DROP I2CSTOP
 	;
pub ESAVEB ( ram eeprom cnt -- \ byte by byte method - safer for non-page aligned addresses and counts )
 	ADO C@++ I EC! 5 ms SPINNER LOOP DROP
 	;


\ pri 64K?			8 E@ $8008 E@ <> ;

0 $8000 E! $8000 E@ 0 E@ <> IF 128 ELSE 64 THEN		== ep
\ 64 == ep



--- Save a block of RAM to EEPROM. Will backup 32K to EEPROM in 4.963 seconds
pub ESAVE ( ram eeprom cnt -- )
	ep ALIGN                        				--- round up to nearest 64 byte page
	ROT SWAP                         				--- use ram address for loop index, leave eeprom addr on stack
   	ADO
   	( eeprom )
   	  DUP @EEWAIT                    				--- Wait for the EEPROM write cycle
        EERD DROP 0 I ep
 	    ADO FI2C@ I C@ <> OR DUP IF LEAVE THEN LOOP
        1 I2C@ DROP
     	  IF
 	    DUP @EE DROP 0 I ep ADO I C@ I2C!? OR LOOP I2CSTOP		--- Write 64 bytes and check acks
         	IF $0D EMIT ." FAIL @" DUP .WORD THEN
        THEN
    	  SPINNER                      					--- console spinner to show it's busy
    	  ep +
  	ep +LOOP DROP
 	;

--- Load a block of EEPROM to RAM
pub ELOAD ( eeprom ram cnt -- )
	ROT  @EEWAIT EERD DROP				--- select the device - might have to wait
	  ADO FI2C@ I C! LOOP				--- sequential reading from EEPROM into RAM
	ENDRD						--- signal last byte read
 	;

--- fill EEPROM except src and cnt must be page aligned (64 or 128)
pub EFILL ( src cnt ch -- )				--- fill EEPROM from src address with cnt times byte ch)
	SWAP 0
 	DO ( src ch )
	  OVER @EEWAIT					--- write address but wait if necessary
	  ep FOR DUP I2C! NEXT I2CSTOP			--- store one page's worth of data to EEPROM and write
	  SWAP ep + SWAP				--- increment src by page size
	ep +LOOP					--- next page
	2DROP
	;



--- copy cnt bytes from eesrc to eedst )
pub ECOPY ( eesrc eedst cnt -- )
	ADO
	  DUP BUFFERS ep ELOAD
	  BUFFERS I ep ESAVE	\ 5 ms
	ep +
	ep +LOOP DROP
	;
IFDEF EXPLORER

pub EVERIFY ( ram cnt -- \ compare cnt bytes of EEPROM with RAM starting at address ram )
	OVER @EEWAIT EERD DROP
	  ADO ackI2C@ DUP I C@ <>
 	    IF .INDEX I C@ .BYTE SPACE .BYTE
 	    ELSE DROP
 	    THEN
 	  LOOP
	ENDRD
	;

    }

IFDEF EXPLORER
\ SLOW I2C! (100kHz)
\ This routine runs at a slow I2C speed of >125kHz
pub SI2C!?	 ( data -- ) 					--- write a byte to the I2C bus and return with the ack (0=ack)
	#24 REV							--- put into lsb first format for SHROUT
 	SCL SWAP SDA DUP OUTSET SWAP				--- position clock and data masks ( scl sda dat )
 	8 FOR
	  SHROUT						--- Shift out next data bit
	  3RD OUTSET 3RD OUTCLR					--- clock
	  NEXT							--- loop
	DROP DUP INPUTS						--- Float SDA
	OVER OUTSET IN SWAP OUTCLR				--- ack clock
	;

pub SI2C!  SI2C!? DROP ;

\ SLOW I2C@ (100kHz)
\ Fetch a byte from the I2C bus - mirror ack signal 0 in = 0 out
pub SI2C@	( ack -- data )
	SDA DUP INPUTS 0  ( ack iomask dat )
	  8 FOR CLOCK 0 DROP SHRINP CLOCK 0 DROP NEXT
	ROT 0= IF OVER OUTCLR THEN
 	CLOCK 0 DROP CLOCK SWAP INPUTS
	BL REV
 	;


pri .SUB ( n -- )		PRINT"  #" >N 2/ $0A .NUM ;
pub .DEVICE ( adr -- )
 	SWITCH
 	$A0	CASE ep 128 = IF PRINT" 64K" ELSE PRINT" 32K" THEN PRINT"  BOOT EEPROM   " BREAK
 	$98	CASE PRINT" MMA7660 SENSOR " BREAK
 	SWITCH@ DUP 4 SHR SWITCH
 	3	CASE PRINT" TEMP SENSOR?   " .SUB BREAK
 	$0A	CASE PRINT" EEPROM or RTC  " .SUB BREAK
 	4  	CASE PRINT" I/O EXPANDER   " .SUB BREAK
 	7	CASE PRINT" I/O-KEYS-LED   " .SUB BREAK
 	6	CASE PRINT" SEIKO RTC?     " .SUB BREAK
 	$0D	CASE PRINT" RTC/ADC?       " .SUB BREAK
 	DROP
		     PRINT" Unknown device "
;

( Scan I2C bus at 100kHz and 400kHz for devices and report )

pub SignI2C
 	i2csig 8 ERASE
	I2CSTOP
	0 $100 0
 	DO
	  I2CSTART 5 us I SI2C!? 0=			--- detect slow (any) devices first
	  IF
	    I2CSTART I  I2C!? 0= 1 AND			--- Flag true if fast device detected
 	    I + OVER 7 AND i2csig + C! 1+			--- append address and fast/slow flag to sig string
 	    I2CSTOP 5 us
 	  THEN
	2 +LOOP
 	DROP
	I2CSTOP						\ some devices signal busy unless a stop is detected
	;

pub lsi2c
	PRINT"  Scanning I2C bus"
 	SignI2C
 	i2csig
  	BEGIN DUP C@
 	WHILE
 	  DUP C@ 1 AND  CR IF ." Fast" ELSE ." Slow" THEN
 	  SPACE DUP C@ .DEVICE PRINT"  at $" DUP C@ .BYTE PRINT" : "
 	  I2CSTART DUP C@ 1 OR SI2C!
 	  16 FOR 0 SI2C@ .BYTE SPACE NEXT 		\ and list first 8 bytes we read
 	  1 SI2C@ DROP I2CSTOP  					\ then a dummy nak read
	  1+
 	REPEAT
	DROP
	;



    }


--- Only backup if there are no errors recorded
pub ?BACKUP
 	errors C@ ?EXIT
--- Backup the current Tachyon Forth session
pub BACKUP
	EEPROM
	0 0 (end) ep ALIGN OVER - ESAVE
	;

--- Select EEPROM device for DUMP command access
--- Usage: 0 $100 EE DUMP
pub EE		' EC@ dmm W! ' EW@ dmm 2+ W! ' E@ dmm 4 + W! ;


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

#23 MODULE:   COUNTERS

--- always include these words, very useful
\ IFNDEF SMALLEST
( COUNTERS )
( Block diagram of a Propeller counter  )
\  There are two counters per cog or 16 total


BYTE ctr PRIVATE		\ latch the selected counter A or B (0 or 1)

pri CTR ( -- addr )
 	$01F8 ctr C@ +
 	;
pri CTR@ ( -- val )
 	CTR COG@
 	;

( Select the desired target CTR A or B before use )
pub A			ctr C~ ;
pub B			1 ctr C! ;

\ Set NCO counter mode
pub NCO			4
pub CTRMODE ( n -- \ Writes to the CTRMODE field of the current CTR channel without disturbing the other bits of the counter )
 	#26		SHL		\ Shift n left 26 bits
 			CTR@		\ Read current CTR so we can OR our data in with it
 			$7C.00.00.00
			ANDN		\ mask it
 			OR		\ blend in our value
pri CTR! ( val -- )
 	CTR COG!
 	;

--- Change counter mode to differential
pub DIFF
	CTR@ 1 26 << OR CTR!
	;

pub DUTY ( -- \ SetDuty counter mode )
 	6 CTRMODE
	;
pub PLL
 	2 CTRMODE
 	;
pub PLLDIV ( n -- )			\ note: showing how to write ASSEMBLER style
 	#23 		SHL		\ move up to the PLLDIV field in the CTR
 			CTR@		\ mask out this field ready for merging
 	7 #23 		SHL
 			ANDN
 			OR		\ merge it
 			CTR!		\ save it
	;

pub APIN ( pin -- \ Set the APIN of the current CTR )
\ 	DUP LOW
 	CTR@ $1F ANDN
 	OR CTR!
	;
pub BPIN ( pin -- \ Set the BPIN of the current CTR )
\ 	DUP LOW
 	9<<
 	CTR@ $1F 9<< ANDN
 	OR CTR!
	;
pub FRQ ( n -- \ Set the value of the current FRQ either A or B )
 	$01FA ctr C@ + COG!
	;


( FREQUENCY GENERATION )
{
Generate frequencies via NCO mode - only need to select A or B beforehand
Pin number can be changed anytime
Multiply hz by 53.6870912 to convert from Hz to FRQ value

USAGE:
Generate a 150kHz signal on pin 21 using the A counter and APIN (vs complementary BPIN)
A #21 APIN #150 KHZ
The A sets a variable and is normally defaulted to this so specifing it is optional unless changed
HZ = FRQ/32 . CLKFREQ
for 96MHZ CLKFREQ use *44.74 to convert
NOTE: Some of these definitions cascade into the next rather than call and exit

}

--- 2^32 / clkfreq / freq
-1 2/ CLKFREQ 10000 / 2/ /	== HZCON

pub MHZ ( MHz -- )
 	#1000 *
pub KHZ ( khz -- )
 	#1000 *
pub HZ ( hz -- )
 	NCO HZCON #10000 */ FRQ
  	CTR@ $1F AND LOW
 	;
pub MUTE
  	CTR@ $1F AND FLOAT
 	OFF CTRMODE
	;


--- quick easy way to typically blink an LED - to blink faster etc just use HZ
pub BLINK ( pin -- ) 	APIN 2 HZ ;


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

( DIGITAL to ANALOG - DUTY DAC )
{
By using the high frequency duty-mode (variable frequency PWM) we can filter the output with a simple RC network to achieve 0 to 3.3V analog output.
The RC values vary depending upon filtering, response, and output impedance but 1K and 0.1uF values are typical.

Example of an RC digital to analog converter buffered by an opamp to convert 0..3.3V to 0..5V

}
--- Write an 8-bit value to the pin as a duty cycle - filter output for a voltage
pub DAC! ( byte pin -- )
	DUP LOW APIN DUTY #24 SHL FRQ
	;

    }

\    }

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

( BACKGROUND TIMER COG FUNCTIONS )
{ DESC:
COUNTER TIMERS - BACKGROUND COG
POLLING
Soft timers are primarily count down to zero and stop with an optional autoexecute vector (ALARM)
Any double variable can be linked automatically when invoked
Elapsed runtime in ms is also maintained

TIMER STRUCTURE:
00: timer long in milliseconds
04: timeout alarm vector
06: link to next timer (1=last)

USAGE:
<value in ms> <address of timer> TIMEOUT
<address of timer> TIMEOUT?
' <function> <address of timer> ALARM


\ demo LED flasher which takes 5 seconds before it starts flashing every 100ms
DOUBLE blinktimer
WORD blinky
: BLINKY
 	#16 PIN@ 0= #16 PIN!			\ toggle pin 16
 	blinky W@ blinktimer TIMEOUT			\ reload timer
 	;
\ Setup the timeout vector for TIMER 0
' BLINKY 0 ALARM
\ Write a reload value to timer's memory which we can change anytime
#100 blinky W!
\ Setup timer 0 to timeout in 5 seconds
#5,000 blinktimer TIMEOUT

}

--- create a timer variable (replaces DOUBLE)
--- ms(4), alarm/mode(2), link(2), tid(1), nu(1), nu(2)
pub TIMER	IMMEDIATE	#12 4 [COMPILE] AVAR ;


\ Define variables used by the background timer cog

WORD	timers PUBLIC		\ link to timers
BYTE	tid PRIVATE
1 timers W!				\ last link

CLKFREQ #1000 / == ttint				\ define the timing constant ( writable constant )

( Background timer API )

{ New timer methods that allow modules to link their timers into the background countdown process
add a timer to the list of timers to countdown,
addr points to 2 longs, first is the timer, second is both the alarm word and the link word
last timer has a link word of 0
link->TIMER3->TIMER2->TIMER1->0
}
pub TIMEOUT ( ms addr -- \ Set the timeout period in ms for this timer - link and init if not already set )
 	SWAP OVER ! --- set it and link it if it has not been linked yet
pri +TIMER ( addr -- )
 	DUP 8 + C@ tid C@ = IF DROP EXIT THEN --- discard and ignore if already linked
 	tid C@ OVER 8 + C! --- set tid
   	timers W@ OVER 6 + W! --- link in new timer (first one is set to 1 )
 	timers W! --- save latest in timers
	;

pub COUNTUP ( addr -- \ countup timer mode )
 	1 SWAP
pub ALARM ( pfa addr -- \ Set an alarm action to perform once timeout occurs )
	4 + W!
	;
pub TIMEOUT? ( addr -- flg \ check if this timer has timed out )
	@ 0=
	;

IFDEF EXPLORER
\ List the timers and their status
pub .TIMERS
      SPACE CLKFREQ ttint / ." ticks = 1/" 0 PRINTDEC
 	timers W@
 	BEGIN
 	  DUP $FF >
 	WHILE
 	  CR DUP .WORD 	  ." : "
 	  DUP 1- >NAME DUP PRINT$ LEN$ #20 SWAP - SPACES
 	  DUP @ 6 PRINTDEC ." ms "
 	  ." =" DUP @ .LONG
 	  ."  L" DUP 6 + W@ .WORD
 	  SPACE DUP 4 + W@ IF ." ALARM=" DUP 4 + W@ >NAME PRINT$ THEN
 	  6 + W@ --- fetch the link to the next timer
 	REPEAT
 	DROP
 	;

    }

( WATCHDOG TIMER )
{
Watchdog timer, default action is to reboot, activate from application by specifying a timeout period:
#3000 WATCHDOG --- reload the watchdog timer, if not reloaded within 3 seconds it will reboot
OFF WATCHDOG --- disable watchdog
}

TIMER wdt
pub WATCHDOG ( ms -- )		wdt TIMEOUT ;


{ test timer method
TIMER timer1
TIMER timer2

-1 timer1 TIMEOUT
-1 2/ timer2 TIMEOUT
.TIMERS
TIMER lockout
#10,000 lockout TIMEOUT
.TIMERS
}


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

( REAL-TIME CLOCK )

LONG	runtime
10 BYTES time

--- DS3231 I2C RTC DRIVER ---

$D0    == @rtc        --- device I2C address

--- selects type of I2C RTC chip used
pub DS3231	$D0 ' @rtc 1+ ! ;
pub MCP79410	$DE ' @rtc 1+ ! ;
pub NORTC	0 ' @rtc 1+ ! ; NORTC				--- define and set default RTC as NORTC


pub RTC! ( byte addr -- )
    I2CSTART @rtc I2C! I2C! I2C! I2CSTOP
    ;
pub RTC@ ( addr -- byte )
    I2CSTART @rtc I2C! I2C! I2CSTART @rtc 1+ I2C! 1 I2C@ I2CSTOP
    ;

8 BYTES rtcbuf


\ Read first 8 timekeeping bytes of RTC into rtcbuf
pub RDRTC
    @rtc
    IF
      I2CSTART @rtc I2C! 0 I2C! I2CSTART @rtc 1+ I2C!
      rtcbuf 8 ADO 0 I2C@ I C! LOOP 1 I2C@ DROP
      I2CSTOP
    THEN
;
\ Write first 8 timekeeping bytes of RTC from rtcbuf
pub WRRTC
    @rtc
    IF
      I2CSTART @rtc I2C! 0 I2C!
      rtcbuf 8 ADO I C@ I2C! LOOP
      I2CSTOP
    THEN
    ;

pub BCD>DEC ( bcd -- dec )
    DUP >N SWAP 4 SHR #10 * +
    ;
pub DEC>BCD ( dec -- bcd )
    #10 U/MOD 4 SHL +
    ;

pub TIME@ ( -- #hhmmss ) \ read time in decimal format
    @rtc
    IF
      RDRTC
      rtcbuf 2+ C@ $3F AND BCD>DEC #10000 *
      rtcbuf 1+ C@ BCD>DEC #100 * +
      rtcbuf C@ $7F AND BCD>DEC +
      DUP time !
    ELSE
      time @ 1000 /
      60 U/MOD ( sec x ) 60 U/MOD ( sec mins hrs ) 24 MOD 10000 * SWAP 100 * + +
    THEN
    ;
pub TIME! ( #hh.mm.ss -- ) \ write time in decimal format
    @rtc
    IF
      DUP time !
      RDRTC
      #100 U/MOD SWAP DEC>BCD $80 OR rtcbuf C!		--- ensure some RTC devices have a 'RUN' bit set otherwised it is ignored.
      #100 U/MOD SWAP DEC>BCD rtcbuf 1+ C!
      DEC>BCD rtcbuf 2+ C!
      WRRTC
    ELSE
      100 U/MOD 100 U/MOD 60 * SWAP + 60 * + 1000 * time !	--- store time in milliseconds
    THEN
    ;

--- read international date in decimal format
pub DATE@ ( -- #yymmdd )
    @rtc
    IF
      RDRTC
      rtcbuf 6 + C@ BCD>DEC #10000 *
      rtcbuf 5 + C@ $3F AND BCD>DEC #100 * +
      rtcbuf 4 + C@ $3F AND BCD>DEC +
      DUP time 4 + !						--- copy to hub memory
      rtcbuf 3 + C@ 7 AND time 8 + C!
    ELSE
       time 4 + @
    THEN
    ;
--- Usage: #130630 DATE! \ set the date to the 30th June 2013
pub DATE! ( #yy.mm.dd -- )
    @rtc
    IF
    DUP time 4 + !						--- copy date to hub memory
    RDRTC
    #100 U/MOD SWAP DEC>BCD rtcbuf 4 + C!
    #100 U/MOD SWAP DEC>BCD rtcbuf 5 + C!
    DEC>BCD rtcbuf 6 + C!
    WRRTC
    ELSE
       time 4 + !
    THEN
    ;

pub DAY@ ( -- day ) --- read the day of the week as 0-6
    time 8 + C@
     ;
pub DAY ( day -- )
     DUP time 8 + C!
     @rtc IF rtcbuf 3 + C@ 7 ANDN + rtcbuf 3 + C! WRRTC ELSE DROP THEN
     ;

1 == MON
2 == TUE
3 == WED
4 == THU
5 == FRI
6 == SAT
7 == SUN

pub .TIME
     TIME@ ":"
pri .DTF ( value sep -- )
     SWAP #10 >RADIX <# # # OVER HOLD # # SWAP HOLD # # #> PRINT$ RADIX>
     ;

--- Print date in international format YYYY/MM/DD (otherwise 1/12/2013 could be 1st of December or 12th of January)
pub .DATE        PRINT" 20" DATE@ "/" .DTF ;

pub .DAY        DAY@ 1- 3 * " MONTUEWEDTHUFRISATSUN" + 3 CTYPE ;

pub .ASMONTH ( index -- )
    >N 1- 3 * " JanFebMarAprMayJunJulAugSepOctNovDec" + 3 CTYPE
    ;
pub .DT        .DATE SPACE .DAY SPACE .TIME ;

--- read temperature from DS3231
pub 'F ( -- 'F*100 )        $12 RTC@ $11 RTC@ B>W ;
pub 'C ( -- 'C*100 )        'F #3200 - 5 * 9 / ;

( TIMERS )
--- Maintain chained list of TIMERS by counting down 32-bits to zero every millisecond if set
pri CountDown
	timers W@					--- next timer
 	BEGIN
 	  DUP $FF >					--- another timer?
	WHILE
 	  DUP 4 + W@ 1 =				--- count up mode? (ALARM=1)
 	  IF						--- count up mode
 	    DUP ++					--- count up without anything else
 	  ELSE						--- count down mode
 	    DUP @ ?DUP					--- non-zero?
 	    IF
 	      1- DUP 3RD !				--- decrement non-zero timer and udate
 	        0= IF DUP 4 + W@ DUP 4 SHR		--- if now zero then execute valid alarm if set
 	          IF CALL ELSE DROP THEN
 	        THEN
 	    THEN
 	  THEN
 	  6 + W@					--- follow link to next timer
 	REPEAT
 	DROP
	;

#12 LONGS timerstk					--- allot space for timer data stack (typ. 4 levels)
WORD timerjob
pub TIMERJOB ( cfa -- )		BEGIN timerjob W@ 0= UNTIL timerjob W! ;

pub TIMERTASK ( DESC: Provide background timing functions including alarm actions on timeouts )
 	timerstk SP!								--- Setup a datastack for this cog
	1 timers W!								--- reset timer chain
 	3 tid C+!								--- timer boot id - if timer id is same as this then it has already been added since boot
	runtime ~								--- clear variables
	ttint DELTA								--- set the WAITCNT DELTA for every millisecond
 	wdt 8 ERASE								--- disable watchdog
 	0 wdt TIMEOUT								--- but link it into the timer list
	' REBOOT wdt ALARM							--- set default watchdog behaviour
	BEGIN
 	  timerjob W@ ?DUP IF CALL timerjob W~ THEN				--- allow other cogs to get this cog to handle I/O inits etc
 	  runtime ++
 	  CountDown								--- maintain the linked chain of countdown timers
	  @rtc NOT IF time ++ THEN
 	  $F000.0000 INPUTS							--- make sure no alarm routine affects these lines (in this cog).
	  WAITCNT								--- synch to next heartbeat
	AGAIN
	;



--- EXTENDED KEY POLLING – UP TO 8 ENTRIES
8 WORDS polls
pub ?POLL
 	polls 16 ADO I W@ ?DUP IF CALL THEN 2 +LOOP
 	;
pub +POLL ( cfa -- )
 	polls 16 ADO I W@ 0= IF DUP I W! LEAVE THEN LOOP DROP
 	' ?POLL keypoll W!
	;


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---


--- PING MODULE ---

pub PING ( trig echo -- us )
    MASK 3 COGREG!								--- setup WAITPxx mask
    DUP HIGH >R R> LOW								--- 10us trigger (dummy cycles)
    (WAITPEQ) (WAITPNE)								--- detect high period
    0 COGREG@ 1 COGREG@ -							--- calculate high period
    CLKFREQ #1,000,000 / /							--- convert cycles to us
    ;

--- return with the range in mm using trig pin and echo pin
pub DISTANCE ( trig echo -- distance.mm )	PING 170145 1,000,000 */ ( #1,000 / 954 * )  ;

{
--- Generates a differential output frequency
pub HZ2		5 CTRMODE HZCON #10000 */ FRQ ;
--- simple proximity alert
pub PROX
	#P19 APIN #P20 BPIN --- setup piezo to be driven differentially
	#P19 LOW #P20 LOW
	BEGIN #P16 #P17 DISTANCE 2000 SWAP - 2* 0 MAX HZ2 50 ms 0 HZ2 100 ms ESC? UNTIL
	MUTE
	;
}

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

--- DHT22 HUMIDITY AND TEMPERATURE ---


LONG httime									--- last time DHT was polled
WORD htref,rh,htsav								--- timing reference and last valid readings
BYTE htck									--- checksum

pri DHTBIT ( -- cnt )
	(WAITPEQ)								--- wait for it to go high
	0 COGREG@								--- get captured CNT
	(WAITPNE)								--- until it goes low
	0 COGREG@ SWAP -							--- calculate timing of high period
	;

pri DHTBYTE ( -- byte )
	0 8 FOR 2* DHTBIT htref W@ > 1 AND OR NEXT
	DUP htck C+!
	;

{HELP DHT@ ( pin -- rh temp | -1 )
Read the relative humidity and temperature from the DHT22
Return with rh and temp in Celsius
If an error occurred in the checksum then return last valid reading
If the sensor is polled more than once every 2 seconds then use last valid readings
Typical acquisition time ~6ms
}
pub DHT ( pin -- rh temp )
 	runtime @ httime @ - 2000 =>						--- don't poll more than once every 2 seconds
 	IF
 	  runtime @ httime !							--- mark runtime when this was polled
 	  htck C~
	  DUP MASK 3 COGREG!
	  DUP LOW 1 ms DUP FLOAT						--- Generate reset pulse
	  DHTBIT DROP								--- wait for start of response
	  DHTBIT 3 / 2* htref W!						--- use start bit as reference
	  DHTBYTE 8<< DHTBYTE +							--- 2 bytes humidity reading
	  DHTBYTE 8<< DHTBYTE +							--- 2 bytes temperature reading
	  htck C@ DHTBYTE =							--- if checksum does not match then use last reading
 	    IF htsav W! rh W! ELSE 2DROP THEN					--- latch readings if valid
  	THEN
	DROP rh W@ htsav W@							--- return with latest valid result
	;

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

--- WS2812 ---

pub RGBLEDS ( buffer cnt pin – )
 	MASK
      DUP OUTCLR								--- Start a RET to synch the chips
      4 COGREG!									--- setup the I/O pin for the RUNMOD to use
      [WS2812]									--- select the WS2812 module for RUNMOD
	RUNMOD									--- pass the address of the array and the byte count to the RUNMOD
\\\	#50 us									--- WS2812 needs at least 50us to RET although there are delays elsewhere
	;

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

pub RCTIME ( pin -- time )
	DUP MASK 3 COGREG!
	DUP HIGH 200 us FLOAT
	CNT@  (WAITPNE)
	0 COGREG@ SWAP -
	;


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

#10 MODULE: PWM
IFDEF EXPLORER

WORD pwmtbl,pwmfreq

\ set the PWM duty cycle as a percentage
pub PWM% ( %duty -- dutyval )
	8<< #100 /
	;


{ PWM32 - max freq is 7.6kHz
 Task that runs the PWM engine in a COG
}
LONG pwmmask									--- output mask
pri PWMCOG.TASK
	pwmmask @ OUTCLR							--- set outputs & dir in PWM cog
	[PWM32]									--- load PWM32 runtime module
	pwmtbl W@ pwmfreq W@ RUNMOD						--- and run it
	;

--- Main PWM start method
pub PWM.START ( mask table hz -- | Start up a task to run the multichannel PWM "object" )
	CLKFREQ SWAP / 8>> pwmfreq W!
	DUP $400 ERASE
	pwmtbl W!								--- pass the table address
	pwmmask !								--- pass the I/O mask
	' PWMCOG.TASK TASK? RUN
	;

\ pub PULSEWIDTH ( duty pin -- )
pub SETPWM ( duty8 pin -- )
 	MASK
pub PWM! ( duty8 mask -- )
	pwmtbl W@ [PWM32!] RUNMOD
	;
\ pub PULSEWIDTHS ( duty firstpin lastpin -- )
pub SETPWMS ( duty8 firstpin lastpin -- )
 	1+ OVER - MASKS PWM!
 	;

pub SETPWMW ( on on+off pin -- )
 	\ to be implemented
 	;

ALIAS SETPWM PULSEWIDTH
ALIAS SETPWMS PULSEWIDTHS

    }
}   \  end of   #10 MODULE: PWM



--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

{
Spin header bytes $0000..$000F:
0-3 Clock speed
4 : Clock Mode
5 : Checksum
6-7 : PBase - Start of object
8-9 : VBase - Start of Variables
10-11 : DBase - Start of Stack
12-13 : PCurr - Pointer to start of first spin object to run
14-15 : DCurr - Stack pointer
The byte sum is computed from 0 to the address before VBASE plus eight extra bytes, which are $FFF9FFFF, $FFF9FFFF.
You then subtract this from whatever was at location $5. The two $FFF9FFFF values make up the initial Spin stack frame that is added by the loader.
The sum of the extra bytes is $EC, which is -$14
}

IFDEF EXPLORER
#11 MODULE: HEX FILE LOAD & DUMP
( HEX FILE LOAD & DUMP )

\ Allocate enough memory for typical 16 bytes/line + headers etc
$20 BYTES hexbuf	PRIVATE
LONG hexptr,dst,hexadr
BYTE hexflg,hexch


\ Write bytes from hexbuf to dest
pri WRITEHEX
	2 hexflg SET
	hexbuf C@++ ( ptr cnt )							--- Process 1st byte = count
	SWAP C@++ 8<< ( cnt ptr adrh )						--- next 2 bytes are the destination address
	SWAP C@ +	( cnt addr )
	2DUP + DUP hexadr !							--- Update last unwritten address pointer (external use)
   	<CR> .WORD ." : "
	dst @ + ( cnt dst )							--- add in the offset
	hexbuf 4 + SWAP ROT ( src dst cnt )					--- and write this line to the destination
 	dmm 4 + W@ ' E@ =
 	  IF SWAP @EEWAIT ADO I C@ I2C! LOOP I2CSTOP				--- write directly to EEPROM if "EE" is selected
 	  ELSE CMOVE THEN							--- else write directly to hub ram
	;
pri +HEX ( nibble -- )
	hexch C@ 4 SHL + hexch C!
	1 hexflg SET?
	  IF hexch C@ hexptr @ C! hexptr ++ 1 hexflg CLR
	  ELSE 1 hexflg SET
	  THEN
	;
pri HEX: ( char -- \ Process Intel Hex input )
	DUP ":" = IF DROP hexch C~ hexflg C~ hexbuf hexptr ! EXIT THEN
	DUP "0" "9" WITHIN IF "0" - +HEX EXIT THEN
	DUP "A" "F" WITHIN IF $37 - +HEX EXIT THEN
	DUP $0A = 2 hexflg SET? 0= AND
 	SWAP $0D = OR
 	IF hexptr @ hexbuf - 5 >						--- terminate on an empty line else write a valid line
	  IF WRITEHEX  ELSE R> DROP THEN
 	THEN
	;

{HELP HEXLOAD ( dst -- )
Load an Intel hex file into the destination area
If EE is specified prior to execution then the EEPROM will be loaded
}
pub HEXLOAD ( dst -- \ Load an Intel Hex file into the dst area )
	dst !
	BEGIN KEY HEX: AGAIN
	;
{HELP IDUMP ( src cnt -- )
 Dump EEPROM memory in Intel hex format so that a binary can be created on a PC
but calculate the checksum of a Propeller binary image first
includes the boot spin method located at the end of memory
17 bytes at the end of memory are used for buffers and are not included.

00 clkfreq
04 clkmode
05 chksum
06 pbase
08 vbase
0A dbase
0C pcurr
0E dcurr
7FEF temp checksum
7FF0 temp hex buffer
}
pri IDUMP ( src cnt -- )
	OVER @EEWAIT								--- Wait until the EEPROM is ready
	EERD DROP								--- Init sequential read from EEPROM
	ADO
 	  $7FEF C~								--- Proceed with Intel hex dump
	  0 $7FF0 16 ADO ackI2C@ DUP I C! + LOOP
	  IF									--- skip line if eeprom is blank
	    CR ":" EMIT								--- Header symbol :
 	    16 DUP $7FEF C+! .BYTE						--- byte count :10
 	    I >B $7FEF C+!
 	    I 8>> >B $7FEF C+!
 	    I .WORD								--- address :10aaaa
 	    0 .BYTE								--- control byte :10aaaa00
 	    $7FF0 16								--- 16 bytes of data
 	      ADO I C@ DUP $7FEF C+! .BYTE LOOP					--- data bytes :10aaaa
  	    $7FEF C@ NEGATE .BYTE
	  THEN
         16
 	+LOOP
  	CR ." :00000001FF" CR
 	ENDRD
	;

{HELP DUMPROM
Adjust and dump the current Tachyon binary image in Intel hex format for conversion at the PC end to a bin file
The bin file should be renamed as .binary to suit the Prop tool
}
--- Fix the binary header and checksum so that the Spin tool will recognize the final binary
pub FIXBIN ( src cnt -- )
	5 C~									--- zero our cksum
	0 0 $16 ESAVEB								--- backup header into EEPROM (with checksum zeroed)
	SWAP @EE DROP EERD DROP							--- Setup EEPROM for sequential read
 	  FOR ackI2C@ 5 C+! NEXT						--- add up all the bytes in memory
	ENDRD									--- terminate EEPROM read
	5 C@ NEGATE 5 EC!
	;

pub DUMPROM
	0 $8000
	2DUP FIXBIN
 	CLS
 	IDUMP
	;
    }
}        \ end of       #11 MODULE: HEX FILE LOAD & DUMP


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

( REPORTING )
#18 MODULE: COMPILER REPORTING

WORD resets

pri .diff	?DUP IF ."  bytes (" DUP 0< NOT IF "+" EMIT THEN 0 PRINTDEC ")" EMIT THEN ;

pub lsclk
	." FREQ:   " CLKFREQ #1,000,000 U/MOD SWAP ?DUP IF 0 PRINTDEC ELSE 0 PRINTDEC ." MHZ" THEN
 	PRINT"  ("
 	4 C@ $40 AND IF PRINT" PLLEN " THEN
	4 C@ $20 AND IF PRINT" OSCEN " THEN
	4 C@ 3 SHR 3 AND 6 * " XINPUTXTAL1 XTAL2 XTAL3 " + 6 CTYPE
 	SPACE
 	4 C@ 7 AND 6 * " RCFASTRCSLOWXINPUTPLL1X PLL2X PLL4X PLL8X PLL16X" + 6 CTYPE
 	PRINT" )"
	 ;

--- BUILD INFO

$FFF0 == build
build == build.time
build 4 + == build.date

pub .BUILD ." FIRMWARE BUILD DATE " build.date E@ $60A .NUM ." :" build.time E@ $60A .NUM ;

--- DATE@ build.date E! TIME@ build.time E!

' LAP $FF > IF 64 ELSE 32 THEN == %L	--- adjust LAP readings for instruction itself 150526

--- 140811 Modified for any clock frequency, 150526 compensate for type of LAP op (single or XOP)
--- 150614 Fixed bug in calculation and switch to 64-bit to increase range and resolution up to CNT limit.
pub .LAP ( -- \ prints time since last LAP )
	#18 COGREG@ %L - 0 MAX ( cnt )
	1000 CLKFREQ #1,000,000 U/ UM*/ 			--- result is in ns
 	OVER 999,999,999 U> OVER 0= AND
 	OVER OR
 	  IF 1,000,000 UM/MOD64 3 .DP PRINT" secs" DROP
 	  ELSE DROP DUP 999,999 U> IF 1,000 / 0 3 .DP PRINT" ms" ELSE  0 3 .DP PRINT" us" THEN
 	  THEN
 	;


pub END  ( -- \ denotes end of source code module, does some housekeeping )
 	]~
	CR CR IFDEF .TIME .TIME } ."   End of source code, "
	lines W@ .DEC ."  lines processed and "
	errors W@ DUP IF BELL THEN .DEC ."  errors found "
	CR ." Load time = " LAP .LAP
	.MODULES
	2 flags CLR
{HELP .STATS
Display current Tachyon status thus:
VER:    Propeller .:.:--TACHYON--:.:. Forth V24150105.2330
FREQ:   80MHZ (PLLEN OSCEN XTAL1  PLL8X )
NAMES:  $64EF...74B6 for 4,039
CODE:   $0924...5B92 for 21,102
CALLS:  2 vectors free
RAM:    2,397 bytes free
BOOTS:  153
}
pub .STATS
	CR
 	." VER:  " .VER
 	lsclk
	#10 >RADIX	 							--- allow signed decimal numbers to be printed (.DEC is unsigned)
--- NAMES
	CR ." NAMES:  $" @NAMES DUP .WORD ." ..."  ( @names )			--- display dictionary usage
 	(end) DUP .WORD 	( @names @end )
	."  for " SWAP - 0 PRINTDEC
 	names 2- W@ @NAMES - .diff						--- display difference from start of load
--- CODE
	CR ." CODE:   $" XCALLS $800 + DUP .WORD				--- display CODE usage
 	." ..." HERE .WORD
  	."  for " HERE SWAP - 0 PRINTDEC					--- x
	HERE here 2- W@ - .diff							--- display code difference from start of load
{ deprecated as not that important since we have 16-bit direct calls
--- .VECTORS
\ 	0 XCALLS $800 ADO I W@ 0= 1 AND + 2 +LOOP				--- count the number of free vectors
	0 XCALLS BEGIN DUP @ 1+ WHILE DUP W@ 0= 1 AND ROT + SWAP 2+ REPEAT			--- count free vectors stopping on -1 long
	DROP
	CR PRINT" CALLS:  " 0 PRINTDEC ."  vectors free"
}
--- FREE RAM
	CR ." RAM:    " @NAMES HERE - 0 PRINTDEC ."  bytes free"
--- BUILD
 	CR PRINT" BUILD:  " .BUILD
 	BELL RADIX>
pub .BOOTS
--- RESETS
 	3 SPACES ." BOOTS:  " resets W@ 0 PRINTDEC
	3 SPACES ." runtime " runtime @ 0 PRINTDEC
 	autorun W@
pri .AUTORUN ( pfa -- )
 	?DUP IF CR PRINT" BOOT:   " >NAME PRINT$ THEN
pub .POLL
 	keypoll W@
	IF
	  PRINT" POLL:   "  keypoll W@ >NAME PRINT$
	  polls 16 ADO I W@ IF CR SPACE I polls - 2/ . SPACE I W@ >NAME PRINT$ THEN 2 +LOOP
	THEN
	;





} \ end of   #18 MODULE: REPORTING



--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

--- simple string evaluation using I/O channel
WORD evp PRIVATE
LONG evio PRIVATE
pri (EVAL)			evp W@ C@ evp W++ DUP 0= IF DROP evio @ uemit ! $0D THEN ;
pub EVAL$ ( str -- )		evp W! uemit @ evio ! ' (EVAL) ukey W! NULLOUT ;


\ some code for initialization ??  just right at the end of the file  - NOT optional ? MJB

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

--- Set TACHYON's baudrate for next reboot (or hit ^C or send break to reboot now)
pub CONBAUD ( baud -- \ Set TACHYON's baudrate for next reboot  )
	_con 2DUP ! E!  --- change baudrate location directly
;


--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

--- 160606 PING PONG ADDITIONS
--- directly sets the mask in eeprom of the driver's cog image - needs a reboot before it is active
--- configure PING PONG NETWORK - set trpin/tepin to -1 if not used
pub PPCFG ( trpin tepin baud myadr -- ) ( off -- )
	?DUP
	IF
	  $80 OR 3 rxpars E!				--- Set ID
	  CLKFREQ SWAP / DUP 6 rxpars E!		--- set baud
 	  2/ 4 - 7 rxpars E!				--- and start bit timing
	  MASK? 5 rxpars E! MASK? 4 rxpars E!		--- set te and tr pins
	ELSE
	 3 3 ADO 0 I rxpars E! LOOP
	THEN
;
--- Set the group ID $00..$0F --> $E0..$EF (this setting is not retained between resets
pub GROUP ( n -- )
	>N $E0 OR
	rx W@ 6 - C!
	;
pub .PPCFG
	3 rxpars EC@ $7F AND '#" EMIT . SPACE
	'@' EMIT CLKFREQ 6 rxpars E@ / 0 PRINTDEC
	PRINT"  TR/TE=" 4 rxpars E@ >| . '/' EMIT 5 rxpars E@ >| .
	;

--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

#25 MODULE: TERSE COMMAND MODE

--- table of execution vectors for all printable characters (and DEL)
---  !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~

96 WORDS tcodes

--- table building word
: AS ( ch -- ) IMMEDIATE
	[COMPILE] ' [COMPILE] GRAB SWAP  BL - 2* tcodes + W!
	;

[PRIVATE
--- redefine VM opcodes as hub executable words
: ~+ + ; : ~- - ; : ~! ! ; : ~@ @ ; : ~* * ;


--- define some terse commands --- just add in the same manner
'.' AS .
'+' AS ~+
'-' AS ~-
'*' AS ~*
'/' AS /
'S' AS .S
'V' AS .VER
'D' AS DUMP
'P' AS PPCFG
'R' AS REBOOT
'!' AS ~!
'@' AS ~@

LONG tkeys	--- maintain history of last few characters

--- Accumulate this digit but push old one if previous character was not a digit
: +DIGIT	tkeys 1+ C@ "0" "9" WITHIN NOT IF 0 THEN 10 * tkeys C@ "0" - + ;

--- just fill in the digit codes automatically at compile time
0 10 ADO ' +DIGIT I $10 + 2* tcodes + W! LOOP
PRIVATE]

--- enter terse mode after a terminator such as a CR or SPACE or TAB - any control key exits
: ^ IMMEDIATE
	BEGIN
	  BEGIN KEY >B ?DUP UNTIL
	  DUP BL =>
	WHILE
	  tkeys @ 8<< OVER + tkeys ! BL - 2* tcodes + W@ ?DUP IF CALL THEN
	REPEAT
	DROP CR
	;

\ : .tcodes 96 0 DO I 2* tcodes + W@ ?DUP IF CR I BL + DUP .BYTE SPACE EMIT SPACE PFA>NFA PRINT$ THEN LOOP ;

} --- end of MODULE #25



--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

pub RECLAIM IMMEDIATE	delim 1+ C@ BL = IF PRINT" from " [NFA'] DUP 0= IF PRINT" no such word " THEN ELSE $8000 THEN	(RECLAIM) .STATS ;



IFDEF EXPLORER
{HELP lshw
List the results of the hardware scan routines including clock, I/O pins, registers and I2C bus.
}
pub lshw
 	CR lsclk CR lsio CR lsregs CR lsi2c
 	CR CR PRINT" Hardware signature = " iosig @ .LONG "," EMIT iosig 4 + @ .LONG
 	i2csig 4 FOR "," EMIT DUP @ .LONG 4 + NEXT DROP
 	DECIMAL
;




{HELP CLKFREQ? ( -- freq )
Measure a space character entered at 115,200 baud
and return with the clock frequency rounded to 0.25MHz
to allow for measurement errors.
}
pub CLKFREQ? ( -- freq )
	!SP
	#31 MASK >L
	IX WAITPNE 0 COGREG@
	IX WAITPEQ 1 COGREG@
	SWAP - DUP 400 / + 6 / 			--- add 0.25% for errors and 1/6 = bittime
	L> DROP
 	115,200 * 					--- by baudrate = clkfreq
\ 	250,000 ROUND 				--- round to nearest 0.25MHZ
	;
    }


IFDEF V3
{
roms          byte "ROMS"
              long @romend-@roms
              byte "ROMS"                      ' verification sig.

then for each ROM
              byte ".ROM"                       ' ROM signature (4)
              word @vgaend-@vgarun              ' size (2)
              byte "VGA32x15  "                ' name 10 chars
}

$E000		== roms
$1F00		== romsz
" .ROM" U@	== .rom

pub lsroms
	roms E@
	IF " ROMS" DUP PRINT$
	  U@ .rom roms
	BEGIN DUP E@ 3RD =
	  IF ( ROMS PTR )
	   CR DUP 4 + EW@ .DEC SPACE DUP 6 + 10 ADO I EC@ EMIT LOOP
	   DUP 4 + EW@ +
	  ELSE
	   4 +
	  THEN
	DUP roms romsz + =>
	UNTIL
	2DROP
	ELSE PRINT" NO ROMS "
	THEN
;
pri NEXTROM ( addr -- addr2 | false )
\	CR DUP .WORD SPACE
	BEGIN DUP E@ .rom <> WHILE 4 + DUP roms romsz + => IF DROP FALSE EXIT THEN REPEAT
;
pri FINDROM ( name -- nameaddr | false )
	roms
	BEGIN NEXTROM DUP
	WHILE ( name @rom ) 6 + OVER U@ OVER E@ = IF OVER 4 + U@ OVER 4 + E@ = IF NIP EXIT THEN THEN
	DUP 2- EW@ + 2+  ( skip over this rom )
	REPEAT
	NIP
;
{		--- COGINIT ( code pars cog -- ret )
@VGA $200 + vgapars 2 COGINIT DROP
0 = Tachyon console
1 = serial recevie
2 = TIMER
}
pub LOADCOG ( pars cog name  -- )
	FINDROM ?DUP
	IF
	  PRINT" Loading cog " OVER PRINT SPACE DUP .WORD
	  DUP 10 + SWAP 2- EW@ ( pars cog addr cnt )
	  BUFFERS SWAP ep ALIGN ELOAD			--- load image into BUFFERS (up to 2k)
	  BUFFERS ROT ROT COGINIT DROP
	THEN
;


}




LONG boot								--- set to a random number each boot as a signature
WORD uboot

pub Q
\	OFF CURSOR RAM
IFDEF SPLASH SPLASH }
	.STATS
\	PRINT" PCB: "  " PCB$" FIND ?DUP IF CALL PRINT$ THEN CR
	.MODULES
	lsroms
\	HERE .WORD PRINT" :  -->HERE" CR
\	@NAMES .WORD PRINT" :  DICTIONARY<--" CR
\	keypoll W@ ?DUP IF <CR> ." POLL: " >NAME PRINT$ CR THEN
 	uboot W@ .AUTORUN CR
	;

\ Startup code for background
pub EXTEND.boot
	RND boot !
 	resets EW@ 1+ resets EW!
 	keypoll W~ 							--- stop any background polling in case it's been locked in
 	polls 16 ERASE

	' TIMERTASK 2 RUN						--- always run this in this cog
 	Q DECIMAL
	ESC? NOT	 						--- abort uboot if escape has been pressed
 	IF
 	  " !PCB" CALL$							--- call user !PCB by searching dictionary !!! mod for EEWORDS
 	  uboot W@ ?DUP IF DUP >NAME					--- disregard invalid or expired boot (no header)
 	    IF CALL ELSE DROP THEN
 	  THEN
 	THEN
	;



IFDEF AUTORUN
'a' NFA' AUTORUN ?DUP IF 1+ C! THEN					--- Rename old AUTORUN to aUTORUN
aUTORUN EXTEND.boot
}
IFNDEF AUTORUN
' EXTEND.boot autorun W!
}

\ redefine AUTORUN so that EXTEND.boot can manage it --- 140603 make it backup automatically
pub AUTORUN IMMEDIATE
	[COMPILE] ' [COMPILE] GRAB DUP uboot W! uboot EW!
 	;




pub COLD
	2 6 ADO I STOP LOOP KOLD
	;




IFDEF DATE@
DATE@ build.date E! TIME@ build.time E!
}
IFNDEF DATE@
0 build.date E! 0 build.time E!
}


]~

DECIMAL --- let's use decimal as the default base on startup
END

IFDEF V3

--- Scan first 32k of EEPROM for any ROMs and move them up into the special ROM area, then forget this routine
: SAVEROMS
	" ROMS" U@ @NAMES 3 ANDN ' TACHYON 3 ANDN
	DO I E@ OVER =				--- found a match for "ROMS"
	  IF I 8 + E@ OVER =			--- Yes but verify for additional ROMS sig
	    IF
	      CR PRINT" COPY ROMS @" I .WORD
	      PRINT"  for " I 4 + E@ .DEC
	      I roms I 4 + E@ romsz MIN ECOPY LEAVE
	    THEN
	  THEN
	4 +LOOP
	DROP
	;
SAVEROMS
0 U@		--- wipe ROMS pattern from U@ register
FORGET SAVEROMS
}

?BACKUP



