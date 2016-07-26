TACHYON
[~

FORGET EASYNET.fth
pub EASYNET.fth		PRINT" WIZNET NETWORK SERVERS 150101.0800 " ;

{
The server task is running in the same cog as the Tachyon console through keypoll.

Tested on: Filezilla, Firefox, IE, Chrome

NOTE: Set Filezilla to binary transfer and passive mode.

CHANGELOG:
150101		MJB Fixed bug in FEAT - lacking indentation plus FF bug resulted in failed FTP
140904		Fixed stack bug in RETR, also allowed stack to be reset if it grew past a limit
140731		Fixed CWD to simply reject request but also increased cwd$ size
140703		Updated STOR to do block reads directly to the file
140627		Added FTP RENAME capability
140615		Remove forced port settings during init, leave this to W5xxx driver (ports in EEPROM)
140614		Add in defs for W5100 as well as W5200
140425		Changed module name to EASYNET to emphasize easy methods of networking
140402		Changed disconnect method to allow TCP when ready. Poll stats to reset socket.
140206		Fixing foreground/background sockets
140205		Fixed bugs, added standard debug messages, enabled with ON MSGS
140128		reverted back to fast block send (was debugging using XTYPE)
140121		Modified to work with linked timers
131211		Added polling for ?SEND autosend feature

Spinneret build 150101
.EEMOD
MODULES LOADED:
49F9: EASYNET.fth     	WIZNET NETWORK SERVERS 140918.2000
4111: W5100.fth       	WIZNET W5100 driver 141228.1400

326F: EASYFILE.fth    	FAT32 Virtual Memory Access File System Layer V1.1 141211-1100
2A14: SPINNERET.fth   	Spinneret + W5100 HARDWARE DEFINITIONS 141228.1700
2C84: SDCARD.fth      	SD CARD Toolkit - 141202.0000
1A06: EXTEND.fth      	Primary extensions to TACHYON kernel - 141217-0000
3E02: EEWORDS.fth     	TACHYON DICTIONARY WORDS in EEPROM 141218.1930
 ok
.STATS
VER:	Propeller .:.:--TACHYON--:.:. Forth V24141103.0500
FREQ:   80,000,000
NAMES:  $67AA...748D for 3,299 bytes (+16)
CODE:   $0924...569F for 19,835 bytes (+48)
CALLS:  60 vectors free
RAM:	4,363 bytes free

}


IFNDEF !WIZIO
CR       PRINT" !!!  This module requires WIZnet drivers !!!          "
!!! --- cause loader to halt
}

IFNDEF READYLED
pub READYLED	DROP ;
}
IFNDEF LANLED
pub LANLED		DROP ;
}
IFNDEF LEDS
pri LEDS ;
}

pri UNKNOWN
 	delim C@ 1+ $0D <> IF BEGIN KEY $0D <> WHILE DROP REPEAT THEN		\ if there is more than get it and discard
	LANCON PRINT" 550 Unknown command " word PRINT$ CR LANSEND
	;

WORD un PRIVATE
IFNDEF QUIET
\ Turn the Forth console into a quiet non-echoing/prompting command interpreter
pub QUIET
	IF
 	  OFF ECHO OFF OK				--- Non-interactive mode - just accept "commands"
	  ' NOOP 					--- Disable auto space (added when the console processes a word)
	  ' UNKNOWN 					--- Respond with negative FTP style message for unknown
 	ELSE
 	  ON ECHO ON OK
 	  0 0						--- reset unum and prompt - default shell processing
 	THEN
 	unum W! prompt 2+ W!				--- set vector for further processing if not found or not number
	;
}


\ LANLED blink variables
BYTE ledcnt	PRIVATE
BYTE ledon PRIVATE



( Console diagnostic message handler )
BYTE msgs PRIVATE
pub MSGS ( on/off -- ) msgs C! ;

LONG msgstk PRIVATE
pri <MSG ( level -- )				--- print message to console if message priority is => message setting with 0 being the highest
	uemit @ msgstk ! msgs C@ <=
 	  IF CON ELSE NULLOUT THEN
 	<CR> REVERSE .DT PRINT"  #" SKT@ DUP PRINT SPACE 3 * skt$ + 3 CTYPE SPACE
 	;
pri MSG>	PLAIN CR msgstk @ uemit ! ;


pri FlushSkt	 	  word 1- BL ERASE ;		--- erase any garbage that has already been accumulated


HELP: LANSKT ( -- )
Set console's socket backup to the current one - allows console processing of server commands
}
pub LANSKT		SKT@ socket 1+ C! LAN ;

HELP: UpdateTXWR
Due to limitations of WIZnet read/write register access a copy is maintained and updated when possible
}
pri UpdateTXWR
	TXWRITE LW@ @txwr W! 						--- TXWRITE is now readable - buffer it
	;


TIMER contd

pri KEEPALIVE		#300,000 contd TIMEOUT ;	   			--- ms 300 seconds = 5 MINS


BYTE disreq									--- background timer cog can only request a disconnect
pri DISCREQ		disreq C~~ ;						--- timeout sets disreq flag which is handled by main loop

