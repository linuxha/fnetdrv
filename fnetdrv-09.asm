
                     *   File name   FLEXNet.txt
                     *
                     *   This is a driver package which implements
                     *   a remote mounted ".DSK file drive" over a serial line.
                     *
                     *** If the remote end is running on a slow machine, you mig
ht have
                     *   to remove the "***" comments, which will activate some 
delays
                     *   and "hand shaking". There is also a constant in the "de
lay"
                     *   routine, that can be changed for fine tuning. "As is," 
(with
                     *   the "***" comments removed) the constants have been tun
ed to
                     *   run with a 40 MHz 386 PC as the host computer.
                     *
                     *   Also, the "odelc" constant might have to be increased, 
if the
                     *   remote end has a slow HD. Otherwise, a time-out error m
ight
                     *   occur during file pointer positioning.
                     *
                     *
                     *   vn  01.00   2000-09-15, BjB
                     *       01.01   2000-09-19, BjB:    fixing typos and omissi
ons
                     *       02.00   2000-09-24, BjB:    time-out if comm link i
s broken
                     *       02.01   2000-09-24, BjB:    fixed verify
                     *       02.03   2000-09-30, BjB:    options for "fast/slow 
PC"
                     *       03.00   2002-05-01, js      Add jump vectors for rc
har/schar
                     *       03.01   2002-08-30, js      Add string search routi
ne to
                     *                                   avoid duplicate loads
                     *       03.02   2002-09-19, JS      Add ACIA reset vector a
nd move all
                     *                                   vectors after signature
                     *       03.03   2002-11-23, js      Add the "remember drive
 letter" function
                     *                                   and longer delay for fl
oppies
                     *       03.04   2002-11-29  js      Add a few pointers for 
uninstall
                     *
                     * ---------------------------------------------------------
------
                     *
                     *   This part will be relocated below the FLEX [MEMEND].
                     *   The code must be position-independent so that it remain
s
                     *   functional after relocation!
                     *
                     * ---------------------------------------------------------
------
                     *
  0000                       org    $0000
                     
                     
                     * The following lines should all stay together: jump table,
                     * signature, vectors, and a few pointers. The Rxxx.CMD util
ities
                     * expect them to keep the same relative position, so if the
y
                     * are moved they MUST be moved together as one single block
.
                     *
                     *   FLEX disk driver jump table
                     *
  0000               fread   rmb    3         read single sector
  0003               fwrite  rmb    3         write single sector
  0006               fverfy  rmb    3         verify write operation
  0009               frestr  rmb    3         restore head to track# 00
  000C               fdrive  rmb    3         drive selection
  000F               fcheck  rmb    3         check ready
  0012               fquick  rmb    3         quick check ready
                     
                     * signature string
                     
  0015 6E 65 74 55   sgnst   fcc    'netUUdrv'
  0019 55 64 72 76   
               0008  len     equ    *-sgnst
                     
  001D 16   0253             lbra   schar     vector for send character
  0020 16   022C             lbra   rchar     vector for receive character
  0023 16   0280             lbra   reset     vector for ACIA reset
                     
  0026 46 4C 45 58           fcc    'FLEXNet 4.1.0'
  002A 4E 65 74 20   
  002E 34 2E 31 2E   
  0032 30            
                     
  0033               drvltr  rmb    4         MS-DOS drive letter
  0037 FF            netdrv  fcb    -1        Flex drive selected as DOS drive
  0038 FF                    fcb    -1        -1 means no drive mapped
  0039 FF                    fcb    -1
  003A FF                    fcb    -1
                     
  003B 00            qcheck  fcb    0         0 = do not do Quick Check before r
eading and writing sectors
                     *                               1 = do Quick Check before r
eading and writing sectors
  003C 01            slowpc  fcb    1         0 = not slow PC
                     *                               1 = Slow PC
                     
                     
  003D 02C7          size    fdb    drvend    Size of drivers
                     
                     * End of "block"
                     
                     *
                     *   Local variables
                     *
  003F               curdrv  rmb    1         current drive from fcb
  0040               curtrk  rmb    2         current ttss#
  0042               chksum  rmb    2         checksum
  0044               cnt     rmb    1         div counter
  0045               lstdrv  rmb    1         latest drive# selected
  0046               delcnt  rmb    1         inner time-out delay counter
                     *                               (default is drive 3)
  0047               odelc   rmb    2         max delay
                     *
                     *   Read one sector from 'net drive'
                     *
  0049 34   12       nread   pshs   a,x
  004B A6   88 C3            lda    -64+3,x   get requested drive#
  004E A7   8C EE            sta    curdrv,pcr
  0051 30   8C E3            leax   netdrv,pcr
  0054 30   86               leax   a,x
  0056 A1   84               cmpa   0,x       same as assigned 'net drive'#?
                     
                     *       cmpa    netdrv,pcr      same as assigned 'net drive
