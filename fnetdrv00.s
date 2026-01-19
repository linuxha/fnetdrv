;*   File name   FLEXNet.txt
;*
;*   This is a driver package which implements
;*   a remote mounted ".DSK file drive" over a serial line.
;*
;*** If the remote end is running on a slow machine, you might have
;*   to remove the "***" comments, which will activate some delays
;*   and "hand shaking". There is also a constant in the "delay"
;*   routine, that can be changed for fine tuning. "As is," (with
;*   the "***" comments removed) the constants have been tuned to
;*   run with a 40 MHz 386 PC as the host computer.
;*
;*   Also, the "odelc" constant might have to be increased, if the
;*   remote end has a slow HD. Otherwise, a time-out error might
;*   occur during file pointer positioning.
;*
;*
;*   vn  01.00   2000-09-15, BjB
;*       01.01   2000-09-19, BjB:    fixing typos and omissions
;*       02.00   2000-09-24, BjB:    time-out if comm link is broken
;*       02.01   2000-09-24, BjB:    fixed verify
;*       02.03   2000-09-30, BjB:    options for "fast/slow PC"
;*       03.00   2002-05-01, js      Add jump vectors for rchar/schar
;*       03.01   2002-08-30, js      Add string search routine to
;*                                   avoid duplicate loads
;*       03.02   2002-09-19, JS      Add ACIA reset vector and move all
;*                                   vectors after signature
;*       03.03   2002-11-23, js      Add the "remember drive letter" function
;*                                   and longer delay for floppies
;*       03.04   2002-11-29  js      Add a few pointers for uninstall
;*
;*   CONVERTED TO 6800 ASSEMBLY LANGUAGE FOR FLEX OS
;*
;* ---------------------------------------------------------------
;*
;*   This part will be relocated below the FLEX [MEMEND].
;*   The code must be position-independent so that it remains
;*   functional after relocation!
;*
;* ---------------------------------------------------------------
;*
        org    $0000


;* The following lines should all stay together: jump table,
;* signature, vectors, and a few pointers. The Rxxx.CMD utilities
;* expect them to keep the same relative position, so if they
;* are moved they MUST be moved together as one single block.
;*
;*   FLEX disk driver jump table
;*
fread   rmb    3         ;* read single sector
fwrite  rmb    3         ;* write single sector
fverfy  rmb    3         ;* verify write operation
frestr  rmb    3         ;* restore head to track# 00
fdrive  rmb    3         ;* drive selection
fcheck  rmb    3         ;* check ready
fquick  rmb    3         ;* quick check ready

;* signature string

sgnst   fcc    'netUUdrv'

len     equ    *-sgnst

        jmp    schar     ;* vector for send character
        jmp    rchar     ;* vector for receive character
        jmp    reset     ;* vector for ACIA reset

        fcc    'FLEXNet 4.1.0'

drvltr  rmb    4         ;* MS-DOS drive letter
netdrv  fcb    -1        ;* Flex drive selected as DOS drive
        fcb    -1        ;* -1 means no drive mapped
        fcb    -1
        fcb    -1

qcheck  fcb    0         ;* 0 = do not do Quick Check before reading and writing sectors
;*                               1 = do Quick Check before reading and writing sectors
slowpc  fcb    1         ;* 0 = not slow PC
;*                               1 = Slow PC


size    fdb    drvend    ;* Size of drivers

;* End of "block"

;*
;*   Local variables
;*
curdrv  rmb    1         ;* current drive from fcb
curtrk  rmb    2         ;* current ttss#
chksum  rmb    2         ;* checksum
cnt     rmb    1         ;* div counter
lstdrv  rmb    1         ;* latest drive# selected
delcnt  rmb    1         ;* inner time-out delay counter
;*                               (default is drive 3)
odelc   rmb    2         ;* max delay
pkgadr  rmb    2         ;* package base address (for PC-relative emulation)
;*
;*   Read one sector from 'net drive'
;*
nread   psha
        pshx
        ldaa   -64+3,x   ;* get requested drive#
        staa   curdrv
        ldx    pkgadr
        ldab   curdrv
        abx
        ldx    netdrv,x
        ldaa   curdrv
        cmpa   0,x       ;* same as assigned 'net drive'#?

        pulx
        pula
        bne    fread     ;* no, do FLEX read routine

        pshx             ;* save FCB pointer
        std    curtrk    ;* save current ttss#
        clr    chksum    ;* clear checksum
        clr    chksum+1  ;* 
        clr    cnt       ;* 256 bytes to read