pub CONNECTED? ( -- flg )
	sCONNECTED? 								--- Has CONNECT interrupt been set?
	DUP IF 								--- and save result
	  OFF ECHO 								--- Setup Tachyon to handle command/response mode
         UpdateTXWR
	  ( 1 <MSG PRINT" CONNECT " MSG> )
	  CON SKT@ .SOCKET 							--- let console know what is happening
 	    BEGIN BEGIN KEY 0= UNTIL 3 ms KEY 0= UNTIL			--- discard any console input as well
 	  LAN
	  KEEPALIVE
 	  ON LANLED
	  FlushSkt								--- flush out anything already sitting there
	  ' DISCREQ contd ALARM
	THEN
	;
HELP: DISCONNECT
Disconnect socket (which may progress through DISCON WAIT) and flip the shell back to the console
Report the socket status
}
pub DISCONNECT	sDISCON CONIO SKT@ .SOCKET LAN ;

pri DISCONNECTED? ( -- flg )
	disreq C@ sESTAB? AND
 	  IF DISCONNECT disreq C~ 0 contd ALARM THEN 			--- process disconnect req if active

 	sCLOSED? sCLOSING? OR 						--- or if it's closed OR closing or $1C?
 	sSTAT LC@ $1C = OR						--- CLOSE WAIT - check this out - gets stuck on this