'#?
                     
  0058 35   12               puls   x,a
  005A 26   A4               bne    fread     no, do FLEX read routine
                     
  005C 34   10               pshs   x         save FCB pointer
  005E ED   8C DF            std    curtrk,pcr save current ttss#
  0061 6F   8C DE            clr    chksum,pcr clear checksum
  0064 6F   8C DC            clr    chksum+1,pcr
  0067 6F   8C DA            clr    cnt,pcr   256 bytes to read
                     *
                     *   Q(uick) Check that remote drive is ready
                     *
  006A A6   8C CE            lda    qcheck,pcr
  006D 27   1E               beq    nqchk1
                     
  006F 86   51               lda    #'Q       Send Q command
  0071 17   01FF             lbsr   schar
 >0074 1024 0076             lbcc   nrea10    "Drive not ready" time out
  0078 17   01D4             lbsr   rchar     get response
 >007B 1024 006F             lbcc   nrea10    time out
  007F 81   06               cmpa   #ack      got an ack?
 >0081 1026 0069             lbne   nrea10    nope, report error
                     
  0085 A6   8C B4            lda    slowpc,pcr
  0088 27   03               beq    nqchk1
                     
  008A 17   020B             lbsr   delay     for "slow PC" ***
                     
  008D 86   73       nqchk1  lda    #'s       Send sector command
  008F 17   01E1             lbsr   schar
  0092 24   5A               bcc    nrea10    "Drive not ready"
                     
  0094 A6   8C A5            lda    slowpc,pcr
  0097 27   03               beq    ntslw1
                     
  0099 17   01FC             lbsr   delay     for "slow PC" ***
                     
  009C A6   8C A0    ntslw1  lda    curdrv,pcr drive number
  009F 17   01D1             lbsr   schar
  00A2 24   4A               bcc    nrea10
  00A4 A6   8C 99            lda    curtrk,pcr tt#
  00A7 17   01C9             lbsr   schar
  00AA 24   42               bcc    nrea10
  00AC A6   8C 92            lda    curtrk+1,pcr ss#
  00AF 17   01C1             lbsr   schar
  00B2 24   3A               bcc    nrea10
                     
  00B4 17   0198     nrea04  lbsr   rchar     read one byte
  00B7 24   35               bcc    nrea10
  00B9 A7   80               sta    ,x+       store in FCB and move pointer
  00BB AB   8C 85            adda   chksum+1,pcr update checksum lsb
  00BE A7   8C 82            sta    chksum+1,pcr
  00C1 24   04               bcc    nrea08    bra if no carry
  00C3 6C   8D FF7B          inc    chksum,pcr update checksum msb
                     
  00C7 6A   8D FF79  nrea08  dec    cnt,pcr   decrease byte count
  00CB 26   E7               bne    nrea04    loop till 0
                     
  00CD 17   017F             lbsr   rchar     get checksum msb
  00D0 24   1C               bcc    nrea10
  00D2 34   02               pshs   a         save for now
  00D4 17   0178             lbsr   rchar     get checksum lsb
                     
  00D7 1F   89               tfr    a,b       make lsb
  00D9 35   02               puls   a         restore msb
  00DB 24   11               bcc    nrea10    time out?
                     
  00DD 10A3 8D FF60          cmpd   chksum,pcr compare checksums
  00E2 26   0E               bne    nrea12    bra if checksum err
                     
  00E4 86   06               lda    #ack      send ack char
  00E6 17   018A             lbsr   schar
  00E9 24   03               bcc    nrea10
  00EB 5F                    clrb             report okay
  00EC 20   0D               bra    nrea16
                     
  00EE C6   10       nrea10  ldb    #16       report Drive not ready
  00F0 20   09               bra    nrea16
                     
  00F2 86   15       nrea12  lda    #nak      send nak char
  00F4 17   017C             lbsr   schar
  00F7 24   F5               bcc    nrea10
  00F9 C6   09               ldb    #09       report read error (CRC)
                     
  00FB E7   8D FF43  nrea16  stb    chksum,pcr for later test
  00FF 5D                    tstb             for FLEX error check
  0100 35   10               puls   x         restore FCB pointer
  0102 39                    rts
                     *
                     *   Write one sector to 'net drive'
                     *
  0103 34   12       nwrite  pshs   a,x
  0105 A6   88 C3            lda    -64+3,x   get requested drive#
  0108 A7   8D FF33          sta    curdrv,pcr
  010C A7   8D FF35          sta    lstdrv,pcr last drive written to
  0110 30   8D FF23          leax   netdrv,pcr
  0114 30   86               leax   a,x
  0116 A1   84               cmpa   0,x       same as assigned 'net drive'#?
                     
                     *       cmpa    netdrv,pcr      same as assigned 'net drive
