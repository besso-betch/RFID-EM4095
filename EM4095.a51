$nomod51
$include (89S8253.mcu)
$include (ascii.a51)

KartenAnzahl EQU 250

EEMEN EQU 00001000b
EEMWE EQU 00010000b
DPS EQU 00000100b
EELD EQU 00100000b

TasterAdmin bit P3.6
TasterErase bit P3.7

ledGreen bit P1.0
ledRed bit P1.1
ledBlue bit P1.2

Pipser bit P2.7
Relais bit P2.6
RelaisTimeJumper bit P3.5

MOD_ bit P2.3
SHD bit P2.4
DEMOD bit P3.2
;RDY_CLK bit P3.4

inBufCount EQU 41
byteCtr EQU R3 ;wird in Empfangsroutine verwendet(uart.a51)
;byteCtrTest EQU R4

;R2 und R3 ist algemeiner djnz Hilfsvariable
;R3 is bitCounter

bitCtr EQU R4
bitCtr2 EQU R5
CtrEm4102Row EQU R6
Em4102ReadTrys EQU R7

;Variablen Deklaration
DSEG AT 48  
msgRam : DS 32   ;Erstes Byte(msgRam+0) ist KommandoByte in ASCII

_50Hz_TeilerT1 : DS 1
_2Hz_TeilerT1 : DS 1
_1Hz_TeilerT1 : DS 1
_02Hz_TeilerT1 : DS 1

sendBuf : DS 7
LastCard : DS 4
CurrCard : DS 4
Em4102Rows : DS 11
CtrCardOk : DS 1

BSEG AT 0 
_50HzT1 : DBIT 1
_2HzT1 : DBIT 1
_1HzT1 : DBIT 1
_02HzT1 : DBIT 1

Make : DBIT 1
CardSame : DBIT 1
MasterCardPresent : DBIT 1
CardInDB : DBIT 1
eepromFull : DBIT 1

TimeOut : DBIT 1
NormalMode : DBIT 1
ManchesterInverted : DBIT 1
CardPresent : DBIT 1

CaptureState EQU 2Fh ; Ganz oben auf dem Bitbereich
;CaptureState.0 = Header bits (Capture begin)
;CaptureState.1 = Customer ID bits
;CaptureState.2 = Data bits
;CaptureState.3 = Column parity bits
;CaptureState.4 = Capture ended
;CaptureState.5 = Capture Result

ISEG AT 128
inBuf : DS 41

STACK : DS 1

CSEG AT RESET
LJMP Startup    

ORG EXTI0
LJMP EXTI0_ISR

ORG TIMER0
LJMP TIMER0_ISR

ORG EXTI1
LJMP EXTI1_ISR

ORG TIMER1
LJMP TIMER1_ISR

ORG SINT 
LJMP uart_isr

ORG TIMER2
RETI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
EXTI0_ISR:
clr EX0
clr TR0
mov TL0, #240
mov TH0, #224
mov CaptureState, #1     ;setb SyncFlag
setb TR0
EXTI0_ISR_EXIT:
RETI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;
EXTI1_ISR:
RETI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

TIMER0_ISR: ;Timer 0 Interrupt

jnb CaptureState.0, CheckCaptureState2     ;Quasi 1 Startbit
jb Demod, TIMER0_ISR_EXIT_Error
mov bitCtr, #16
mov CaptureState, #2
setb ManchesterInverted
RETI 

CheckCaptureState2:
jnb CaptureState.1, CheckCaptureState4     ;8 Header Bits
jnb ManchesterInverted, CheckManchesterInverted
clr ManchesterInverted
jnb Demod, TIMER0_ISR_EXIT_Error
sjmp CheckBitCounter

CheckManchesterInverted:
setb ManchesterInverted
jb Demod, TIMER0_ISR_EXIT_Error

CheckBitCounter:
djnz bitCtr, TIMER0_ISR_EXIT
mov CaptureState,#4
setb ManchesterInverted
mov bitCtr, #10
mov CtrEm4102Row, #10
mov R0, #Em4102Rows+0
RETI 


CheckCaptureState4:         ;Customer Id
jnb CaptureState.2, CheckCaptureState8
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
jnb ManchesterInverted, CheckManchesterInverted1
clr ManchesterInverted
mov C, Demod
rrc A
sjmp CheckBitCounter1

CheckManchesterInverted1:
setb ManchesterInverted
;do nothing here