( #2  22:09:58 TCP 	80 39416 EE08.EE08.  83.  83.	. 00 1C closed wait	150.070XXXX )
 	sDISCON? OR DUP 							--- disconnect interrupt? OR closed - ok
 	IF
	( 1 <MSG PRINT"   LISTENING " MSG> )
	  sCLOSE sOPEN sLISTEN
 	  OFF QUIET
	  OFF LANLED
 	  FlushSkt CONIO
 	  SKT@ .SOCKET
	THEN
	;

pri CONNECT
	( 1 <MSG PRINT" CONNECTING " )
	#3000 contd TIMEOUT							--- allow up to 3 seconds to connect
	  BEGIN sESTAB? contd TIMEOUT? OR UNTIL 				--- Wait for it to be established (WIZNET regsiter quirks)
 	KEEPALIVE
	TXWRITE LW@ @txwr W!							--- refresh txwrite (treat as new connection)
	( PRINT" ---  CONNECTED " MSG> )
	;

BYTE constat 									--- relay connection status to application

{ TELNET IACs
pri /DO			#253
pri IAC ( cmd -- )	#255 EMIT EMIT ;
pri /SB			#250 IAC ;
pri /SE			#240 IAC ;
pri /WILL		#251 IAC ;
pri /WONT		#252 IAC ;
pri /DONT		#254 IAC ;

pri /NAWS		#31 EMIT ;
pri /LINEMODE		#34 EMIT ;
pri /ECHO		1 EMIT ;
}


--- define a "bye" especially for telnet sessions.

ALIAS DISCONNECT BYE
ALIAS DISCONNECT QUIT

pri ?TELNET
	TELNET SOCKET 						--- Use the TELNET socket
	CONNECTED? 							--- New connection?
	IF
 	  "T" constat C!  						--- indicate connection status active as Telnet
  	  1 flags 1+ SET 						--- be interactive but not reset etc with certain controls
	  ledcnt C~
 	  CON CR LAN
 	  autosend C~							--- let 1/128 timeout handle characters or blocks
	  " TELNET.INI" FOPEN$ IF FINPUT THEN			--- execute IAC script to setup remote telnet client
 	  WAITSEND 	  " WELCOME.TEL" FOPEN$
 	    IF (cat)
 	    ELSE PRINT" WELCOME TO THE TACHYON WIZNET TELNET SESSION!" CR   	--- default Welcome banner
 	    THEN
	  FlushSkt           					--- Reset rx buffer and receive
	  LANSKT 							--- redirect console to this LAN socket
 	  OFF QUIET OFF ECHO
	  KEEPALIVE
	THEN
	DISCONNECTED? IF 						--- Process disconnection
 	  ( 0 <MSG PRINT" SESSION ENDED " CR MSG> )
 	  "t" constat C! CONIO
 	  1 flags 1+ CLR
 	THEN
	;


pub RESOLVE ( namestr -- ip )
 	HTTP SOCKET
 	;
{
HTTP/1.0 302 Found
Cache-Control: private
Content-Type: text/html; charset=UTF-8
Location: http://www.google.com.au/?gfe_rd=cr&ei=UH_EVO24O63u8wfd74GYAQ
Content-Length: 262
Date: Sun, 25 Jan 2015 05:29:52 GMT
Server: GFE/2.0
Alternate-Protocol: 80:quic,p=0.02

<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>302 Moved</TITLE></HEAD><BODY>
<H1>302 Moved</H1>
The document has moved
<A HREF="http://www.google.com.au/?gfe_rd=cr&amp;ei=UH_EVO24O63u8wfd74GYAQ">here</A>.
</BODY></HTML>
}
pub GETTIME
 	HTTP SOCKET
 	" google.com" RESOLVE HTTP SOCKET $0C L!			--- contact google.com and set dest IP
 	LAN PRINT" GET /" CR						--- issue GET request

 	--- Date: Sun, 25 Jan 2015 05:29:52 GMT


 	;


\ Print the byte as a decimal number
pri .BYTEDEC ( byte -- )		>B $0A .NUM ;

pri COMMA			PRINT" ,"  ;

pri .IPD ( long -- ) 	DUP #24 SHR .BYTEDEC COMMA DUP 16 SHR .BYTEDEC COMMA DUP 8 SHR .BYTEDEC COMMA .BYTEDEC ;


" user" BL STRING user$

" pass" BL STRING pass$

WORD dataport PRIVATE

#20 dataport W!			\ Default FTP data port


pri GETFNAME
	GETWORD DUP C@ "/" = IF 1+ THEN						--- adjust name if / is used
 	DUP LEN$ 1- OVER  + C@ "." = IF 0 OVER DUP LEN$ 1- + C! THEN 		--- remove final period
 	;


pri ECHOREQ
 	CON CR BEGIN LANKEY DUP EMIT 0= UNTIL					--- Just echo the request to the console for now
 	;

( FTP COMMANDS )
( FTP COMMANDS LINK )

{ NOTES:
RESPONSE CODES:
        There are five values for the first digit of the reply code:

            1yz   Positive Preliminary reply

               The requested action is being initiated; expect another
               reply before proceeding with a new command.  (The
               user-process sending another command before the
               completion reply would be in violation of protocol; but
               server-FTP processes should queue any commands that
               arrive while a preceding command is in progress.)  This
               type of reply can be used to indicate that the command
               was accepted and the user-process may now pay attention
               to the data connections, for implementations where
               simultaneous monitoring is difficult.  The server-FTP
               process may send at most, one 1yz reply per command.

            2yz   Positive Completion reply

               The requested action has been successfully completed.  A
               new request may be initiated.

            3yz   Positive Intermediate reply

               The command has been accepted, but the requested action
               is being held in abeyance, pending receipt of further
               information.  The user should send another command
               specifying this information.  This reply is used in
               command sequence groups.

            4yz   Transient Negative Completion reply

               The command was not accepted and the requested action did not take place, but the error condition is temporary and the action may be requested again.  The user should eturn to the beginning of the command sequence, if any. It is difficult to assign a meaning to "transient",               particularly when two distinct sites (Server- and User-processes) have to agree on the interpretation. Each reply in the 4yz category might have a slightly different time value, but the intent is that the user-process is encouraged to try again.  A rule of thumb in determining if a reply fits into the 4yz or the 5yz(Permanent Negative) category is that replies are 4yz if the commands can be repeated without any change in command form or in properties of the User or Server (e.g., the command is spelled the same with the same arguments used; the user does not change his file access or user name; the server does not put up a new implementation.)

            5yz   Permanent Negative Completion reply

               The command was not accepted and the requested action did not take place.  The User-process is discouraged from repeating the exact request (in the same sequence).  Even some "permanent" error conditions can be corrected, so reinitiate the command sequence by direct action at some point in the future (e.g., after the spelling has been changed, or the user has altered his directory status.)

         The following function groupings are encoded in the second digit:

            x0z   Syntax - These replies refer to syntax errors,
                  syntactically correct commands that don't fit any
                  functional category, unimplemented or superfluous
                  commands.

            x1z   Information -  These are replies to requests for
                  information, such as status or help.

            x2z   Connections - Replies referring to the control and
                  data connections.

            x3z   Authentication and accounting - Replies for the login
                  process and accounting procedures.

            x4z   Unspecified as yet.

            x5z   File system - These replies indicate the status of the
                  Server file system vis-a-vis the requested transfer or
                  other file system action.

         The third digit gives a finer gradation of meaning in each of
         the function categories, specified by the second digit.  The
         list of replies below will illustrate this.  Note that the text




MULTI-LINE RESPONSE: (RFC 959)
       Thus the format for multi-line replies is that the first line
         will begin with the exact required reply code, followed
         immediately by a Hyphen, "-" (also known as Minus), followed by
         text.  The last line will begin with the same code, followed
         immediately by Space <SP>, optionally some text, and the Telnet
         end-of-line code.

            For example:
                                123-First line
                                Second line
                                  234 A line beginning with numbers
                                123 The last line

         The user-process then simply needs to search for the second
         occurrence of the same reply code, followed by <SP> (Space), at
         the beginning of a line, and ignore all intermediary lines.  If
         an intermediary line begins with a 3-digit number, the Server
         must pad the front  to avoid confusion.
}


HELP: USER
FTP COMMAND
Syntax: USER username
Send this command to begin the login process. username should be a valid username on the system, or "anonymous" to initiate an anonymous login.
}
pub USER  IMMEDIATE
	ON LANLED
	GETWORD user$ $!
	PRINT" 331 User admin OK. Password required" CR
	;

pub PASS IMMEDIATE
	ON LANLED
	GETWORD pass$ $!
	PRINT" 230 OK. Current restricted directory is /" CR
	;

LONG type

HELP: TYPE
FTP COMMAND
Syntax: TYPE 	type-character [second-type-character]
Sets the type of file to be transferred. type-character can be any of:
A - ASCII text
E - EBCDIC text
I - image (binary data)
L - local format
For A and E, the second-type-character specifies how the text should be interpreted. It can be:
N - Non-print (not destined for printing). This is the default if 	second-type-character is omitted.
T - Telnet format control (<CR>, 	<FF>, etc.)
C - ASA Carriage Control
For L, the second-type-character specifies the number of bits per byte on the local system, and may not be omitted.
}
pub TYPE IMMEDIATE
	ON LANLED
	GETWORD type 4 CMOVE
	LAN PRINT" 200 TYPE is now " type C@ EMIT CR
	;