;*
;*   Q(uick) Check that remote drive is ready
;*
        ldaa   qcheck
        beq    nqchk1

        ldaa   #'Q       ;* Send Q command
        jsr    schar
        bcc    nrea10    ;* "Drive not ready" time out
        jsr    rchar     ;* get response
        bcc    nrea10    ;* time out
        cmpa   #ack      ;* got an ack?
        bne    nrea10    ;* nope, report error

        ldaa   slowpc
        beq    nqchk1

        jsr    delay     ;* for "slow PC" ***

nqchk1  ldaa   #'s       ;* Send sector command
        jsr    schar
        bcc    nrea10    ;* "Drive not ready"

        ldaa   slowpc
        beq    ntslw1

        jsr    delay     ;* for "slow PC" ***

ntslw1  ldaa   curdrv    ;* drive number
        jsr    schar
        bcc    nrea10
        ldaa   curtrk    ;* tt#
        jsr    schar
        bcc    nrea10
        ldaa   curtrk+1  ;* ss#
        jsr    schar
        bcc    nrea10

nrea04  jsr    rchar     ;* read one byte
        bcc    nrea10
        staa   ,x        ;* store in FCB
        inx              ;* move pointer
        adda   chksum+1  ;* update checksum lsb
        staa   chksum+1
        bcc    nrea08    ;* bra if no carry
        inc    chksum    ;* update checksum msb

nrea08  dec    cnt       ;* decrease byte count
        bne    nrea04    ;* loop till 0

        jsr    rchar     ;* get checksum msb
        bcc    nrea10
        psha             ;* save for now
        jsr    rchar     ;* get checksum lsb

        tab              ;* make lsb
        pula             ;* restore msb
        bcc    nrea10    ;* time out?

        cmpa   chksum    ;* compare checksums msb
        bne    nrea12    ;* bra if checksum err
        cmpb   chksum+1  ;* compare checksums lsb
        bne    nrea12    ;* bra if checksum err

        ldaa   #ack      ;* send ack char
        jsr    schar
        bcc    nrea10
        clrb             ;* report okay
        bra    nrea16

nrea10  ldab   #16       ;* report Drive not ready
        bra    nrea16

nrea12  ldaa   #nak      ;* send nak char
        jsr    schar
        bcc    nrea10
        ldab   #09       ;* report read error (CRC)

nrea16  stab   chksum    ;* for later test
        tstb             ;* for FLEX error check
        pulx             ;* restore FCB pointer
        rts
;*
;*   Write one sector to 'net drive'
;*
nwrite  psha
        pshx
        ldaa   -64+3,x   ;* get requested drive#
        staa   curdrv
        staa   lstdrv    ;* last drive written to
        ldx    pkgadr
        ldab   curdrv
        abx
        ldx    netdrv,x
        ldaa   curdrv
        cmpa   0,x       ;* same as assigned 'net drive'#?

        pulx
        pula
        bne    fwrite    ;* no, do FLEX write routine

        pshx             ;* save FCB pointer
        std    curtrk    ;* save current ttss#
        clr    chksum    ;* clear checksum
        clr    chksum+1  ;* 
        clr    cnt       ;* 256 bytes to send
;*
;*   Q(uick) Check that remote drive is ready
;*
        ldaa   qcheck
        beq    nqchk2

        ldaa   #'Q       ;* Send Q command
        jsr    schar
        bcc    nwri10    ;* "Drive not ready" time out
        jsr    rchar     ;* get response
        bcc    nwri10    ;* time out
        cmpa   #ack      ;* got an ack?
        bne    nwri10    ;* nope, report error

        ldaa   slowpc
        beq    nqchk2

        jsr    delay     ;* for "slow PC" ***