'?
                     
  0118 35   12               puls   x,a
  011A 1026 FEE5             lbne   fwrite    no, do FLEX write routine
                     
  011E 34   10               pshs   x         save FCB pointer
  0120 ED   8D FF1C          std    curtrk,pcr save current ttss#
  0124 6F   8D FF1A          clr    chksum,pcr clear checksum
  0128 6F   8D FF17          clr    chksum+1,pcr
  012C 6F   8D FF14          clr    cnt,pcr   256 bytes to send
                     *
                     *   Q(uick) Check that remote drive is ready
                     *
  0130 A6   8D FF07          lda    qcheck,pcr
  0134 27   1F               beq    nqchk2
                     
  0136 86   51               lda    #'Q       Send Q command
  0138 17   0138             lbsr   schar
  013B 1024 0083             lbcc   nwri10    "Drive not ready" time out
  013F 17   010D             lbsr   rchar     get response
 >0142 1024 007C             lbcc   nwri10    time out
  0146 81   06               cmpa   #ack      got an ack?
 >0148 1026 0076             lbne   nwri10    nope, report error
                     
  014C A6   8D FEEC          lda    slowpc,pcr
  0150 27   03               beq    nqchk2
                     
  0152 17   0143             lbsr   delay     for "slow PC" ***
                     
  0155 86   72       nqchk2  lda    #'r       Receive sector command
  0157 17   0119             lbsr   schar
  015A 24   66               bcc    nwri10    "Drive not ready"
                     
  015C A6   8D FEDC          lda    slowpc,pcr
  0160 27   03               beq    ntslw2
                     
  0162 17   0133             lbsr   delay     for "slow PC" ***
                     
  0165 A6   8D FED6  ntslw2  lda    curdrv,pcr drive number
  0169 17   0107             lbsr   schar
  016C 24   54               bcc    nwri10
  016E A6   8D FECE          lda    curtrk,pcr tt#
  0172 17   00FE             lbsr   schar
  0175 24   4B               bcc    nwri10
  0177 A6   8D FEC6          lda    curtrk+1,pcr ss#
  017B 17   00F5             lbsr   schar
  017E 24   42               bcc    nwri10
                     
  0180 A6   8D FEB8          lda    slowpc,pcr
  0184 27   03               beq    nwri04
                     
  0186 17   010F             lbsr   delay     for "slow PC" ***
                     
  0189 A6   80       nwri04  lda    ,x+       get byte from FCB and move pointer
  018B 17   00E5             lbsr   schar
  018E 24   32               bcc    nwri10
  0190 AB   8D FEAF          adda   chksum+1,pcr update checksum lsb
  0194 A7   8D FEAB          sta    chksum+1,pcr
  0198 24   04               bcc    nwri08    bra if no carry
  019A 6C   8D FEA4          inc    chksum,pcr update checksum msb
                     
  019E 6A   8D FEA2  nwri08  dec    cnt,pcr   decrease byte count
  01A2 26   E5               bne    nwri04
                     
  01A4 A6   8D FE9A          lda    chksum,pcr send checksum msb
  01A8 17   00C8             lbsr   schar
  01AB 24   15               bcc    nwri10
  01AD A6   8D FE92          lda    chksum+1,pcr send checksum lsb
  01B1 17   00BF             lbsr   schar
  01B4 24   0C               bcc    nwri10
                     
  01B6 17   0096             lbsr   rchar     get response
  01B9 24   07               bcc    nwri10
  01BB 81   06               cmpa   #ack
  01BD 26   07               bne    nwri12    bra if not ack
                     
  01BF 5F                    clrb             report okay
  01C0 20   06               bra    nwri16
                     
  01C2 C6   10       nwri10  ldb    #16       report Drive not ready
  01C4 20   02               bra    nwri16
                     
  01C6 C6   0A       nwri12  ldb    #10       disk file write error
                     
  01C8 E7   8D FE76  nwri16  stb    chksum,pcr for later check
  01CC 5D                    tstb             for FLEX error check
  01CD 35   10               puls   x         restore FCB pointer
  01CF 39                    rts
                     *
                     *   Verify last sector written
                     *
  01D0 A6   8D FE71  nverfy  lda    lstdrv,pcr was last drive# = new drive#?
  01D4 34   10               pshs   x
  01D6 30   8D FE5D          leax   netdrv,pcr
  01DA 30   86               leax   a,x
  01DC A1   84               cmpa   0,x       same as assigned 'net drive'#?
                     
                     *       cmpa    netdrv,pcr
                     
  01DE 35   10               puls   x
  01E0 1026 FE22             lbne   fverfy    no, do FLEX verify routine
                     
  01E4 E6   8D FE5A          ldb    chksum,pcr get latest checksum test result
  01E8 5D                    tstb
  01E9 39                    rts
                     *
                     *   Restore to track# 00
                     *
  01EA A6   03       nrestr  lda    3,x       get requested drive#
  01EC 34   10               pshs   x
  01EE 30   8D FE45          leax   netdrv,pcr
  01F2 30   86               leax   a,x
  01F4 A1   84               cmpa   0,x       same as assigned 'net drive'#?
                     
                     *       cmpa    netdrv,pcr      same as assigned 'net drive