HELP: PORT
FTP COMMAND
Syntax: PORT 	a1,a2,a3,a4,p1,p2
Specifies the host and port to which the server should connect for the next file transfer.
This is interpreted as IP address a1.a2.a3.a4, port p1*256+p2.
}
pub PORT IMMEDIATE	\ accept port number
	ON LANLED
	GETWORD NUMBER dataport W!
	LAN PRINT" 200 Port is now " dataport W@ .DEC CR
	;

\ Define min and max for FTP passive ports
#40,000 	== #ftpmin
#50,000 	== #ftpmax

\ 227 Entering Passive Mode (192,168,16,106,248,252)
HELP: PASV
FTP COMMAND
Syntax: PASV
Tells the server to enter "passive mode". In passive mode, the server will wait for the client to establish a connection with it rather than attempting to connect to a client-specified port. The server will respond with the address of the port it is listening on, with a message like:
227 Entering Passive Mode 	(a1,a2,a3,a4,p1,p2)
where a1.a2.a3.a4 is the IP address and p1*256+p2 is the port number.
}
pub PASV IMMEDIATE
	ON LANLED
	#ftpmax #ftpmin GETRND dataport W!						\ pick a random port in the specified range
	FTPDAT SOCKET sCLOSE 								\ Prep the data port socket
	TCP dataport W@ SetPORT sOPEN sLISTEN   					\ Set the port and open listen for connection
 	( 1 <MSG PRINT" FTPDAT CONNECT " MSG> )
	\ respond that all is accepted
	FTP SOCKET LAN									\ switch back to FTP socket
	PRINT" 227 Entering Passive Mode with port " \ dataport W@ .DEC		\ Response with msg and port
	PRINT" (" @sip E@ .IPD COMMA dataport 1+ C@ .BYTEDEC COMMA dataport C@ .BYTEDEC PRINT" )" CR
	;

HELP: SYST
FTP COMMAND
Syntax: SYST
Returns a word identifying the system, the word "Type:", and the default transfer type (as would be set by the TYPE command).
For example: UNIX Type: L8
}
pub SYST IMMEDIATE
	ON LANLED
	PRINT" 215 Unix Type: L8" CR
	;

HELP: FEAT
FTP COMMAND
  Where a server-FTP process does not support the FEAT command, it will
   respond to the FEAT command with a 500 or 502 reply.  This is simply
   the normal "unrecognized command" reply that any unknown command
   would elicit.  Errors in the command syntax, such as giving
   parameters, will result in a 501 reply.

   Server-FTP processes that recognize the FEAT command, but implement
   no extended features, and therefore have nothing to report, SHOULD
   respond with the "no-features" 211 reply.  However, as this case is
   practically indistinguishable from a server-FTP that does not
   recognize the FEAT command, a 500 or 502 reply MAY also be used.  The
   "no-features" reply MUST NOT use the multi-line response format,
   exactly one response line is required and permitted.

   Replies to the FEAT command MUST comply with the following syntax.
   Text on the first line of the reply is free form, and not
   interpreted, and has no practical use, as this text is not expected
   to be revealed to end users.  The syntax of other reply lines is
   precisely defined, and if present, MUST be exactly as specified.

        feat-response   = error-response / no-features / feature-listing
        no-features     = "211" SP *TCHAR CRLF
        feature-listing = "211-" *TCHAR CRLF
                          1*( SP feature CRLF )
                          "211 End" CRLF
        feature         = feature-label [ SP feature-parms ]
        feature-label   = 1*VCHAR
        feature-parms   = 1*TCHAR

   Note that each feature line in the feature-listing begins with a
   single space.  That space is not optional, nor does it indicate
   general white space.  This space guarantees that the feature line can


}
pub FEAT IMMEDIATE
	ON LANLED
	PRINT" 211 no Features supported" CR
{	PRINT" 211-no Features supported" CR
 	PRINT"  yet to be implemented" CR
 	PRINT" 211 End" CR
}
	;

HELP: MDTM
FTP COMMAND
  The server-PI will respond to the MDTM command with a 213 reply
   giving the last modification time of the file whose pathname was
   supplied, or a 550 reply if the file does not exist, the modification
   time is unavailable, or some other error has occurred.

      mdtm-response = "213" SP time-val CRLF /
                      error-response
Example response:
213 19980615100045.014
}
pub MDTM IMMEDIATE
 	ON LANLED
  	GETFNAME FOPEN$ DROP
 	autosend C~~
	PRINT" 550 Modification time not available" CR
	;


HELP: CDUP
FTP COMMAND
Syntax: CDUP
Makes the parent of the current directory be the current directory.
}
pub CDUP IMMEDIATE
	  ON LANLED
	PRINT" 250 Directory successfully changed" CR
	;


" FILENAME.TXT " 0 STRING cwd$

HELP: CWD
Syntax: CWD remote-directory
Makes the given directory be the current directory on the remote host
}
pub CWD ( <name> ) IMMEDIATE
	ON LANLED
	GETWORD DUP cwd$ $! DUP " /" $= SWAP LEN$ 0= OR
 	IF
 	  PRINT" 250 okay"
	ELSE
	  PRINT" 550 Not a directory"
	THEN
 	CR
	;

HELP: PWD
Syntax: PWD
Returns the name of the current directory on the remote host.
}
pub PWD IMMEDIATE
	ON LANLED
	PRINT" 257 \"/\" is your current location" CR
	;