nqchk2  ldaa   #'r       ;* Receive sector command
        jsr    schar
        bcc    nwri10    ;* "Drive not ready"

        ldaa   slowpc
        beq    ntslw2

        jsr    delay     ;* for "slow PC" ***

ntslw2  ldaa   curdrv    ;* drive number
        jsr    schar
        bcc    nwri10
        ldaa   curtrk    ;* tt#
        jsr    schar
        bcc    nwri10
        ldaa   curtrk+1  ;* ss#
        jsr    schar
        bcc    nwri10

        ldaa   slowpc
        beq    nwri04

        jsr    delay     ;* for "slow PC" ***

nwri04  ldaa   ,x        ;* get byte from FCB
        inx              ;* move pointer
        jsr    schar
        bcc    nwri10
        adda   chksum+1  ;* update checksum lsb
        staa   chksum+1
        bcc    nwri08    ;* bra if no carry
        inc    chksum    ;* update checksum msb

nwri08  dec    cnt       ;* decrease byte count
        bne    nwri04

        ldaa   chksum    ;* send checksum msb
        jsr    schar
        bcc    nwri10
        ldaa   chksum+1  ;* send checksum lsb
        jsr    schar
        bcc    nwri10

        jsr    rchar     ;* get response
        bcc    nwri10
        cmpa   #ack
        bne    nwri12    ;* bra if not ack

        clrb             ;* report okay
        bra    nwri16

nwri10  ldab   #16       ;* report Drive not ready
        bra    nwri16

nwri12  ldab   #10       ;* disk file write error

nwri16  stab   chksum    ;* for later check
        tstb             ;* for FLEX error check
        pulx             ;* restore FCB pointer
        rts
;*
;*   Verify last sector written
;*
nverfy  ldaa   lstdrv    ;* was last drive# = new drive#?
        pshx
        ldx    pkgadr
        ldab   lstdrv
        abx
        ldx    netdrv,x
        ldaa   lstdrv
        cmpa   0,x       ;* same as assigned 'net drive'#?

        pulx
        bne    fverfy    ;* no, do FLEX verify routine

        ldab   chksum    ;* get latest checksum test result
        tstb
        rts
;*
;*   Restore to track# 00
;*
nrestr  ldaa   3,x       ;* get requested drive#
        pshx
        ldx    pkgadr
        ldab   3,x
        abx
        ldx    netdrv,x
        ldaa   3,x
        cmpa   0,x       ;* same as assigned 'net drive'#?

        pulx
        bne    frestr    ;* no, do FLEX restore routine

        clrb             ;* nothing to do with 'net drive'
        rts
;*
;*   Drive select
;*
ndrsel  ldaa   3,x       ;* get requested drive#
        pshx
        ldx    pkgadr
        ldab   3,x
        abx
        ldx    netdrv,x
        ldaa   3,x
        cmpa   0,x       ;* same as assigned 'net drive'#?

        pulx
        bne    fdrive    ;* no, do FLEX drive select routine

        clrb             ;* nothing to do with 'netdrv'
        rts
;*
;*   Check drive ready
;*
ncheck  ldaa   3,x       ;* get requested drive#
        pshx
        ldx    pkgadr
        ldab   3,x
        abx
        ldx    netdrv,x
        ldaa   3,x
        cmpa   0,x       ;* same as assigned 'net drive'#?

        pulx
        bne    fcheck    ;* no, do FLEX check drive ready routine
        bra    nqui04    ;* common for Check & Quick Check
;*
;*   Quick check drive ready
;*
nquick  ldaa   3,x       ;* get requested drive#
        pshx
        ldx    pkgadr
        ldab   3,x
        abx
        ldx    netdrv,x
        ldaa   3,x
        cmpa   0,x       ;* same as assigned 'net drive'#?

        pulx
        bne    fquick    ;* no, do FLEX Quick Check routine

nqui04  ldaa   #'Q       ;* quick check command
        bsr    schar
        bcc    nqui08

        bsr    rchar     ;* get response
        bcc    nqui08
        cmpa   #ack
        bne    nqui08    ;* not ready

        clrb             ;* report drive ready
        bra    nqui12

