TACHYON [~

FORGET EEWORDS.fth
pub EEWORDS.fth		." TACHYON DICTIONARY WORDS in EEPROM 150724.1400 " ;

{
Convert dictionary as indexed blocks of names and introduce fast search methods.
Just run COMPACT to convert whatever there is to upper 32K of 64K EEPROM
Note: Once compacted it is not possible to forget any of those words (for now)
COLD will not work properly, the kernel must be reloaded or else an image restore from before a compact is needed

CHANGELOG:
150724	Fixed bug which was not flushing last block after a COMPACT – lost last word.
15061		Changed origin of cache and buffers to refer to end of dictionary as TF V2.6 rearranges buffers
150323		Added nbuf to prevent end of dict in term area being corrupted (word at end found but atr/code cropped)
150116 	Reference all to #EEBLK which can now be any size in multiples of 64. 256 is fine for most work (only uses 16K EEPROM)
141218 	Main testing, added fast I2C functions
141216 	Adding to EEPROM
141203 	Added .SDMOD which revectors .MODULES - use new EXTEND.fth as well
141201 	Fixed bug in SDCARD.fth and increase &sdto timeout as COMPACT would sometimes crash.

NAMES:  $4FF3...715F for 8,556 bytes (+234)
CODE:   $0924...490A for 16,358 bytes (+757)
}

0	== d?		--- message control constant – set to non-zero to enable debug messages during compact

6	6 SHL == #EEBLK						--- sector block size, multiples of 64 (page writes)

BYTE dictwr
LONG nfasect,dboot						--- starting sector of dictionary, currently indexed sector


(end) ep ALIGN #EEBLK 2* BL 2* + - 16 - ORG				--- reuse old dictionary area for two sets of buffers + terminations

#EEBLK		DS cache					--- dictionary cache plus simple termination area (zeros)
BL 		DS term						--- null termination area, a bit like a gutter
BL		DS nbuf						--- 150323 added as copy buf to leave term free
#EEBLK		DS dict						--- private sector buffer for dictionary

{HELP FRESHEN ( nfaptr -- newnfa )
freshen the existing name in the cache by shuffling it to the top.
}
pub FRESHEN ( nfaptr -- newnfa ) 				--- move word in cache to top of cache (freshen) 8.8us, 204us
 	DUP cache <= IF EXIT THEN				--- don't do anything if it's in the previous section or current
	DUP nbuf BL CMOVE					--- just preserve it for now
 	cache DUP nbuf C@ 4 + + ( nfa src dst )
 	ROT cache - <CMOVE					--- make room at start
 	nbuf cache OVER C@ 4 + CMOVE				--- move it to the top
 	cache
	;

pub (DICT) ( -- \ Check that the dictionary sectors are ready )
	boot @ dboot @ <>					--- remount if rebooted or not init'd
	IF
	  nfasect ~~ dictwr C~					--- clear flags
	  boot @ dboot !
	THEN
	;

{HELP NFA>SECT ( nfa -- addr )
Convert the NFA to the corresponding dictionary address in EEPROM
Indexing method to convert a name into a 1 of 64 sector index offset from EEPROM $8000
add all character codes together and use low nibble of it and 2 ls-bits from character count
}
pub NFA>SECT ( nfa -- addr )
	C@++ ( nfa+1 cnt )
 	SWAP 0 SWAP 3RD ADO I C@ + LOOP >N SWAP 3 AND 4 SHL +
 	#EEBLK * $8000 +
	;


pub EERDBLK ( eadr ram -- )
 	DUP #EEBLK ERASE
	SWAP @EEWAIT EERD DROP					--- select the device - might have to wait
	#EEBLK
	ADO FI2C@ FI2C@ 8<< + FI2C@ 16<< + FI2C@ 8<< 16<< +	--- sequential reading longs from EEPROM into RAM
	    ?DUP 0= IF LEAVE ELSE I ! THEN			--- but abort on a null long - no more text
	4 +LOOP
	ENDRD							--- signal last byte read
	;


{
--- treats upper 32k of EEPROM as 512 byte "sectors"
--- Read up to a block of EEPROM into RAM but cut short on a blank line
pub EERDBLK ( eadr ram -- )
 	DUP #EEBLK ERASE
	SWAP @EEWAIT EERD DROP					--- select the device - might have to wait
	#EEBLK
 	  ADO I 16 ADO FI2C@ I C! LOOP 				--- sequential reading from EEPROM into RAM
 	    I 12 + @ 0= IF LEAVE THEN				--- terminate read as there are only blanks left
 	  16 +LOOP
	ENDRD							--- signal last byte read
	;
}
--- Write up to a block of RAM into EEPROM
pub EEWRBLK ( ram eadr -- )
 	#EEBLK ADO
	  DUP @							--- only write valid text - terminate on nulls
 	  IF DUP I ep ESAVE ep + ELSE LEAVE THEN		--- early termination as remainder is blank
 	ep +LOOP DROP
	;
--- EEPROM search method which presents the correct dictionary sector for FINDSTR to operate on
pub (EESEARCH) ( cstr -- nfaptr )
	DUP names W@ FINDSTR ?DUP IF NIP ( FRESHEN ) EXIT THEN	--- conventional search first
	(DICT)							--- ensure file is mounted
	DUP NFA>SECT						--- open the matching word sector
 	dict ( eesect dict ) EERDBLK				--- read the block in
	dict							--- Try to find the counted string in the dictionary(s) (ignore smudged entries)
	FINDSTR ( cstr dict -- nfaptr | false )
	?DUP
	IF DUP						--- add a new name to the cache - normally from a sector buffer
	    DUP C@ 4 + 						--- find length of entry to move the cache
	    cache 2DUP + #EEBLK 4TH - BL + <CMOVE		--- make room for it
	    cache SWAP CMOVE					--- and add new name to top of cache
 	    --- invalidate overlapping entry
 	    cache DUP #EEBLK + SWAP BEGIN DUP C@ 4 + OVER + 3RD < WHILE C@++ + 3 + REPEAT NIP 2 ERASE
 	ELSE FALSE
 	THEN
;



--- this section is really only needed when creating the WORDS file
--- it does not try to use the private buffers as that memory may not be available yet
--- could be forgotten immediately afterwards if no additional COMPACTing is performed.

pub +NFA ( nfa -- \ add this name field including atr and codebyte field to dictionary blocks )
	d? IF DUP CR nfasect @ .WORD SPACE 1+ PRINT$ SPACE THEN
	DUP C@ 4 + ( name len )
	BUFFERS DUP 3RD + ( name len buf buf+len )
	#EEBLK 4TH - <CMOVE ( name len buf buf+len rem )		--- make room for new entry at start of block
	BUFFERS SWAP CMOVE						--- write header entry to block
	d? IF BUFFERS #EEBLK DUMPA THEN
	dictwr C~~							--- flag that this block has been modified
	;

IFNDEF EFILL
pub EFILL ( src cnt ch -- \ fill EEPROM from src address with cnt times byte ch)
	SWAP 0
	DO ( src ch )
	  OVER @EEWAIT
	  ep FOR DUP I2C! NEXT I2CSTOP
	  SWAP ep + SWAP
	  ep +LOOP
	2DROP
	;
}