pub ?DISCONNECT   	#300 ms DISCONNECT ;

HELP: LIST
FTP COMMAND
Syntax: LIST [remote-filespec]
If remote-filespec refers to a file, sends information about that file. If remote-filespec refers to a directory, sends information about each file in that directory. remote-filespec defaults to the current directory. This command must be preceded by a PORT or PASV command.
}
pub LIST IMMEDIATE
 	delim 1+ C@ BL = IF GETWORD DROP THEN                 --- ignore a remote-filespec
 	uemit W@ --- allow this to be dumped to the console in interactive mode
 	IF
	  KEEPALIVE
	  ON LANLED LANCON	PRINT" 150 Here comes the directory listing" CR LANSEND
	  ( 1 <MSG PRINT" LIST REQUEST " MSG> )
	  FTPDAT SOCKET CONNECT
 	  autosend C~
	  LAN .LIST							--- Send off the directory listing in compatible format
	  LANSEND WAITSEND
 	  #50 ms
	  FTPDAT SOCKET DISCONNECT
	  autosend C~~
	  FTP SOCKET LANCON PRINT" 226 Directory send OK" CR LANSEND
	  ( 1 <MSG PRINT" LIST SENT " MSG> )
	  ?DISCONNECT
 	ELSE
	  CR .LIST
	THEN
	;

{ This is how most UNIX, Novell, and MacOS ftp servers send their time
                                  Jul 06 12:57 or Jul  6  1999
-rwxrwxrwx	1 502  	500 	674 Sep  4  2014 HELP.TXT
-rwxrwxrwx	1 502  	500   65536 Sep  4  2014 FIRMWARE.ROM
}
{ Feature list from NAS FTP
211-Extensions supported:
 EPRT
 IDLE
 MDTM
 SIZE
 REST STREAM
 MLST type*;size*;sizd*;modify*;UNIX.mode*;UNIX.uid*;UNIX.gid*;unique*;
 MLSD
 TVFS
 ESTP
 PASV
 EPSV
 SPSV
 ESTA
 AUTH TLS
 PBSZ
 PROT
 UTF8
211 End.
}


WORD blkpoll
$200 == BUFSIZ

--- BLKSEND will send a file sector by sector
pri BLKSEND ( xaddr cnt -- )							\ send chunks of up to one complete sector at buffer address
	?DUP 0= IF DROP EXIT THEN
	BEGIN
	  OVER XADR OVER BUFSIZ MIN ( xaddr cnt bufadr bufcnt )		\ grab it a sector at a time
	  >L 										\ save the bufcnt (referenced as IX)
	  IX LSEND									\ copy source buffer directly to socket tx buffer
         blkpoll W@ ?DUP IF CALL THEN						\ callback hook used by applications
	  ( src cnt )
	  IX - SWAP L> + SWAP ( xaddr cnt )					\ update source parameters block by block
	  DUP 0=									\ until the source buffer is exhausted (cnt=0)
 	  sCLOSED? OR									\ or if closed
	UNTIL
	2DROP
	;

--- Send the currently open file in block mode
pub SENDFILE ( offset -- )	FILE@ OVER + FSIZE@ ROT - BLKSEND ;

HELP: SIZE
FTP COMMAND
Syntax: SIZE remote-filename
Returns the size of the remote file as a decimal number.
}
pub SIZE IMMEDIATE
	ON LANLED
  	GETFNAME FOPEN$
 	( 1 <MSG PRINT" SIZE " FILE$ PRINT$ MSG> )
 	LANCON
	IF
	  PRINT" 213 "  FSIZE@ #10 .NUM
	ELSE
 	  PRINT" 550 Could not get file size."
 	THEN
 	CR LANSEND
	;
{

0000_C800:   55 53 45 52  20 61 6E 6F   6E 79 6D 6F  75 73 0D 0A   USER anonymous..
0000_C810:   50 41 53 53  20 63 68 72   6F 6D 65 40  65 78 61 6D   PASS chrome@exam
0000_C820:   70 6C 65 2E  63 6F 6D 0D   0A 53 59 53  54 0D 0A 50   ple.com..SYST..P
0000_C830:   57 44 0D 0A  54 59 50 45   20 49 0D 0A  50 41 53 56   WD..TYPE I..PASV
0000_C840:   0D 0A 53 49  5A 45 20 2F   0D 0A 50 41  53 56 0D 0A   ..SIZE /..PASV..
0000_C850:   43 57 44 20  2F 0D 0A 4C   49 53 54 20  2D 6C 0D 0A   CWD /..LIST -l..

550 Could not get the file size
}

--- send accepted or rejected message to FTP client
pri FTPMSG ( flg -- )
 	FTP SOCKET LANCON
	IF
	  ON LANLED
	  PRINT" 150 Accepted data connection for " FILE$ PRINT$ CR LANSEND
	  FTPDAT SOCKET CONNECT LAN
 	ELSE
	  PRINT" 550 File not available" CR LANSEND
	THEN
 	;

--- FTP rename file request ---