nqui08  ldab   #16       ;* report drive not ready
        sec

nqui12  tstb
        rts
;*
;*   Receive character.
;*   Returns with character in ACCA and CC set if successful,
;*                           CC cleared if time-out occurred.
;*
rchar   pshx
        bsr    dlyset    ;* go set delay
        ldx    odelc     ;* outer delay counter
        clr    delcnt    ;* inner delay counter

rcha04  ldab   aciac     ;* check if char received
        asrb
        bcs    rcha08    ;* get character

        dec    delcnt    ;* decrement inner delay counter
        bne    rcha04    ;* continue if not = 0
        dex              ;* decrement outer delay counter
        bne    rcha04    ;* continue if not = 0
        bra    rcha12    ;* return with CC cleared

rcha08  ldaa   aciad     ;* read char
rcha12  pulx
        rts
;*
;*   Send character.
;*   Returns with CC set if successful,
;*                CC cleared if time-out occurred.
;*
schar   pshx
        bsr    dlyset    ;* go set proper delay
        ldx    odelc     ;* outer delay counter
        clr    delcnt    ;* inner delay counter

scha04  ldab   aciac     ;* check if tdr is empty
        asrb
        asrb
        bcs    scha08    ;* OK, send char

        dec    delcnt    ;* decrement inner delay counter
        bne    scha04    ;* continue if not = 0
        dex              ;* decrement outer delay counter
        bne    scha04    ;* continue if not = 0
        bra    scha12    ;* return with CC cleared

scha08  staa   aciad     ;* send char
scha12  pulx
        rts
;*
;*   Delay routine (for "slow PC")
;*
delay   clrb
        pshb
        ldab   #50       ;* change if needed
dela04  dec    0,x
        bne    dela04
        decb
        bne    dela04
        pulb
        rts
;*
;*  ACIA reset routine
;*
reset   ldaa   #$03      ;* ACIA master reset
        staa   aciac
        ldaa   #$15      ;* 8 bits, 1 stop, clk/16
        staa   aciac
        rts
;*
;*  Delay set routine
;*  Sets the content of "odelc" as a function of
;*  the drive type; destroys x and b
;*
dlyset  ldx    #100      ;* default value
        ldab   drvltr    ;* get drive letter
        cmpb   #$40      ;* is it floppy?
        bne    dlexit    ;* no, don't change
        ldx    #65535    ;* select longer delay
dlexit  stx    odelc
        rts


;*         end of driver package
drvend  equ    *
;* -----------------------------------------------------------------------------
;*
;* ---------------------------------------------------------------
;*
;*   FLEX equates
;*
warms   equ    $cd03     ;* FLEX warm start
pstrng  equ    $cd1e     ;* write string to display
pcrlf   equ    $cd24     ;* write cr/lf to display
putchr  equ    $cd18     ;* write character to display
gethex  equ    $cd42     ;* get hex number
;*
memend  equ    $cc2b     ;* FLEX end of user RAM
drvtbl  equ    $de00     ;* start of FLEX driver jump table
;*
;*   Misc equates
;*
ack     equ    $06       ;* acknowledge character
nak     equ    $15       ;* negative acknowledge
        
tmp     equ    lstdrv    ;* re-use for temp storage
tries   equ    cnt       ;* re-use for number of tries
;*
;* ---------------------------------------------------------------
;*
;*   The following code will be dropped after a successful
;*   line synchronization and relocation of the driver routines.
;*
;* ---------------------------------------------------------------
;*
         org    $c100

;*
;*   New jump address table
;*
newtbl  fdb    nread     ;* read single sector
        fdb    nwrite    ;* write single sector
        fdb    nverfy    ;* verify write operation
        fdb    nrestr    ;* restore head to track# 00
        fdb    ndrsel    ;* drive select
        fdb    ncheck    ;* check drive ready
        fdb    nquick    ;* quick check drive ready
        
;*---------------------------------------------------------
;*
;*   Start of installer program
;*
;*
;*---------------------------------------------------------