CheckBitCounter1:
djnz bitCtr, TIMER0_ISR_EXIT
rr A
rr A
rr A
mov C, ACC.4    ;Parity
anl A, #00001111b
jnc CheckPis0 
jnb p, err 
sjmp RowCaptured

CheckPis0:
jb p, err 
sjmp RowCaptured 

err:
clr TR0
mov CaptureState,#00010000b ;Capture ended with error
RETI

RowCaptured:
mov @R0, A
inc R0
djnz CtrEm4102Row, Reinit1
mov CaptureState,#8
mov bitCtr, #10
setb ManchesterInverted
RETI

Reinit1:
mov bitCtr, #10
RETI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckCaptureState8:         ;Data bits
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
jnb ManchesterInverted, CheckManchesterInverted2
clr ManchesterInverted
mov C, Demod
rrc A
sjmp CheckBitCounter2

CheckManchesterInverted2:
setb ManchesterInverted
;do nothing here

CheckBitCounter2:
djnz bitCtr, TIMER0_ISR_EXIT
rr A
rr A
rr A
jb ACC.4, err
anl A, #00001111b
mov @R0, A
;5 Bits Captured

clr TR0
mov CaptureState,#00110000b ;Capture ended with success
RETI


TIMER0_ISR_EXIT_Error:
clr TR0
mov CaptureState,#00010000b ;Capture ended with error

TIMER0_ISR_EXIT:
RETI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TIMER1_ISR: ;Timer 1 Interrupt
djnz _50Hz_TeilerT1, TIMER1_ISR_EXIT
mov _50Hz_TeilerT1, #200
setb _50HzT1

djnz _2Hz_TeilerT1, TIMER1_ISR_EXIT
mov _2Hz_TeilerT1, #25
setb _2HzT1 
jb NormalMode, NormalModeLabel
cpl ledBlue 

NormalModeLabel:
djnz _1Hz_TeilerT1, TIMER1_ISR_EXIT
mov _1Hz_TeilerT1, #2
setb _1HzT1 

djnz _02Hz_TeilerT1, TIMER1_ISR_EXIT
mov _02Hz_TeilerT1, #5
setb _02HzT1   
jb Relais, SetBitTimeOut
setb Relais
clr ledGreen
setb ledBlue
RETI

SetBitTimeOut:
setb TimeOut  ;For Add Cards Mode


TIMER1_ISR_EXIT:
RETI

ORG RESET + 200H 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
$include (uart.a51)
$include (time.a51)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                     
startup: 
mov SP, #Stack 
orl WDTCON, #11100000b ;2 sec
orl WDTCON, #00000100b ;enable hardware watchdog  
mov WDTRST, #01Eh
mov WDTRST, #0E1h; Watchdog enabled 

mov _50Hz_TeilerT1, #200
clr  _50HzT1 
mov _2Hz_TeilerT1, #25
clr  _2HzT1 
mov _1Hz_TeilerT1, #2
clr  _1HzT1 
mov _02Hz_TeilerT1, #5
clr  _02HzT1 

lcall PrepareDataReception 
lcall init_uart_intr
 mov TL1, #9Ch
 mov TH1, #9Ch
 mov TMOD, #00100110b  ;T1=Autoreload; and T0=Autoreload
 mov IP, #00010000b ;Prioritaet fuer Serial Port
;IE REGISTER
setb ET0
setb ET1
setb ES
setb EA
;mov IE, #10011010b  ;EA, ES, T1, T0 Interrupt freigeben
;;;;;;;;;;;;;;;;;;;;;;;;;;; 

;TCON REGISTER
setb IT0
setb TR1
;;;;;;;;;;;;;;;;

orl eecon, #eemen ;eeprom einschalten 

mov LastCard+0, #0FFh
mov LastCard+1, #0FFh
mov LastCard+2, #0FFh
mov LastCard+3, #0FFh

clr CardSame
clr MasterCardPresent
lcall Em4095SetUp

clr ledRed
clr ledGreen
clr ledBlue

setb NormalMode
;ljmp  LoopNormalMode

jb TasterAdmin, CheckTasteErase
clr pipser
clr ledBlue
mov A, #50
lcall F_wait_m
setb pipser
mov A, #50
lcall F_wait_m
clr pipser 
mov A, #50
lcall F_wait_m
setb pipser
LJMP LoopProgAdminMode