'#?
                     
  01F6 35   10               puls   x
  01F8 1026 FE0D             lbne   frestr    no, do FLEX restore routine
                     
  01FC 5F                    clrb             nothing to do with 'net drive'
  01FD 39                    rts
                     *
                     *   Drive select
                     *
  01FE A6   03       ndrsel  lda    3,x       get requested drive#
  0200 34   10               pshs   x
  0202 30   8D FE31          leax   netdrv,pcr
  0206 30   86               leax   a,x
  0208 A1   84               cmpa   0,x       same as assigned 'net drive'#?
                     
                     *       cmpa    netdrv,pcr      same as assigned 'net drive
'#?
                     
  020A 35   10               puls   x
  020C 1026 FDFC             lbne   fdrive    no, do FLEX drive select routine
                     
  0210 5F                    clrb             nothing to do with 'netdrv'
  0211 39                    rts
                     *
                     *   Check drive ready
                     *
  0212 A6   03       ncheck  lda    3,x       get requested drive#
  0214 34   10               pshs   x
  0216 30   8D FE1D          leax   netdrv,pcr
  021A 30   86               leax   a,x
  021C A1   84               cmpa   0,x       same as assigned 'net drive'#?
                     
                     *       cmpa    netdrv,pcr      same as assigned for 'net d
rive'#?
                     
  021E 35   10               puls   x
  0220 1026 FDEB             lbne   fcheck    no, do FLEX check drive ready rout
ine
  0224 20   12               bra    nqui04    common for Check & Quick Check
                     *
                     *   Quick check drive ready
                     *
  0226 A6   03       nquick  lda    3,x       get requested drive#
  0228 34   10               pshs   x
  022A 30   8D FE09          leax   netdrv,pcr
  022E 30   86               leax   a,x
  0230 A1   84               cmpa   0,x       same as assigned 'net drive'#?
                     
                     *       cmpa    netdrv,pcr      same as assigned for 'net d
rive'#?
                     
  0232 35   10               puls   x
  0234 1026 FDDA             lbne   fquick    no, do FLEX Quick Check routine
                     
  0238 86   51       nqui04  lda    #'Q       quick check command
  023A 8D   37               bsr    schar
  023C 24   0B               bcc    nqui08
                     
  023E 8D   0F               bsr    rchar     get response
  0240 24   07               bcc    nqui08
  0242 81   06               cmpa   #ack
  0244 26   03               bne    nqui08    not ready
                     
  0246 5F                    clrb             report drive ready
  0247 20   04               bra    nqui12
                     
  0249 C6   10       nqui08  ldb    #16       report drive not ready
  024B 1A   01               sec
                     
  024D 5D            nqui12  tstb
  024E 39                    rts
                     *
                     *   Receive character.
                     *   Returns with character in ACCA and CC set if successful
,
                     *                           CC cleared if time-out occurred