;* -----------------------------------------------------------------------------
start   bra    init
versn   fcb    4,1       ;* version number

init    clra             ;* reset accumulator

;*
;* Display greeting message and version number
;*
        ldx    #greet    ;* point to string
        ldaa   versn     ;* get version number
        ldab   versn+1
        adda   #$30      ;* make ASCII
        addb   #$30
        staa   v1
        stab   v1+2
        jsr    pstrng    ;* go print string
;*
;* Scan memory from MEMEMD to $C000 to find
;* out if a copy of FLEXNet is already loaded
;*
search  ldx    memend    ;* start of search
sear2   inx              ;* Bump pointer
        cpx    #$c000    ;* Finished?
        beq    sear4     ;* Yes, not found
        pshx
        ldx    #sgnst    ;* Point to target string
        clrb             ;* Reset byte counter
        pulx
sear3   ldaa   b,x       ;* Get byte from RAM
        pshx
        ldx    #sgnst
        cmpa   b,x       ;* Same as signature?
        pulx
        bne    sear2     ;* No, bump and restart
        incb             ;* Point to next byte
        cmpb   #len      ;* Finished?
        bne    sear3     ;* No, check next byte
;*
;* string found, already in memory; tell user
;*
        ldx    #alread   ;* already loaded...
        bra    sync17    ;* display then exit
;*
;* Search done and no match found;
;* initialize FLEXNet and go!
;*
sear4   equ    *

;* Get drive number from user

        jsr    gethex    ;* get hex number
        bcs    nonum     ;* skip if not valid
        tstb
        beq    nonum
        psha
        tab
        pula             ;* transfer number to d
        andb   #$03      ;* limit to 3

        pshx
        ldx    pkgadr
        ldaa   #netdrv
        staa   0,x
        abx
        ldx    0,x
        stab   b,x       ;* store in target drive #

        pulx

        bra    sear4     ;* allow multiple drives

nonum   equ    *
;*
;*   Initialize ACIA.
;*

;* This file is the only one which must be
;* system-dependent (i.e. it must be edited
;* to match the address of your serial port).

;* Adaptation for Mike's system:
;*
;*   ACIA on port #0

port    equ    0
BOARD   EQU    16*port+$E000

aciac   EQU    BOARD     ;* ACIA CONTROL REGISTER
aciad   EQU    aciac+1   ;* ACIA DATA REGISTER

;*
        jsr    reset     ;* call the ACIA reset routine

;* default to short delay (i.e. hard disk)
;*
        ldx    #$4000
        stx    odelc

;*   Check if host is ready; "sync" with $55
;*   and then $aa. This will verify that 8 bits
;*   are transferred correctly.
;*
sync    ldaa   #5        ;* number of tries
        staa   tries
        ldaa   #$55      ;* 1:st sync char
sync04  staa   tmp

sync08  jsr    schar     ;* send char
        bcc    sync16    ;* time out, report error

        jsr    rchar     ;* get answer from receiver
        bcc    sync16
        cmpa   tmp       ;* same as sent?
        beq    sync12    ;* yes

        ldaa   tmp
        cmpa   #$55      ;* 1:st sync char?
        bne    sync16    ;* nope, something is wrong

        dec    tries     ;* decrease try count
        bne    sync08    ;* try again if not 0
        bra    sync16    ;* report sync error

sync12  cmpa   #$aa      ;* 2:nd sync char?
        beq    sync20    ;* yes, continue

        ldaa   #$aa      ;* send 2:nd sync char
        bra    sync04

sync16  ldx    #synstr   ;* "Can't sync..."
sync17  jsr    pstrng
        jmp    warms     ;* back to FLEX
;*
sync20  ldx    #scnest   ;* "Serial connection established"
        jsr    pstrng

;*
;*   Now do a "Where am I" command
;*
        ldaa   #'?
        jsr    schar
        bcc    sync16

