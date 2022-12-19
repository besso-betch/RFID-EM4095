UART_ISR:
	push	psw
	push	acc
	
	setb RS0 ; Select Registerbank #1
	jb  ti, xmit             
        clr ri
      
        mov a, sbuf        
        cjne byteCtr, #1, SOHkontrollieren        
        sjmp DatenEmpfangen ;Letztes Byte ohne SOH Kontrolle passieren

        SOHkontrollieren:
        cjne A, #soh, DatenEmpfangen               
        lcall PrepareDataReception    ;Datenempfang vorbereiten   
        pop	acc
	pop	psw
	RETI

DatenEmpfangen:    
        djnz byteCtr, SaveData        
        mov @R0, A  ;letztes Byte(Prüfsumme)
        ;Abschlussroutine  
        
        ;Prüfsumme berechnen
        mov R0, #inBuf+0
        clr A
        mov byteCtr, #inBufCount

        AddNextByte:
        add A, @R0
        inc R0
        djnz byteCtr, AddNextByte
       
        jnz SendNAK           
        ;Hier inBuf nach msgRam kopieren        
        mov byteCtr, #40          
        mov R0, #inBuf+0        
        mov R1, #msgRam+0
        
        CopyNextToMsgRam:
        clr c         
        mov A, @R0        
        subb A, #48
        mov @R1, A  
        inc R0
        inc R1
        djnz byteCtr, CopyNextToMsgRam      
        ;lcall Display     
                  
        mov sendBuf+0, #ACK          
        sjmp SendAnswer

        SendNAK:   
        mov sendBuf+0, #NAK           

        SendAnswer:   
        lcall GetSendBuf
        setb ti 
        pop	acc
	pop	psw
	RETI

SaveData :
        mov @R0, A        
        inc R0
	pop	acc
	pop	psw
	RETI


;;;;;;;;;;;;;;;;;;;;,,
xmit:
clr ti
;djnz byteCtr, SendNextByte
;lcall PrepareDataReception
pop acc
pop psw
RETI


;xmit:
;clr ti
;djnz byteCtr, SendNextByte
;lcall PrepareDataReception
;pop acc
;pop psw
;RETI

SendNextByte:
mov sbuf, @R0
inc R0
pop acc
pop psw
RETI


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GetSendBuf:

mov R0, #sendBuf+0
mov byteCtr, #2

RET


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PrepareDataReception:
mov R0, #inBuf+0
mov byteCtr, #inBufCount
PrepareDataReception_1:
mov @R0, #0
inc R0
djnz byteCtr, PrepareDataReception_1
mov R0, #inBuf+0
mov byteCtr, #inBufCount
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init_uart_intr:
        mov scon, #01010000b        ;config serial port (ri and ti cleared)        
        mov RCAP2L, #0D9h ;(@9600bps AND @12MHZ RCAP2L=D9; @11MHZ RCAP2L=DC)
        mov RCAP2H, #0FFh
        mov T2CON, #34h      
RET