.
                     *
  024F 34   20       rchar   pshs   y
  0251 8D   5E               bsr    dlyset    go set delay
  0253 10AE 8D FDEF          ldy    odelc,pcr outer delay counter
  0258 6F   8D FDEA          clr    delcnt,pcr inner delay counter
                     
  025C F6   E000     rcha04  ldb    aciac     check if char received
  025F 57                    asrb
  0260 25   0C               bcs    rcha08    get character
                     
  0262 6A   8D FDE0          dec    delcnt,pcr decrement inner delay counter
  0266 26   F4               bne    rcha04    continue if not = 0
  0268 31   3F               leay   -1,y      decrement outer delay counter
  026A 26   F0               bne    rcha04    continue if not = 0
  026C 20   03               bra    rcha12    return with CC cleared
                     
  026E B6   E001     rcha08  lda    aciad     read char
  0271 35   A0       rcha12  puls   y,pc
                     *
                     *   Send character.
                     *   Returns with CC set if successful,
                     *                CC cleared if time-out occurred.
                     *
  0273 34   20       schar   pshs   y
  0275 8D   3A               bsr    dlyset    go set proper delay
  0277 10AE 8D FDCB          ldy    odelc,pcr outer delay counter
  027C 6F   8D FDC6          clr    delcnt,pcr inner delay counter
                     
  0280 F6   E000     scha04  ldb    aciac     check if tdr is empty
  0283 57                    asrb
  0284 57                    asrb
  0285 25   0C               bcs    scha08    OK, send char
                     
  0287 6A   8D FDBB          dec    delcnt,pcr decrement inner delay counter
  028B 26   F3               bne    scha04    continue if not = 0
  028D 31   3F               leay   -1,y      decrement outer delay counter
  028F 26   EF               bne    scha04    continue if not = 0
  0291 20   03               bra    scha12    return with CC cleared
                     
  0293 B7   E001     scha08  sta    aciad     send char
  0296 35   A0       scha12  puls   y,pc
                     *
                     *   Delay routine (for "slow PC")
                     *
  0298 5F            delay   clrb
  0299 34   04               pshs   b
  029B C6   32               ldb    #50       change if needed
  029D 6A   E4       dela04  dec    0,s
  029F 26   FC               bne    dela04
  02A1 5A                    decb
  02A2 26   F9               bne    dela04
  02A4 35   84               puls   b,pc
                     *
                     *  ACIA reset routine
                     *
  02A6 86   03       reset   lda    #$03      ACIA master reset
  02A8 B7   E000             sta    aciac
  02AB 86   15               lda    #$15      8 bits, 1 stop, clk/16
  02AD B7   E000             sta    aciac
  02B0 39                    rts
                     *
                     *  Delay set routine
                     *  Sets the content of "odelc" as a function of
                     *  the drive type; destroys y and b
                     *
  02B1 108E 0064     dlyset  ldy    #100      default value
  02B5 E6   8D FD7A          ldab   drvltr,pcr get drive letter
  02B9 C1   40               cmpb   #$40      is it floppy?
  02BB 26   04               bne    dlexit    no, don't change
  02BD 108E FFFF             ldy    #65535    select longer delay
  02C1 10AF 8D FD81  dlexit  sty    odelc,pcr
  02C6 39                    rts
                     
                     
               02C7  drvend  equ    *         end of driver package
                     *
                     * ---------------------------------------------------------
------
                     *
                     *   FLEX equates
                     *
               CD03  warms   equ    $cd03     FLEX warm start
               CD1E  pstrng  equ    $cd1e     write string to display
               CD24  pcrlf   equ    $cd24     write cr/lf to display
               CD18  putchr  equ    $cd18     write character to display
               CD42  gethex  equ    $cd42     get hex number
                     *
               CC2B  memend  equ    $cc2b     FLEX end of user RAM
               DE00  drvtbl  equ    $de00     start of FLEX driver jump table
                     *
                     *   Misc equates
                     *
               0006  ack     equ    $06       acknowledge character
               0015  nak     equ    $15       negative acknowledge
                     
               0045  tmp     equ    lstdrv    re-use for temp storage
               0044  tries   equ    cnt       re-use for number of tries
                     *
                     * ---------------------------------------------------------
------
                     *
                     *   The following code will be dropped after a successful
                     *   line synchronization and relocation of the driver routi
nes.
                     *
                     * ---------------------------------------------------------