CheckTasteErase:
jb TasterErase, LoopNormalModePre
clr pipser
clr ledBlue
mov A, #50
lcall F_wait_m
setb pipser
mov A, #50
lcall F_wait_m
clr pipser 
mov A, #50
lcall F_wait_m
setb pipser
LJMP EraseEeprom
;*****************************************************************************
;H A U P T P R O G R A M
;*****************************************************************************
LoopNormalModePre:
setb ledBlue

LoopNormalMode:
jnb _50HzT1, LoopNormalMode
clr _50HzT1

mov WDTRST, #01Eh
mov WDTRST, #0E1h
lcall ReadEM
jnb CardPresent, LoopNormalMode

;mov sbuf, CurrCard+0
;mov A, #10
;lcall F_wait_m

;mov sbuf, CurrCard+1
;mov A, #10
;lcall F_wait_m

;mov sbuf, CurrCard+2
;mov A, #10
;lcall F_wait_m

;mov sbuf, CurrCard+3
;mov A, #10
;lcall F_wait_m


;ljmp LoopNormalMode
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
lcall LastCardCheck
jnb CardSame, CheckFirstMasterCard      ;SameCard
ljmp LoopNormalMode


CheckFirstMasterCard:
lcall MasterCardCheck
jnb MasterCardPresent, CheckNormal
ljmp LoopProgAddDelMode

CheckNormal:
lcall LookUpCardInDB
jnb CardInDB, CardNotInDB     
clr Relais                   ;CardInDb
clr pipser
clr ledBlue
setb LedGreen
mov A, #50
lcall F_wait_m 
jnb RelaisTimeJumper, LoadCloseTime5Sec
mov _02Hz_TeilerT1, #2
ljmp LoadCloseTime1SecLoaded
LoadCloseTime5Sec:
mov _02Hz_TeilerT1, #5
LoadCloseTime1SecLoaded:
setb pipser
LJMP LoopNormalMode

CardNotInDB:     ;CardNotInDb
clr ledBlue
clr pipser
setb LedRed
mov A, #50
lcall F_wait_m 
setb pipser
clr LedRed
mov A, #50
lcall F_wait_m 
clr pipser
setb LedRed
mov A, #50
lcall F_wait_m 
setb pipser
clr LedRed
setb LedBlue
LJMP LoopNormalMode


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoopProgAddDelMode:
clr NormalMode
setb Relais
clr ledBlue
clr Pipser
mov A, #255
lcall F_wait_m
setb Pipser
clr ledRed

orl eecon, #eemwe ;schreiben freigeben

mov _02Hz_TeilerT1, #10
clr TimeOut

LoopProgAddDelMode1:
jnb _50HzT1, LoopProgAddDelMode1
clr _50HzT1
mov WDTRST, #01Eh
mov WDTRST, #0E1h

jb TimeOut, ContinueAddDelExit 
lcall ReadEm
jnb CardPresent, LoopProgAddDelMode1 
mov _02Hz_TeilerT1, #10  ;Timeout verhindern

lcall LastCardCheck  ;Hier adden oder deleten
jb CardSame, LoopProgAddDelMode1

lcall MasterCardCheck
jnb MasterCardPresent, ContinueAddDel
ContinueAddDelExit: 
xrl eecon, #eemwe  ;schreiben sperren 
clr Pipser
clr ledBlue
mov A, #255
lcall F_wait_m
setb Pipser
setb ledBlue
setb NormalMode
ljmp LoopNormalMode  ;Dieses Loop verlasssen

ContinueAddDel:
lcall LookUpCardInDB
jb CardInDB, DeleteCard
;Add Cards here
lcall GetFreePlace
jnb eepromFull, RegisterCard
setb ledRed
setb ledGreen
clr Pipser
mov A, #255
lcall F_wait_m
clr ledRed
clr ledGreen
setb Pipser
ljmp  LoopProgAddDelMode1


RegisterCard:
clr TR1
clr ledBlue
clr Pipser
setb ledGreen

;mov dptr, #0 ;eepromadresse
mov A, #0 ; 4 Byte belegt kennzeichen
movx @dptr, A
mov A, #10
lcall F_wait_m 

inc dptr
mov A, CurrCard+0 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 

inc dptr
mov A, CurrCard+1 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 

inc dptr
mov A, CurrCard+2 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 