;*
;*   Receive the current drive and folder string,
;*   and keep the first letter, with some processing:
;*   @ if floppy, other if hard disk
;*
        jsr    rchar
        bcc    sync16    ;* exit if time-out
        psha             ;* save character
        suba   #1        ;* A/B becomes @/A
        anda   #$5E      ;* make upper case
        staa   drvltr    ;* store it as @ if floppy
        cmpa   #$40      ;* is it floppy?
        bne    wtack     ;* no, leave as-is
        ldx    #$FFFF    ;* set long delay
        stx    odelc     ;* store it
;*
;*   receive all other characters and discard them
;*   until the final ACK is received
;*
wtack   jsr    rchar
        bcc    sync16
        cmpa   #ack
        bne    wtack
;*
;*   Inform user about the current drive
;*
        ldx    #drvmsg   ;* point to string
        jsr    pstrng    ;* print it
        pula             ;* retrieve original char
        anda   #$5f      ;* make upper case
        jsr    putchr    ;* print it
        ldaa   #':       ;* ... then print ":"
        jsr    putchr
;*
;*   Copy FLEX driver jump table to new location
;*
        ldab   #7*3      ;* number of bytes to move
        ldx    #$de00    ;* start of FLEX table
        pshx
        ldx    #$0000    ;* new location
        pulx

movtbl  ldaa   ,x        ;* read byte
        inx              ;* move source pointer
        pshx
        ldx    #$0000    ;* target location
        staa   ,x        ;* store
        inx              ;* move target pointer
        pulx
        decb             ;* decrement byte counter
        bne    movtbl
;*
;*   Move package to below current [MEMEND]
;*
        ldaa   #$55      ;* Point to a dummy drive number...
        staa   lstdrv    ;* ... so that 'net drive'is not selected
;*
        ldx    memend    ;* make room for package
        pshx
        ldx    #drvend   ;* end of package = byte count
        pulx
        pshx
        pshx
        tsx
        subd   2,x       ;* subtract package size
        std    memend
        std    pkgadr    ;* save package address for PC-relative emulation
        pulx
        pulx

        ldx    memend    ;* target pointer
        pshx
        ldx    #$0000    ;* start of package

movpkg  ldaa   ,x        ;* get one byte
        inx              ;* move source pointer
        pshx
        tsx
        ldx    2,x       ;* get target pointer
        staa   ,x        ;* store
        inx              ;* move target pointer
        tsx
        stx    2,x       ;* update target pointer on stack
        pulx
        cpx    #drvend   ;* end of package?
        blo    movpkg    ;* no, continue
        pulx             ;* clean up stack
;*
;*   Set new addresses in FLEX jump table
;*
        ldx    #$de01    ;* target pointer
        pshx
        ldx    #newtbl   ;* table of new jump addresses
        ldaa   #7        ;* number of addresses to move
        staa   tries

movadr  ldaa   ,x        ;* get address msb
        inx
        ldab   ,x        ;* get address lsb
        inx
        pshx
        adda   memend    ;* add offset to address msb
        adcb   memend+1  ;* add offset to address lsb
        tsx
        ldx    4,x       ;* get target pointer
        staa   ,x        ;* store msb at target
        stab   1,x       ;* store lsb at target
        inx
        inx
        inx              ;* move target pointer (skip jmp opcode)
        tsx
        stx    4,x       ;* update target pointer on stack
        pulx
        dec    tries     ;* decrement address counter
        bne    movadr

        pulx             ;* clean up stack

        ldx    memend    ;* make sure memend points to free mem location
        dex
        stx    memend

        ldx    #instst   ;* "Remote .DSK ..."
        jsr    pstrng
        ldaa   netdrv    ;* get 'net drive'#
        adda   #$30      ;* make ASCII
        jsr    putchr
        jsr    pcrlf
        jmp    warms
;*
;* Messages to the user
;*
greet   fcc    "FLEXNet driver version "
v1      fcb    0,'.,0,4
synstr  fcc    "Can't sync serial transfer!",4
scnest  fcc    "Serial connection established",4
instst  fcc    "Remote .DSK drive installed as drive #",4
alread  fcc    "FLEXNet is already loaded, no action taken.",4
drvmsg  fcc    "Current MS-DOS drive is ",4

;*
        end    start