------
                     *
  C100                       org    $c100
                     *
                     *   New jump address table
                     *
  C100 0049          newtbl  fdb    nread     read single sector
  C102 0103                  fdb    nwrite    write single sector
  C104 01D0                  fdb    nverfy    verify write operation
  C106 01EA                  fdb    nrestr    restore head to track# 00
  C108 01FE                  fdb    ndrsel    drive select
  C10A 0212                  fdb    ncheck    check drive ready
  C10C 0226                  fdb    nquick    quick check drive ready
                     
                     *---------------------------------------------------------
                     *
                     *   Start of installer program
                     *
                     *
                     *---------------------------------------------------------
                     
  C10E 20   02       start   bra    init
  C110 04 01         versn   fcb    4,1       version number
                     
  C112 4F            init    clra             reset DP register
  C113 1F   8B               tfr    a,dp      (just in case...)
                     
                     *
                     * Display greeting message and version number
                     *
  C115 8E   C23A             ldx    #greet    point to string
  C118 FC   C110             ldd    versn     get version number
  C11B C3   3030             addd   #$3030    make ASCII
  C11E B7   C251             staa   v1
  C121 F7   C253             stab   v1+2
  C124 BD   CD1E             jsr    pstrng    go print string
                     *
                     * Scan memory from MEMEMD to $C000 to find
                     * out if a copy of FLEXNet is already loaded
                     *
  C127 BE   CC2B     search  ldx    memend    start of search
  C12A 30   01       sear2   leax   1,x       Bump pointer
  C12C 8C   C000             cpx    #$c000    Finished?
  C12F 27   15               beq    sear4     Yes, not found
  C131 108E 0015             ldy    #sgnst    Point to target string
  C135 5F                    clrb             Reset byte counter
  C136 A6   85       sear3   ldaa   b,x       Get byte from RAM
  C138 A1   A5               cmpa   b,y       Same as signature?
  C13A 26   EE               bne    sear2     No, bump and restart
  C13C 5C                    incb             Point to next byte
  C13D C1   08               cmpb   #len      Finished?
  C13F 26   F5               bne    sear3     No, check next byte
                     *
                     * string found, already in memory; tell user
                     *
  C141 8E   C2B6             ldx    #alread   already loaded...
  C144 20   4F               bra    sync17    display then exit
                     *
                     * Search done and no match found;
                     * initialize FLEXNet and go!
                     *
               C146  sear4   equ    *
                     
                     * Get drive number from user
                     
  C146 BD   CD42             jsr    gethex    get hex number
  C149 25   15               bcs    nonum     skip if not valid
  C14B 5D                    tstb
  C14C 27   12               beq    nonum
  C14E 1F   10               tfr    x,d       transfer number to d
  C150 C4   03               andb   #$03      limit to 3
                     
  C152 34   10               pshs   x
  C154 30   8D 3EDF          leax   netdrv,pcr
  C158 30   85               leax   b,x
  C15A E7   84               stab   0,x       store in target drive #
                     
                     *       stab    netdrv          store in target drive #
                     
  C15C 35   10               puls   x
                     
  C15E 20   E6               bra    sear4     allow multiple drives
                     
               C160  nonum   equ    *
                     *
                     *   Initialize ACIA.
                     *
                     
                     * This file is the only one which must be
                     * system-dependent (i.e. it must be edited
                     * to match the address of your serial port).
                     
                     * Adaptation for Mike's system:
                     *
                     *   ACIA on port #0
                     
               0000  port    equ    0
               E000  BOARD   EQU    16*port+$E000
                     
               E000  aciac   EQU    BOARD     ACIA CONTROL REGISTER
               E001  aciad   EQU    aciac+1   ACIA DATA REGISTER
                     
                     *
  C160 BD   02A6             jsr    reset     call the ACIA reset routine
                     
                     * default to short delay (i.e. hard disk)
                     *
  C163 8E   4000             ldx    #$4000
  C166 9F   47               stx    odelc
                     
                     *   Check if host is ready; "sync" with $55
                     *   and then $aa. This will verify that 8 bits
                     *   are transferred correctly.
                     *
  C168 86   05       sync    lda    #5        number of tries
  C16A 97   44               sta    tries
  C16C 86   55               lda    #$55      1:st sync char
  C16E 97   45       sync04  sta    tmp
                     
  C170 17   4100     sync08  lbsr   schar     send char
  C173 24   1D               bcc    sync16    time out, report error
                     
  C175 17   40D7             lbsr   rchar     get answer from receiver
  C178 24   18               bcc    sync16
  C17A 91   45               cmpa   tmp       same as sent?
  C17C 27   0C               beq    sync12    yes
                     
  C17E 96   45               lda    tmp
  C180 81   55               cmpa   #$55      1:st sync char?
  C182 26   0E               bne    sync16    nope, something is wrong
                     
  C184 0A   44               dec    tries     decrease try count
  C186 26   E8               bne    sync08    try again if not 0
  C188 20   08               bra    sync16    report sync error
                     
  C18A 81   AA       sync12  cmpa   #$aa      2:nd sync char?
  C18C 27   0D               beq    sync20    yes, continue
                     
  C18E 86   AA               lda    #$aa      send 2:nd sync char
  C190 20   DC               bra    sync04
                     
  C192 8E   C255     sync16  ldx    #synstr   "Can't sync..."
  C195 BD   CD1E     sync17  jsr    pstrng
  C198 7E   CD03             jmp    warms     back to FLEX
                     *
  C19B 8E   C271     sync20  ldx    #scnest   "Serial connection established"
  C19E BD   CD1E             jsr    pstrng
                     
                     *
                     *   Now do a "Where am I" command
                     *
  C1A1 86   3F               ldaa   #'?
  C1A3 17   40CD             lbsr   schar
  C1A6 24   EA               bcc    sync16
                     
                     *
                     *   Receive the current drive and folder string,
                     *   and keep the first letter, with some processing:
                     *   @ if floppy, other if hard disk
                     *
  C1A8 17   40A4             lbsr   rchar
  C1AB 24   E5               bcc    sync16    exit if time-out
  C1AD 34   02               pshs   a         save character
  C1AF 80   01               suba   #1        A/B becomes @/A
  C1B1 84   5E               anda   #$5E      make upper case
  C1B3 97   33               staa   drvltr    store it as @ if floppy
  C1B5 81   40               cmpa   #$40      is it floppy?
  C1B7 26   05               bne    wtack     no, leave as-is
  C1B9 8E   FFFF             ldx    #$FFFF    set long delay
  C1BC 9F   47               stx    odelc     store it
                     *
                     *   receive all other characters and discard them
                     *   until the final ACK is received
                     *
  C1BE 17   408E     wtack   lbsr   rchar
  C1C1 24   CF               bcc    sync16
  C1C3 81   06               cmpa   #ack
  C1C5 26   F7               bne    wtack
                     *
                     *   Inform user about the current drive
                     *
  C1C7 8E   C2E2             ldx    #drvmsg   point to string
  C1CA BD   CD1E             jsr    pstrng    print it
  C1CD 35   02               puls   a         retrieve original char
  C1CF 84   5F               anda   #$5f      make upper case
  C1D1 BD   CD18             jsr    putchr    print it
  C1D4 86   3A               LDAA   #':       ... then print ":"
  C1D6 BD   CD18             jsr    putchr
                     *
                     *   Copy FLEX driver jump table to new location
                     *
  C1D9 C6   15               ldb    #7*3      number of bytes to move
  C1DB 8E   DE00             ldx    #$de00    start of FLEX table
  C1DE 108E 0000             ldy    #$0000    new location
                     
  C1E2 A6   80       movtbl  lda    ,x+       read byte and move pointer
  C1E4 A7   A0               sta    ,y+       store and move pointer
  C1E6 5A                    decb             decrement byte counter
  C1E7 26   F9               bne    movtbl
                     *
                     *   Move package to below current [MEMEND]
                     *
  C1E9 86   55               ldaa   #$55      Point to a dummy drive number...
  C1EB 97   45               staa   lstdrv    ... so that 'net drive'is not sele