inc dptr
mov A, CurrCard+3 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 

mov A, #50
lcall F_wait_m 

setb Pipser


mov A, #255
lcall F_wait_m 
clr ledGreen
setb TR1
 
LJMP  LoopProgAddDelMode1

;;;;;;;;;;
DeleteCard:
clr TR1
clr ledBlue
clr Pipser
setb ledRed

;mov dptr, #0 ;eepromadresse
mov A, #0FFh ; date zum schreiben
movx @dptr, A
mov A, #100
lcall F_wait_m 
setb Pipser


mov A, #255
lcall F_wait_m 
clr ledRed
setb TR1

LJMP  LoopProgAddDelMode1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoopProgAdminMode:
mov WDTRST, #01Eh
mov WDTRST, #0E1h

lcall ReadEm
jnb CardPresent, LoopProgAdminMode

clr Pipser
orl eecon, #eemwe ;schreiben freigeben

mov dptr, #0 ;eepromadresse
mov A, #0 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 

mov dptr, #1 ;eepromadresse
mov A, CurrCard+0 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 

mov dptr, #2 ;eepromadresse
mov A, CurrCard+1 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 

mov dptr, #3 ;eepromadresse
mov A, CurrCard+2 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 

mov dptr, #4 ;eepromadresse
mov A, CurrCard+3 ; date zum schreiben
movx @dptr, A
mov A, #10
lcall F_wait_m 
 
xrl eecon, #eemwe  ;schreiben sperren 
setb Pipser

BlinkInLoopProgAdminMode:
cpl LedRed
mov A, #50
lcall F_wait_m
mov WDTRST, #01Eh
mov WDTRST, #0E1h; Watchdog enabled 
LJMP BlinkInLoopProgAdminMode

;LJMP LoopNormalMode
;*****************************************************************************
;H A U P T P R O G R A M   E N D E
;*****************************************************************************
LastCardCheck:
mov A, LastCard+0
cjne A, CurrCard+0, LastCardCheckExit
mov A, LastCard+1
cjne A, CurrCard+1, LastCardCheckExit
mov A, LastCard+2
cjne A, CurrCard+2, LastCardCheckExit
mov A, LastCard+3
cjne A, CurrCard+3, LastCardCheckExit
setb CardSame
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LastCardCheckExit:
mov LastCard+0, CurrCard+0
mov LastCard+1, CurrCard+1
mov LastCard+2, CurrCard+2
mov LastCard+3, CurrCard+3
clr CardSame
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MasterCardCheck:
mov DPTR, #1
movx A, @DPTR
cjne A, CurrCard+0, MasterCardCheckExit

mov DPTR, #2
movx A, @DPTR
cjne A, CurrCard+1, MasterCardCheckExit

mov DPTR, #3
movx A, @DPTR
cjne A, CurrCard+2, MasterCardCheckExit

mov DPTR, #4
movx A, @DPTR
cjne A, CurrCard+3, MasterCardCheckExit

setb MasterCardPresent
RET

MasterCardCheckExit:
clr MasterCardPresent
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LookUpCardInDB:
clr CardInDB
mov DPTR, #0
mov R2, #KartenAnzahl

LookUpInDB:
inc DPTR
inc DPTR
inc DPTR
inc DPTR
inc DPTR
movx A, @DPTR
jz CardChecken
ContinueLookUpInDB:
;jb CardInDB, LookUpInDBExit
djnz R2, LookUpInDB

;LookUpInDBExit:
RET

CardChecken:
mov DP1L, DP0L
mov DP1H, DP0H
orl EECON, #DPS
inc DPTR
movx A, @DPTR
cjne A, CurrCard+0, CardCheckenExit
inc DPTR
movx A, @DPTR
cjne A, CurrCard+1, CardCheckenExit
inc DPTR
movx A, @DPTR
cjne A, CurrCard+2, CardCheckenExit
inc DPTR
movx A, @DPTR
cjne A, CurrCard+3, CardCheckenExit
xrl EECON, #DPS
setb CardInDB
RET
;ljmp ContinueLookUpInDB1

CardCheckenExit:
xrl EECON, #DPS
clr CardInDB
ljmp ContinueLookUpInDB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetFreePlace:
mov DPTR, #0
mov R2, #KartenAnzahl
clr eepromFull