pri ?EEFLUSH
 	   nfasect @ 1+
 	   IF dictwr C@
 	     IF BUFFERS nfasect @ EEWRBLK dictwr C~ THEN
 	   THEN
	;
--- convert the dictionary in RAM to a sorted and indexed dictionary in EEPROM
--- COMPACT runs during development so it can use the BUFFERS for file storage whereas runtime uses reclaimed dictionary space
pub (COMPACT)
	(DICT)
 	PRINT"  erasing eeprom sectors.."
	BUFFERS #EEBLK ERASE
	$8000 #EEBLK 64 * $7FC0 MIN 0 EFILL 			--- erase the file, all 64 sectors
pub (+COMPACT)
	(DICT)							--- entry for adding more words to dictionary file
 	PRINT"  compacting.."
	@NAMES ( nfaptr )                    			--- start from the current end of the dictionary (newest)
	BEGIN
 	  SPINNER						--- indicate activity
  	  DUP C@ 0= IF 1+ DUP C@ ELSE TRUE THEN			--- while there is another nfa (double null is end)
	WHILE
  	  DUP NFA>SECT ( nfaptr sect )        			--- get sector address (not read yet) for this NFA
  	  DUP nfasect @ <>                			--- only read it in if it's different
  	  IF							--- read in a new sector
 	  --- flush the previous buffer if needed
 	   ?EEFLUSH
   	    DUP nfasect !                    			--- remember this new sector
   	    BUFFERS EERDBLK	                		--- read in the new sector
  	  ELSE DROP						--- sector already available
  	  THEN
  	( nfaptr )						--- dict sector is ready
	  BUFFERS #EEBLK + BL ERASE				--- workaround to allow an nfa term string to be found
   	  DUP BUFFERS #EEBLK + OVER C@ 1+ CMOVE			--- so that older matches are not added to the dict.
   	  BUFFERS #EEBLK + BUFFERS FINDSTR NOT 			--- now see if this nfa is already added
 	    IF DUP +NFA THEN   					--- add this NFA to it's sector
	  DUP C@ 4 + +                    			--- advance to next NFA
	REPEAT
	DROP                            			--- discard NFA pointer
 	?EEFLUSH
pub !EEWORDS
	' (EESEARCH) ufind W!					--- set new search method
	cache names W!						--- hybrid dictionary, any new words still in standard dictionary
 	cache #EEBLK BL + ERASE					--- clean the cache
 	;

--- Use this method to compact or add to the compact dictionary
--- remember to BACKUP if all is well or wait until the app is loaded even
pub COMPACT
	" EEWORDS.fth" >CSTR @NAMES FINDSTR 		--- is this a fresh or additional compact operation.
 	  IF (COMPACT) 						--- found it in the RAM dictionary so init file for new
 	  ELSE
 	    cache ~							--- make sure cache doesn't get included for additions
 	    ."  adding " (+COMPACT)
 	  THEN
--- search method is locked into the search vector after a BACKUP

 	.STATS
 	;


HELP: EEWORDS
EEWORDS lists all the words in the EE dictionary
This is the EEWORDS equivalent of WORDS to list the dictionary
}
pub WORDS IMMEDIATE
 	delim 1+ C@ BL = IF [COMPILE] WORDS: EXIT THEN			--- if something is following this then use the "N WORDS array"
\ pub EEWORDS
 	(DICT)
 	cache ~								--- invalidate cache
 	5 REG C~							--- long format
 	.WORDS
	8 REG W~
 	CR ." EEPROM WORDS "
 	$8000 #EEBLK #64 *
 	ADO
	  I dict EERDBLK
	  dict 1+ (.WORDS)
 	  #EEBLK
	+LOOP
 	CR ." WORD TOTAL = " 8 REG W@ .DEC
 	;


pub .EEMOD
	' .MODULES CALL							--- absolute call to revectored code (needs original .MODULES)
 	(DICT)
	$8000 DUP							--- top 32k of 64k EEPROM
 	ADO
	  I BUFFERS EERDBLK						--- read another sector (use sdbuf in case it's not compacted yet)
	  BUFFERS (.MODS)
	  #EEBLK
	+LOOP
 	CR
 	;


]~
END