cted
                     *
  C1ED FC   CC2B             ldd    memend    make room for package
  C1F0 83   02C7             subd   #drvend   end of package = byte count
  C1F3 FD   CC2B             std    memend
                     
  C1F6 1F   01               tfr    d,x       target pointer
  C1F8 108E 0000             ldy    #$0000    start of package
                     
  C1FC A6   A0       movpkg  lda    ,y+       get one byte and move pointer
  C1FE A7   80               sta    ,x+       store and move target pointer
  C200 108C 02C7             cmpy   #drvend   end of package?
  C204 25   F6               blo    movpkg    no, continue
                     *
                     *   Set new addresses in FLEX jump table
                     *
  C206 8E   DE01             ldx    #$de01    target pointer
  C209 108E C100             ldy    #newtbl   table of new jump addresses
  C20D 86   07               lda    #7        number of addresses to move
  C20F 97   44               sta    tries
                     
  C211 EC   A1       movadr  ldd    ,y++      get address and move pointer
  C213 F3   CC2B             addd   memend    add offset to address
  C216 ED   84               std    0,x       store at target
  C218 30   03               leax   3,x       move target pointer
  C21A 0A   44               dec    tries     decrement address counter
  C21C 26   F3               bne    movadr
                     
  C21E FC   CC2B             ldd    memend    make sure memend points to free me