GetFreePlace1:
inc DPTR
inc DPTR
inc DPTR
inc DPTR
inc DPTR
movx A, @DPTR
jz ContinueGetFreePlace1
RET

ContinueGetFreePlace1:
djnz R2, GetFreePlace1
setb eepromFull
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
EraseEeprom:
orl eecon,#eemwe ;write enable
mov R2, #31
mov R3, #64
mov dptr,#0

orl eecon, #eeld
mov A, #0FFh

ContunueLoadingFF:
movx @dptr, A
inc dptr
djnz R2, ContunueLoadingFF
xrl eecon, #eeld   ;Load last byte in page and program it
movx @dptr, A
mov A, #10
lcall F_wait_m
mov A, #0FFh
mov R2, #31
inc dptr
orl eecon, #eeld
djnz R3, ContunueLoadingFF 
xrl eecon, #eeld
xrl eecon, #eemwe

;NUN Pruefen
mov R2, #32
mov R3, #64
mov dptr,#0

ContunueCheckingFF:
movx A, @dptr
cjne A, #0FFh, EepromBad
inc dptr
djnz R2, ContunueCheckingFF
mov R2, #32
djnz R3, ContunueCheckingFF

EepromOK:
cpl ledGreen
mov A, #100
lcall F_wait_m
mov WDTRST, #01Eh
mov WDTRST, #0E1h
ljmp EepromOK


EepromBad:
cpl ledRed
mov A, #50
lcall F_wait_m
mov WDTRST, #01Eh
mov WDTRST, #0E1h
ljmp EepromBad


;*****************************************************************************
;EM4095   R E A D
;*****************************************************************************
ReadEM:
mov CtrCardOk, #3
clr CardPresent

ReadEM1:
mov Em4102ReadTrys, #128

ReadEM2:
djnz Em4102ReadTrys, CountinueTry
clr CardPresent
mov LastCard+0, #0FFh
mov LastCard+1, #0FFh
mov LastCard+2, #0FFh
mov LastCard+3, #0FFh
RET

CountinueTry:
clr CaptureState.4 
setb EX0
jnb CaptureState.4, $
jnb CaptureState.5, ReadEM2

mov A, Em4102Rows+0
xrl A, Em4102Rows+1 
xrl A, Em4102Rows+2 
xrl A, Em4102Rows+3 
xrl A, Em4102Rows+4 
xrl A, Em4102Rows+5 
xrl A, Em4102Rows+6 
xrl A, Em4102Rows+7 
xrl A, Em4102Rows+8 
xrl A, Em4102Rows+9
xrl A, Em4102Rows+10
jnz ReadEM2

djnz CtrCardOk, ReadEM1

;;;;;;;;;;;;;;;;;;;;;;
mov A, Em4102Rows+2
swap A
mov Em4102Rows+2, A

mov A, Em4102Rows+3
orl A, Em4102Rows+2
mov CurrCard+0, A
;;;;;;;;;;;;;;;;;;;;;;

mov A, Em4102Rows+4
swap A
mov Em4102Rows+4, A

mov A, Em4102Rows+5
orl A, Em4102Rows+4
mov CurrCard+1, A
;;;;;;;;;;;;;;;;;;;;;;

mov A, Em4102Rows+6
swap A
mov Em4102Rows+6, A

mov A, Em4102Rows+7
orl A, Em4102Rows+6
mov CurrCard+2, A
;;;;;;;;;;;;;;;;;;;;;;

mov A, Em4102Rows+8
swap A
mov Em4102Rows+8, A

mov A, Em4102Rows+9
orl A, Em4102Rows+8
mov CurrCard+3, A
;;;;;;;;;;;;;;;;;;;;;;

setb CardPresent

RET




;*****************************************************************************
;EM4095   M O D U L E   C O N F I G U R A T I O N
;*****************************************************************************
EM4095SetUp:
clr Mod_
setb shd
lcall ws35ms
clr shd
lcall ws35ms
RET




;CardMaster  : db 0A2h, 5Ch, 48h, 0AFh

; Warteschleife: 35 ms
;  Anzahl Maschinenzyklen: 35000
ws35ms:
        push PSW
        push 0
        push 1
        mov 1,#159
ws35ms_labelB1:
        mov 0,#18
ws35ms_labelB0:
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        djnz 0,ws35ms_labelB0
        djnz 1,ws35ms_labelB1
        nop
        nop
        pop 1
        pop 0
        pop PSW
        ret

END