" FILENAME.EXT" 0 STRING RNFR$   \ place for source string for rename (PBJ: 0 STRING or #12 > req for null term.)

HELP: RNFR
FTP COMMAND
Syntax: RNFR from-filename
Used when renaming a file. Use this command to specify the file to be renamed; follow it with an RNTO command to specify the new name for the file.
}
pub RNFR IMMEDIATE
 	GETFNAME RNFR$ $!
 	FTP SOCKET LANCON PRINT" 350 Waiting for RNTO" CR LANSEND
 	;
HELP: RNTO
FTP COMMAND
Syntax: RNTO to-filename
Used when renaming a file. After sending an RNFR command to specify the file to rename, send this command to specify the new name for the file.
}
pub RNTO IMMEDIATE
 	RNFR$ FOPEN$ DROP GETFNAME RENAME$
 	FTP SOCKET LANCON PRINT" 250 Rename done" CR LANSEND
 	;


{
Command:	RETR PREVIOUS.ROM
Response:	150 Accepted data connection for PREVIOUS.ROM
Response:	226 File successfully transferred
Status:	File transfer successful, transferred 65,536 bytes in 1 second
}

--- FTP Retrieve a file i.e. RETR /LOG0001.TXT ---
HELP: RETR
FTP COMMAND
Syntax: RETR remote-filename
Begins transmission of a file from the remote host. Must be preceded by either a PORT command or a PASV command to indicate where the server should send data.
}
pub RETR IMMEDIATE
	KEEPALIVE
	GETFNAME FOPEN$ 								// get the file name and try to open it
 	0 SWAP
pri (RETR) ( position flg/addr -- )
 	DUP FTPMSG
 	IF ( position )
	  FILE$ 3 RIGHT$ " LOG" $=
  	  IF										// If it's a log file then just send up to EOF marker
 	    DROP FILE@ 0 APPEND
 	      IF @FWRITE @ OVER - 16 MAX ELSE FSIZE@ THEN
 	    BLKSEND 									// Just send all the text up to the EOF or at least 16
 	  ELSE 									// else send the whole file
 	    SENDFILE
 	  THEN
	  #100 ms
	  ?SEND
  	  DISCONNECT --- close the data connection
	  FTP SOCKET
 	  LANCON PRINT" 226 File successfully transferred" CR LANSEND 	// Announce successful transfer
 	ELSE
 	  DROP
	THEN
 	FTP SOCKET ?DISCONNECT
	;


HELP: STOR
FTP COMMAND
Syntax: STOR remote-filename
Begins transmission of a file to the remote site. Must be preceded by either a PORT command or a PASV command so the server knows where to accept data from.
Usage
Command:	STOR PREVIOUS.ROM
Response:	150 Accepted data connection for PREVIOUS.ROM
Response:	250 File rcvd PREVIOUS.ROM
Status:	File transfer successful, transferred 65,536 bytes in 5 seconds
}
pub STOR IMMEDIATE
	KEEPALIVE
	GETFNAME 							--- get file name to store
	FOPEN$ RW 							--- try to open it for overwrite
	DUP FTPMSG 							--- send appropriate FTP message if accepted or not, connect to FTPDAT if accepted
 	?SEND
 	IF
 	  ( 1 <MSG PRINT" STOR " FILE$ PRINT$ MSG> )
	  FTPDAT SOCKET
	  BEGIN
	    @FWRITE @
	    LREADSKT ( dst --- )
 	    vwrite @ @FWRITE !							--- update file write index
 	    DISCONNECTED?
 	  UNTIL
	  FTP SOCKET LANCON PRINT" 250 File rcvd " FILE$ PRINT$ CR LANSEND
 	  FSTAMP
 	  ( 1 <MSG PRINT" FILE RCVD"  MSG>)
	THEN
    	FTPDAT SOCKET ?DISCONNECT
 	FTP SOCKET ?DISCONNECT
	;




HELP: REST
FTP COMMAND
Syntax: REST position
Sets the point at which a file transfer should start; useful for resuming interrupted transfers. For nonstructured files, this is simply a decimal number. This command must immediately precede a data transfer command (RETR or STOR only); i.e. it must come after any PORT or PASV command.
}
pub REST ( <position> ) IMMEDIATE
	GETWORD NUMBER 				--- read the offset specified
 	(RETR)						--- retrieve as usual from this offset
	;




{                   Tachyon FTP session
Status:	Connecting to 192.168.16.151:21...
Status:	Connection established, waiting for welcome message...
Response:	220 WELCOME TO THE TACHYON WIZNET FTP SESSION!
Command:	USER admin
Response:	331 User admin OK. Password required
Command:	PASS *****
Response:	230 OK. Current restricted directory is /
Status:	Server does not support non-ASCII characters.
Status:	Connected
Status:	Retrieving directory listing...
Command:	CWD /
Response:	250 Directory successfully changed
Command:	TYPE I
Response:	200 TYPE is now I
Command:	PASV
Response:	227 Entering Passive Mode with port (192,168,16,151,173,118)
Command:	LIST
Response:	150 Here comes the directory listing
Response:	226 Directory send OK
Status:	Directory listing successful

}



( *** FTP SERVER 	- relies on the Forth console to interpret FTP commands directly *** )

pri ?FTP
	FTP SOCKET
	CONNECTED? 						--- examine interrupt register for a new connection etc
	IF
 	  "F" constat C!
	  CON CR ON QUIET
{
	  " WELCOME.FTP" FOPEN$
	  IF
 	    LAN (cat)
 	  ELSE
}
 	autosend C~~

	    LANCON PRINT" 220 WELCOME TO THE TACHYON WIZNET FTP SESSION!" CR --- Welcome banner