m location
  C221 83   0001             subd   #$0001
  C224 FD   CC2B             std    memend
                     
  C227 8E   C28F             ldx    #instst   "Remote .DSK ...
  C22A BD   CD1E             jsr    pstrng
  C22D 96   37               lda    netdrv    get 'net drive'#
  C22F 8B   30               adda   #$30      make ASCII
  C231 BD   CD18             jsr    putchr
  C234 BD   CD24             jsr    pcrlf
  C237 7E   CD03             jmp    warms
                     *
                     * Messages to the user
                     *
  C23A 46 4C 45 58   greet   fcc    /FLEXNet driver version /
  C23E 4E 65 74 20   
  C242 64 72 69 76   
  C246 65 72 20 76   
  C24A 65 72 73 69   
  C24E 6F 6E 20      
  C251 00 2E 00 04   v1      fcb    0,'.,0,4
  C255 43 61 6E 27   synstr  fcc    /Can't sync serial transfer!/,4
  C259 74 20 73 79   
  C25D 6E 63 20 73   
  C261 65 72 69 61   
  C265 6C 20 74 72   
  C269 61 6E 73 66   
  C26D 65 72 21 04   
  C271 53 65 72 69   scnest  fcc    /Serial connection established/,4
  C275 61 6C 20 63   
  C279 6F 6E 6E 65   
  C27D 63 74 69 6F   
  C281 6E 20 65 73   
  C285 74 61 62 6C   
  C289 69 73 68 65   
  C28D 64 04         
  C28F 52 65 6D 6F   instst  fcc    /Remote .DSK drive installed as drive #/,4
  C293 74 65 20 2E   
  C297 44 53 4B 20   
  C29B 64 72 69 76   
  C29F 65 20 69 6E   
  C2A3 73 74 61 6C   
  C2A7 6C 65 64 20   
  C2AB 61 73 20 64   
  C2AF 72 69 76 65   
  C2B3 20 23 04      
  C2B6 46 4C 45 58   alread  fcc    /FLEXNet is already loaded, no action taken.
/,4
  C2BA 4E 65 74 20   
  C2BE 69 73 20 61   
  C2C2 6C 72 65 61   
  C2C6 64 79 20 6C   
  C2CA 6F 61 64 65   
  C2CE 64 2C 20 6E   
  C2D2 6F 20 61 63   
  C2D6 74 69 6F 6E   
  C2DA 20 74 61 6B   
  C2DE 65 6E 2E 04   
  C2E2 43 75 72 72   drvmsg  fcc    /Current MS-DOS drive is /,4
  C2E6 65 6E 74 20   
  C2EA 4D 53 2D 44   
  C2EE 4F 53 20 64   
  C2F2 72 69 76 65   
  C2F6 20 69 73 20   
  C2FA 04            
                     *
                             end    start

0 ERROR(S) DETECTED

SYMBOL TABLE:

BOARD  E000   aciac  E000   aciad  E001   ack    0006   alread C2B6   
chksum 0042   cnt    0044   curdrv 003F   curtrk 0040   dela04 029D   
delay  0298   delcnt 0046   dlexit 02C1   dlyset 02B1   drvend 02C7   
drvltr 0033   drvmsg C2E2   drvtbl DE00   fcheck 000F   fdrive 000C   
fquick 0012   fread  0000   frestr 0009   fverfy 0006   fwrite 0003   
gethex CD42   greet  C23A   init   C112   instst C28F   len    0008   
lstdrv 0045   memend CC2B   movadr C211   movpkg C1FC   movtbl C1E2   
nak    0015   ncheck 0212   ndrsel 01FE   netdrv 0037   newtbl C100   
nonum  C160   nqchk1 008D   nqchk2 0155   nqui04 0238   nqui08 0249   
nqui12 024D   nquick 0226   nrea04 00B4   nrea08 00C7   nrea10 00EE   
nrea12 00F2   nrea16 00FB   nread  0049   nrestr 01EA   ntslw1 009C   
ntslw2 0165   nverfy 01D0   nwri04 0189   nwri08 019E   nwri10 01C2   
nwri12 01C6   nwri16 01C8   nwrite 0103   odelc  0047   pcrlf  CD24   
port   0000   pstrng CD1E   putchr CD18   qcheck 003B   rcha04 025C   
rcha08 026E   rcha12 0271   rchar  024F   reset  02A6   scha04 0280   
scha08 0293   scha12 0296   schar  0273   scnest C271   sear2  C12A   
sear3  C136   sear4  C146   search C127   sgnst  0015   size   003D   
slowpc 003C   start  C10E   sync   C168   sync04 C16E   sync08 C170   
sync12 C18A   sync16 C192   sync17 C195   sync20 C19B   synstr C255   
tmp    0045   tries  0044   v1     C251   versn  C110   warms  CD03   
wtack  C1BE   