\  	  THEN
	  KEEPALIVE 						--- Give FTP a maximum 5 min session
	  LANSKT 						--- makes sure the console uses this connection and socket
	THEN
	DISCONNECTED? IF "f" constat C! CONIO THEN
	;



( HTTP COMMANDS )

--- some WIP here while I sort out my webpage files and content formatting etc


\ Sample content header - just for testing
pri CONTENT ( str -- )
	1 <MSG PRINT" CONTENT = " DUP PRINT$  MSG>
	LANCON autosend C~
	PRINT" HTTP/1.1 200 OK" CR
	PRINT" Date: Tue, 03 Dec 2013 04:19:05 GMT" CR
	PRINT" Server: Tachyon Forth " CR
	PRINT" Last Modified: Tue, 01 Jan 2014 12:00:00 GMT" CR
	PRINT" Accept-Ranges: bytes" CR
	PRINT" Content-Length: " FSIZE@ .DEC CR
	PRINT" Connection: close" CR
	PRINT" Content-Type: " PRINT$ CR
	autosend C~~ CR
	;








#48 BYTES GET$

#48 	== getsz	--- limited in size by GETWORD = 39 or implement new GETPARS to place string directly into GET$

pri ?CONTENT     \  MJB maybe later move to a table based approach
	 \ GET$ 3 RIGHT$
	"." GET$ LOCATE$ 1+   \ MJB prepare for other extensions like "JS"

	DUP " JPG" COMPARE$ IF DROP " image/jpg" CONTENT EXIT THEN		\ Send header for JPG files
	DUP " ICO" COMPARE$ OVER " PNG" COMPARE$ OR
	  IF DROP " image/png" CONTENT EXIT THEN					\ Send header for ICO/PNG files
	DUP " HTM" COMPARE$ IF DROP " text/html" CONTENT EXIT THEN		\ Send header for TEXT/HTML files
	DROP
	;

IFNDEF >UPPER
pri >UPPER  ( str1 --  ) --- Convert lower-case letters to upper-case
	DUP LEN$ ADO I C@ "a" "z" WITHIN IF I C@ BL XOR I C! THEN LOOP
	;
}

pri GETHTX --- temp def
pri GETTXT
 	FILE@ 0 APPEND DROP @FWRITE @ OVER - 16 MAX BLKSEND			\ Just send all the text up to the EOF or at least 16
 	;



--- Send the requested page to the web client ---
pri GETPAGE
	GET$ " /" COMPARE$ 								\ null GET / (root dir)
	  IF " HOME.HTM" DUP GET$ $!						\ Default request - open HOME.HTM
	  ELSE GET$ 1+ DUP >UPPER 							\ otherwise convert requested file name to uppercase
	  THEN
 	FOPEN$ NOT IF " HTTP404.HTM" FOPEN$ DROP THEN 				\ on file not found - use default 404 file
	LAN										\ Direct all output to the selected socket
	?CONTENT									\ Handle content headers
	1 <MSG PRINT"  --> " FILE$ PRINT$ MSG>				\ echo name of actual file served
	UpdateTXWR @txwr W@ TXREAD LW!

	FILE$ 3 RIGHT$
  	DUP " TXT" $= IF DROP GETTXT ?SEND EXIT THEN				\ plain text file  ( only uppercase ?? or is >upper used somewhere?)
 	" HTX" $= IF GETHTX ?SEND EXIT THEN 					\ we have a html template file HTX with embedded FORTH

	FILE@ FSIZE@ BLKSEND								\ or just send the whole file
	?SEND
	;

HELP: HEAD
HTTP COMMAND
The HEAD method is identical to GET except that the server MUST NOT return a message-body in the response. The metainformation contained in the HTTP headers in response to a HEAD request SHOULD be identical to the information sent in response to a GET request. This method can be used for obtaining metainformation about the entity implied by the request without transferring the entity-body itself. This method is often used for testing hypertext links for validity, accessibility, and recent modification.
The response to a HEAD request MAY be cacheable in the sense that the information contained in the response MAY be used to update a previously cached entity from that resource. If the new field values indicate that the cached entity differs from the current entity (as would be indicated by a change in Content-Length, Content-MD5, ETag or Last-Modified), then the cache MUST treat the cache entry as stale.
}
pub HEAD IMMEDIATE --- just repond back with the same head
	ECHOREQ
	;



HELP: GET
HTTP COMMAND
The GET method means retrieve whatever information (in the form of an entity) is identified by the Request-URI. If the Request-URI refers to a data-producing process, it is the produced data which shall be returned as the entity in the response and not the source text of the process, unless that text happens to be the output of the process.
The semantics of the GET method change to a "conditional GET" if the request message includes an If-Modified-Since, If-Unmodified-Since, If-Match, If-None-Match, or If-Range header field. A conditional GET method requests that the entity be transferred only under the circumstances described by the conditional header field(s). The conditional GET method is intended to reduce unnecessary network usage by allowing cached entities to be refreshed without requiring multiple requests or transferring data already held by the client.
The semantics of the GET method change to a "partial GET" if the request message includes a Range header field. A partial GET requests that only part of the entity be transferred, as described in section 14.35. The partial GET method is intended to reduce unnecessary network usage by allowing partially-retrieved entities to be completed without transferring data already held by the client.
The response to a GET request is cacheable if and only if it meets the requirements for HTTP caching described in section 13.
}
pub GET ( <name> -- \ Open up the file name and send it ) IMMEDIATE		--- /index.htm HTTP/1.1
	KEEPALIVE
	LAN GETWORD DUP LEN$ getsz => IF DROP " GET$ to long" THEN
 	GET$ COPY$ 									--- get the name and store in GET$  \ GETWORD
	1 <MSG PRINT" GET " GET$ PRINT$ MSG>					--- Let me know about a request
	ECHOREQ
	GETPAGE
	;

1	== #hskts							--- select from 1 to 4 sockets for HTTP processing

HELP: ?HTTP
Service the HTTP server socket
}
pri ?HTTP
	HTTP #hskts ADO
 	I SOCKET
	CONNECTED?
	  IF
 	    "H" constat C!
	    ON QUIET 							--- Disable interactive mode prompts
	    KEEPALIVE
	    LANSKT 							--- Let the same socket talk to the foreground Forth console when it switches back
	  THEN
 	  DISCONNECTED? IF "h" constat C! CONIO THEN
 	LOOP
	;


\ ----------------------------------------------------------------------------------------------------------- \

\ Check for control keys - this does not read the input buffer
pri ?CTRLS
	lastkey C@ SWITCH lastkey C~
 	^A CASE CONIO DISCARD OFF QUIET PRINT"   ENQ " PLAIN CONSOLE BREAK
	^W CASE [CON DISCARD ifconfig CON] BREAK
 	^K CASE keypoll W~ OFF QUIET CONIO BREAK 					--- kill background key poll (servers)
	^S CASE [CON DISCARD .SOCKETS CON] BREAK
	^Q CASE CON DISCARD 8 0 DO I SOCKET DISCONNECT LOOP BREAK
 	^C CASE CON OFF QUIET DEBUG BREAK
       SWITCH@ IF CONIO OFF QUIET PLAIN THEN
	;

pri ?LED
 	--- the LED should be blinking very briefly when it's idle but alive
	1 ledcnt C+! ledcnt C@ ledon C@ < LANLED LEDS
	--- reflect current connection status as a long or short blink
	constat C@ $61 < IF constat C@ ELSE 1 THEN ledon C!
 	;

BYTE fsave PRIVATE
BYTE netflgs
--- 1	inhibit console shortcuts

( Main server loop - checks and services sockets - 1.3ms when idle )
pub ?EASYNET
	?LED
	SKT@ socket 1+ C! 							--- swap current socket between foreground and background
 	filesel C@ fsave C! 0 FILE 						--- use foreground file
	?TELNET 								--- Poll the TELNET server
	?SENDPOLL
	?FTP 									--- Poll the FTP server
	?HTTP 									--- Poll the WEB server
\\\ 	5 SOCKET SKT@ 5 = IF CONNECTED? IF REBOOT THEN THEN		--- 911 reset
	?SDCARD
  	TRUE 8 0 DO I SOCKET sCLOSED? AND LOOP IF CONIO THEN 		--- force console back to serial if not busy
 	socket 1+ C@ SOCKET 							--- restore foreground socket
 	fsave C@ FILE 							--- restore foreground file
  	DEPTH 8 > IF !SP THEN 						--- clean up abnormal stack
	1 netflgs SET? ?EXIT							--- skip controls if flag is set
	?CTRLS 								--- process console shortcuts
	;

pub RESTART		CON PLAIN ifconfig CR CR REBOOT ;

\ pub CMD?		." Tachyon> " ;


pub GO
pub EASYNET
	!SP
	!PCB !WIZ #150 ms 							--- Setup I2CBUS LEDS (includes WIZNET RESET & PWRDN)
	#5000 @RTR LW! 16 @RCR LC!						--- setup retry counters
	CR PRINT" *** Tachyon Forth EASYNET Network Servers and EASYFILE File Server *** " CR CR
	MOUNT
	4 ledon C! 								--- just setup an LED blink time
	ON READYLED 								---  Now init the IP addresses (stored in high 64K EEPROM)
	TELNET SOCKET sCLOSE TCP #10001 PORT!  sOPEN sLISTEN 		--- Setup TELNET but on port 10001
	FTP SOCKET sCLOSE TCP #21 PORT! sOPEN sLISTEN 			--- Setup FTP
	HTTP #hskts ADO I SOCKET sCLOSE TCP #80 PORT! sOPEN sLISTEN LOOP
\\\ 	5 SOCKET SKT@ 5 = IF TCP #911 PORT! sOPEN sLISTEN THEN 	--- if we have more than 4 sockets then use one for 911 reboot
	1 second
	PRINT"  ... ready! " CR
	ifconfig 									--- report WIZnet status
  	constat C~~
	' ?EASYNET keypoll W! 						--- Poll the server in the background
	CR PRINT" * WEB, FTP, and TELNET servers running * "
	CR
 	;


]~
END
?BACKUP
{
NAMES:  $564A...741D for 7635 (4294967037 bytes added)
CODE:   $0000...4D4F for 12156 (3803 bytes added)
CALLS:  0202 vectors free
RAM:    2299 bytes free

}

--- uncomment this next line to have EASYNET run at boot
\ AUTORUN EASYNET


