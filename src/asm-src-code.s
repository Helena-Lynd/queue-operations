            TTL CMPE-250 Exercise 9
;****************************************************************
;This program interfaces with the user from a terminal window,
;taking commands from the keyboard to perform queue operations.
;Name:  Helena Lynd
;Date:  10/5/22
;Class:  CMPE-250
;Section:  Section 03, Wednesday 5:00-6:50 PM
;---------------------------------------------------------------
;Keil Template for KL05
;R. W. Melton
;September 13, 2020
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL05Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;****************************************************************
;EQUates

LEAST_BYTE_MASK	 EQU  0x000F

;UART0 Init Masks
TDRE_MASK	EQU		2_10000000
RDRF_MASK	EQU		2_00100000
	
;String Operations
MAX_STRING	EQU		80

;Characters
CR          EQU  0x0D
LF          EQU  0x0A
NULL        EQU  0x00
LESS_THAN_SYM	EQU	 0x3C
GREATER_THAN_SYM	EQU	0x3E
COLON_CHAR  EQU  0x3A	

; Queue management record field offsets
IN_PTR      EQU   0
OUT_PTR     EQU   4
BUF_STRT    EQU   8
BUF_PAST    EQU   12
BUF_SIZE    EQU   16
NUM_ENQD    EQU   17

; Queue structure sizes
XQ_BUF_SZ	EQU	  80  ;Transmit and Receive Queue sizes
Q_BUF_SZ    EQU   4   ;Queue contents
Q_REC_SZ    EQU   18  ;Queue management record
;---------------------------------------------------------------
;NVIC_ICER
;31-00:CLRENA=masks for HW IRQ sources;
;             read:   0 = unmasked;   1 = masked
;             write:  0 = no effect;  1 = mask
;12:UART0 IRQ mask
NVIC_ICER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_ICPR
;31-00:CLRPEND=pending status for HW IRQ sources;
;             read:   0 = not pending;  1 = pending
;             write:  0 = no effect;
;                     1 = change status to not pending
;12:UART0 IRQ pending status
NVIC_ICPR_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_IPR0-NVIC_IPR7
;2-bit priority:  00 = highest; 11 = lowest
UART0_IRQ_PRIORITY    EQU  3
NVIC_IPR_UART0_MASK   EQU (3 << UART0_PRI_POS)
NVIC_IPR_UART0_PRI_3  EQU (UART0_IRQ_PRIORITY << UART0_PRI_POS)
;---------------------------------------------------------------
;NVIC_ISER
;31-00:SETENA=masks for HW IRQ sources;
;             read:   0 = masked;     1 = unmasked
;             write:  0 = no effect;  1 = unmask
;12:UART0 IRQ mask
NVIC_ISER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
;Use provided PORT_PCR_MUX_SELECT_2_MASK
;---------------------------------------------------------------
;Port B
PORT_PCR_SET_PTB2_UART0_RX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTB1_UART0_TX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
;---------------------------------------------------------------
;SIM_SCGC4
;1->10:UART0 clock gate control (enabled)
;Use provided SIM_SCGC4_UART0_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->09:Port A clock gate control (enabled)
;Use provided SIM_SCGC5_PORTA_MASK
;---------------------------------------------------------------
;SIM_SOPT2
;01=27-26:UART0SRC=UART0 clock source select (MCGFLLCLK)
;---------------------------------------------------------------
SIM_SOPT2_UART0SRC_MCGFLLCLK  EQU  \
                                 (1 << SIM_SOPT2_UART0SRC_SHIFT)
;---------------------------------------------------------------
;SIM_SOPT5
; 0->   16:UART0 open drain enable (disabled)
; 0->   02:UART0 receive data select (UART0_RX)
;00->01-00:UART0 transmit data select source (UART0_TX)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  EQU  \
                               (SIM_SOPT5_UART0ODE_MASK :OR: \
                                SIM_SOPT5_UART0RXSRC_MASK :OR: \
                                SIM_SOPT5_UART0TXSRC_MASK)
;---------------------------------------------------------------
;UART0_BDH
;    0->  7:LIN break detect IE (disabled)
;    0->  6:RxD input active edge IE (disabled)
;    0->  5:Stop bit number select (1)
;00001->4-0:SBR[12:0] (UART0CLK / [9600 * (OSR + 1)]) 
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDH_9600  EQU  0x01
;---------------------------------------------------------------
;UART0_BDL
;26->7-0:SBR[7:0] (UART0CLK / [9600 * (OSR + 1)])
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDL_9600  EQU  0x38
;---------------------------------------------------------------
;UART0_C1
;0-->7:LOOPS=loops select (normal)
;0-->6:DOZEEN=doze enable (disabled)
;0-->5:RSRC=receiver source select (internal--no effect LOOPS=0)
;0-->4:M=9- or 8-bit mode select 
;        (1 start, 8 data [lsb first], 1 stop)
;0-->3:WAKE=receiver wakeup method select (idle)
;0-->2:IDLE=idle line type select (idle begins after start bit)
;0-->1:PE=parity enable (disabled)
;0-->0:PT=parity type (even parity--no effect PE=0)
UART0_C1_8N1  EQU  0x00
;---------------------------------------------------------------
;UART0_C2
;0-->7:TIE=transmit IE for TDRE (disabled)
;0-->6:TCIE=transmission complete IE for TC (disabled)
;0-->5:RIE=receiver IE for RDRF (disabled)
;0-->4:ILIE=idle line IE for IDLE (disabled)
;1-->3:TE=transmitter enable (enabled)
;1-->2:RE=receiver enable (enabled)
;0-->1:RWU=receiver wakeup control (normal)
;0-->0:SBK=send break (disabled, normal)
UART0_C2_T_R    EQU  (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
UART0_C2_T_RI   EQU  (UART0_C2_RIE_MASK :OR: UART0_C2_T_R)
UART0_C2_TI_RI  EQU  (UART0_C2_TIE_MASK :OR: UART0_C2_T_RI)
;---------------------------------------------------------------
;UART0_C3
;0-->7:R8T9=9th data bit for receiver (not used M=0)
;           10th data bit for transmitter (not used M10=0)
;0-->6:R9T8=9th data bit for transmitter (not used M=0)
;           10th data bit for receiver (not used M10=0)
;0-->5:TXDIR=UART_TX pin direction in single-wire mode
;            (no effect LOOPS=0)
;0-->4:TXINV=transmit data inversion (not inverted)
;0-->3:ORIE=overrun IE for OR (disabled)
;0-->2:NEIE=noise error IE for NF (disabled)
;0-->1:FEIE=framing error IE for FE (disabled)
;0-->0:PEIE=parity error IE for PF (disabled)
UART0_C3_NO_TXINV  EQU  0x00
;---------------------------------------------------------------
;UART0_C4
;    0-->  7:MAEN1=match address mode enable 1 (disabled)
;    0-->  6:MAEN2=match address mode enable 2 (disabled)
;    0-->  5:M10=10-bit mode select (not selected)
;01111-->4-0:OSR=over sampling ratio (16)
;               = 1 + OSR for 3 <= OSR <= 31
;               = 16 for 0 <= OSR <= 2 (invalid values)
UART0_C4_OSR_16           EQU  0x0F
UART0_C4_NO_MATCH_OSR_16  EQU  UART0_C4_OSR_16
;---------------------------------------------------------------
;UART0_C5
;  0-->  7:TDMAE=transmitter DMA enable (disabled)
;  0-->  6:Reserved; read-only; always 0
;  0-->  5:RDMAE=receiver full DMA enable (disabled)
;000-->4-2:Reserved; read-only; always 0
;  0-->  1:BOTHEDGE=both edge sampling (rising edge only)
;  0-->  0:RESYNCDIS=resynchronization disable (enabled)
UART0_C5_NO_DMA_SSR_SYNC  EQU  0x00
;---------------------------------------------------------------
;UART0_S1
;0-->7:TDRE=transmit data register empty flag; read-only
;0-->6:TC=transmission complete flag; read-only
;0-->5:RDRF=receive data register full flag; read-only
;1-->4:IDLE=idle line flag; write 1 to clear (clear)
;1-->3:OR=receiver overrun flag; write 1 to clear (clear)
;1-->2:NF=noise flag; write 1 to clear (clear)
;1-->1:FE=framing error flag; write 1 to clear (clear)
;1-->0:PF=parity error flag; write 1 to clear (clear)
UART0_S1_CLEAR_FLAGS  EQU  (UART0_S1_IDLE_MASK :OR: \
                            UART0_S1_OR_MASK :OR: \
                            UART0_S1_NF_MASK :OR: \
                            UART0_S1_FE_MASK :OR: \
                            UART0_S1_PF_MASK)
;---------------------------------------------------------------
;UART0_S2
;1-->7:LBKDIF=LIN break detect interrupt flag (clear)
;             write 1 to clear
;1-->6:RXEDGIF=RxD pin active edge interrupt flag (clear)
;              write 1 to clear
;0-->5:(reserved); read-only; always 0
;0-->4:RXINV=receive data inversion (disabled)
;0-->3:RWUID=receive wake-up idle detect
;0-->2:BRK13=break character generation length (10)
;0-->1:LBKDE=LIN break detect enable (disabled)
;0-->0:RAF=receiver active flag; read-only
UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS  EQU  \
        (UART0_S2_LBKDIF_MASK :OR: UART0_S2_RXEDGIF_MASK)
;---------------------------------------------------------------
;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
            IMPORT  Startup
			IMPORT  LengthStringSB
Reset_Handler  PROC  {}
main
;---------------------------------------------------------------
;Mask interrupts
            CPSID   I
;KL05 system startup with 48-MHz system clock
            BL      Startup
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<
			BL		Init_UART0_IRQ
			CPSIE	I
			
			LDR		R0,=QBuffer				;Initializes program queue to empty
			LDR		R1,=QRecord
			MOVS	R2,#Q_BUF_SZ
			BL		InitQueue
			
			LDR		R0,=String1				;Initializes String1 to a NULL character
			MOVS	R1,#NULL
			STRB	R1,[R0,#0]
			
CodeSearch	LDR		R0,=prompt				;Prints prompt string
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			BL		GetChar
			CMP		R0, #0x61		;If Uppercase convert to lowercase
			BMI		ToLower
			MOVS	R1,R0
BackIn		CMP		R0, #'d'
			BEQ		Output
			CMP		R0, #'e'   
			BEQ		Output
			CMP		R0, #'h'
			BEQ		Output
			CMP		R0, #'p'
			BEQ		Output
			CMP		R0,#'s'
			BEQ		Output
			B		CodeSearch
			
ToLower		MOVS	R1,R0
			ADDS	R0,R0, #0x20
			B		BackIn
			
ToUpper		SUBS	R0,R0,#0x20
			B		Out2
			
Output		MOVS	R2, R0
			CMP		R1,#0x61      ;If Uppercase, print uppercase value
			BMI		ToUpper
Out2		BL		PutChar
			MOVS	R0,#CR
			BL		PutChar
			MOVS	R0,#LF
			BL		PutChar
			CMP		R2,#'d'
			BEQ		DCode
			CMP		R2,#'e'
			BEQ		ECode
			CMP		R2,#'h'
			BEQ		HCode
			CMP		R2,#'p'
			BEQ		PCode
			CMP		R2,#'s'
			BEQ		SCode


DCode		LDR		R1,=QRecord
			BL		Dequeue
			BCS		DFailure
			BL		PutChar
			MOVS	R0,#COLON_CHAR
			BL		PutChar
			B		EndDCode
			
DFailure	LDR		R0,=failure				;Prints "Failure:"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			B		EndDCode
			
EndDCode	B		StatusCode
			
			
ECode		LDR		R0,=promptEnq			;Prints "Character to enqueue:"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			BL		GetChar
			BL		PutChar
			MOVS	R2,R0
			MOVS	R0,#CR					;Prints carriage return
			BL		PutChar
			MOVS	R0,#LF					;Prints line feed
			BL		PutChar
			MOVS	R0,R2
			LDR		R1,=QRecord
			BL		Enqueue
			BCS		EFailure
			LDR		R0,=success				;Prints "Success:"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			B		EndECode
			
EFailure	LDR		R0,=failure				;Prints "Failure:"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			B		EndECode
			
EndECode	B		StatusCode			
			
			
HCode		LDR		R0,=promptHelp
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			B		EndAndLoop

			
PCode		MOVS	R0,#GREATER_THAN_SYM
			BL		PutChar
			
			LDR		R1,=QRecord
			LDRB	R2,[R1,#NUM_ENQD]
			LDR		R4,[R1,#OUT_PTR]
			LDR		R5,[R1,#BUF_PAST]
			
PLoop		CMP		R2,#0					; if NumberEnqueued > 0
			BEQ		EndPCode
			LDRB	R0,[R4,#0]				;	Get queue item at OutPointer
			BL		PutChar
			SUBS	R2,R2,#1				;	Decrement NumberEnqueued
			ADDS	R4,R4,#1				;	Increment OutPointer
			CMP		R4,R5					;	if OutPointer >= BufferPast
			BLO		PLoop
			LDR		R4,[R1,#BUF_STRT]		;		Adjust OutPointer to BufferStart
			B		PLoop
			
EndPCode	MOVS	R0,#LESS_THAN_SYM
			BL		PutChar
			B		EndAndLoop
			
			
			
SCode		LDR		R0,=status				;Prints "Status:"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			B		StatusCode

StatusCode	LDR		R0,=in					;Prints "In=0x"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			LDR		R1,=QRecord				;Prints InPointer
			LDR		R0,[R1,#IN_PTR]
			BL		PutNumHex
			LDR		R0,=out					;Prints "Out=0x"
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			LDR		R1,=QRecord				;Prints OutPointer
			LDR		R0,[R1,#OUT_PTR]
			BL		PutNumHex
			LDR		R0,=num					;Prints "Num="
			MOVS	R1,#MAX_STRING
			BL		PutStringSB
			LDR		R1,=QRecord				;Print number enqueued
			LDRB	R0,[R1,#NUM_ENQD]		
			BL		PutNumUB
			B		EndAndLoop

EndAndLoop	MOVS	R0,#CR					;Prints carriage return
			BL		PutChar
			MOVS	R0,#LF					;Prints line feed
			BL		PutChar
			B		CodeSearch
			
;>>>>>   end main program code <<<<<
;Stay here
            B       .
            ENDP
;>>>>> begin subroutine code <<<<<
Init_UART0_IRQ	PROC	{R0-R13}
;****************************************************************
; Initializes KL05 with 8N0 and 9600 baud
; Inputs : None
; Outputs : None
; Local Variables
;	R0 : Stores memory addresses
;	R1 : Stores masks
;	R2 : Stores the values at memory addresses in R0
;****************************************************************
			PUSH	{R0-R3,LR}
			
			;Init Receive Queue
			LDR		R0,=RxQBuffer
			LDR		R1,=RxQRecord
			MOVS	R2,#XQ_BUF_SZ
			BL		InitQueue
			;Init Transmit Queue
			LDR		R0,=TxQBuffer
			LDR		R1,=TxQRecord
			MOVS	R2,#XQ_BUF_SZ
			BL		InitQueue
			
														;Setting up SIM
			LDR		R0,=SIM_SOPT2							;SIM_SOPT2
			LDR		R1,=SIM_SOPT2_UART0SRC_MASK				;Want : 2_XXXX01XXXXXXXXXXXXXXXXXXXXXXXXXX
			LDR		R2,[R0,#0]
			BICS	R2,R2,R1									;Clear bit 27
			LDR		R1,=SIM_SOPT2_UART0SRC_MCGFLLCLK
			ORRS	R2,R2,R1									;Set bit 26
			STR		R2,[R0,#0]								
															;SIM_SOPT5
			LDR		R0,=SIM_SOPT5								;Want : 2_00000000000000000000000000000000
			LDR		R1,=SIM_SOPT5_UART0_EXTERN_MASK_CLEAR
			LDR		R2,[R0,#0]
			BICS	R2,R2,R1									;Clear all bits
			STR		R2,[R0,#0]
															;SIM_SCGC4
			LDR		R0,=SIM_SCGC4								;Want : 2_XXXXXXXXXXXXXXXXXXXXX0XXXXXXXXXX
			LDR		R1,=SIM_SCGC4_UART0_MASK
			LDR		R2,[R0,#0]
			ORRS	R2,R2,R1									;Set bit 10
			STR		R2,[R0,#0]
															;SIM_SCGC5
			LDR		R0,=SIM_SCGC5								;Want : 2_XXXXXXXXXXXXXXXXXXXXX0XXXXXXXXXX
			LDR		R1,=SIM_SCGC4_UART0_MASK
			LDR		R2,[R0,#0]
			ORRS	R2,R2,R1									;Set bit 10
			STR		R2,[R0,#0]
														;Setting up ports
			LDR		R0,=PORTB_PCR2							;PCR 2
			LDR		R1,=PORT_PCR_SET_PTB2_UART0_RX				;Want : 2_XXXXXXX0XXXXXXXXXXXXX010XXXXXXXX
			STR		R1,[R0,#0]
			LDR		R0,=PORTB_PCR1							;PCR 1
			LDR		R1,=PORT_PCR_SET_PTB1_UART0_TX				;Want : 2_XXXXXXX0XXXXXXXXXXXXX010XXXXXXXX
			STR		R1,[R0,#0]
														;Setting up UART0
			LDR		R0,=UART0_BASE							
			MOVS	R1,#UART0_C2_T_R						;Disable UART0
			LDRB	R2,[R0,#UART0_C2_OFFSET]
			BICS	R2,R2,R1
			STRB	R2,[R0,#UART0_C2_OFFSET]
			
			LDR 	R0,=UART0_IPR							;Set UART0 IRQ priority
			LDR 	R2,=NVIC_IPR_UART0_PRI_3
			LDR 	R3,[R0,#0]
			ORRS 	R3,R3,R2
			STR 	R3,[R0,#0]
			LDR 	R0,=NVIC_ICPR							;Clear any pending UART0 interrupts
			LDR 	R1,=NVIC_ICPR_UART0_MASK
			STR 	R1,[R0,#0]
			LDR 	R0,=NVIC_ISER							;Unmask UART0 interrupts
			LDR 	R1,=NVIC_ISER_UART0_MASK
			STR 	R1,[R0,#0]
			
			LDR		R0,=UART0_BASE
			MOVS	R1,#UART0_BDH_9600						;UART0_BDH and UART0_BDL
			STRB	R1,[R0,#UART0_BDH_OFFSET]					;Set baud rate to 9600
			MOVS	R1,#UART0_BDL_9600
			STRB	R1,[R0,#UART0_BDL_OFFSET]
			MOVS	R1,#UART0_C1_8N1						;UART0_C1
			STRB	R1,[R0,#UART0_C1_OFFSET]					;Want : 2_00X0000X
			MOVS	R1,#UART0_C3_NO_TXINV					;UART_C3
			STRB	R1,[R0,#UART0_C3_OFFSET]					;Want : 2_XXX00000
			MOVS	R1,#UART0_C4_NO_MATCH_OSR_16			;UART_C4
			STRB	R1,[R0,#UART0_C4_OFFSET]					;Want : 2_00001111
			MOVS	R1,#UART0_C5_NO_DMA_SSR_SYNC			;UART_C5
			STRB	R1,[R0,#UART0_C5_OFFSET]					;Want : 2_00000000
			MOVS	R1,#UART0_S1_CLEAR_FLAGS				;UART_S1
			STRB	R1,[R0,#UART0_S1_OFFSET]					;Clear flags
			MOVS	R1,#UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS	;UART_S2
			STRB	R1,[R0,#UART0_S2_OFFSET]									;Clear flags
			MOVS	R1,#UART0_C2_T_RI						;Enable UART0 with receive interrupts
			STRB	R1,[R0,#UART0_C2_OFFSET]
			
			POP		{R0-R3,PC}
			
			;BX		LR
			ENDP
			LTORG
;****************************************************************				
UART0_ISR	PROC	{}
;****************************************************************
; 
; Input
;	None
; Output
;	None
; Modified / Local
;	R0 : Character
;	R1 : Address of queue buffers
;	R2 : UART0_Base address
;	R3 : Value of specific register in UART0
;	R4 : Mask
;****************************************************************
			CPSID	I
			PUSH	{R4,LR}
			
			LDR		R2,=UART0_BASE
			LDRB	R3,[R2,#UART0_C2_OFFSET]    	;Loads C2
			MOVS	R4,#UART0_C2_TI_RI								
			ANDS	R3,R3,R4
			BEQ		NextISR     		           	;if (TIE in UART_C2 = 1)
			LDRB	R3,[R2,#UART0_S1_OFFSET]  		;	if (TDRE is 1)	 
			MOVS	R4,#UART0_S1_TDRE_MASK
			ANDS	R3,R3,R4						;		
			BEQ		NextISR
			LDR		R1,=TxQRecord					;		Dequeue from TxQueue
			BL		Dequeue							;		
			BCS		DisTxISR						;		if dequeue success
			STRB	R0,[R2,#UART0_D_OFFSET]			;			Write data to UART data register
			B		NextISR
DisTxISR	MOVS	R4,#UART0_C2_T_RI				;		else
			STRB	R4,[R2,#UART0_C2_OFFSET]		;			Disable transmit

NextISR		MOVS	R4,#UART0_S1_RDRF_MASK			;if (RDRF is 1)
			LDRB	R3,[R2,#UART0_S1_OFFSET]
			ANDS	R3,R3,R4						
			BEQ		EndISR
			LDRB	R0,[R2,#UART0_D_OFFSET]			;	Read from data register
			LDR		R1,=RxQRecord
			BL		Enqueue

EndISR		CPSIE	I
			POP		{R4,PC}
			ENDP
;****************************************************************
InitQueue	PROC	{R0-R14}
;****************************************************************
; Initializes the queue record structure for the empty queue buffer 
; of the given size
; Input
;	R0 : Address of queue buffer 
;	R1 : Address of queue record structure
;	R2 : Character capacity / size of queue
; Output
;	None
;****************************************************************
			PUSH	{R0-R2}

			ALIGN

			STR		R0,[R1,#IN_PTR]
			STR		R0,[R1,#OUT_PTR]
			STR		R0,[R1,#BUF_STRT]
			ADDS	R0,R0,R2
			STR		R0,[R1,#BUF_PAST]
			STRB	R2,[R1,#BUF_SIZE]
			MOVS	R0,#0
			STRB	R0,[R1,#NUM_ENQD]

			POP		{R0-R2}
			BX		LR
			ENDP
;****************************************************************
Enqueue		PROC	{R0-R14}
;****************************************************************
; Attempts to put a character in the queue. Success if the queue
; is not full, failure if it is full.
; Input
;	R0 : Character to enqueue
;	R1 : Address of queue record structure
; Output
;	PSR C Bit : Cleared on success, set on failure
; Local 
;	R2 : Number enqueued (number of elements in queue)
;	R3 : Buffer size (size of queue)
;	R4 : InPointer
;	R5 : BufferPast
;	R6 : APSR
;	R7 : APSR_C_MASK
;****************************************************************
			PUSH	{R0-R7}

			LDRB	R2,[R1,#NUM_ENQD]		; Value of NumberEnqueued
			LDRB	R3,[R1,#BUF_SIZE]		; Value of Buffer Size
			LDR		R4,[R1,#IN_PTR]			; Memory address stored in InPointer
			LDR		R5,[R1,#BUF_PAST]		; Memory address one past end of buffer
			
			CMP		R2,R3					; if NumberEnqueued < BufferSize 
			BHS		Full
			STRB	R0,[R4,#0]				;	Put new element at memory location pointed by InPointer
			ADDS	R2,R2,#1				;	Increment NumberEnqueued
			STRB	R2,[R1,#NUM_ENQD]		
			ADDS	R4,R4,#1				;	Increment InPointer
			CMP		R4,R5					;	if InPointer >= BufferPast
			BLO		SetEnqSucc				;
			LDR		R4,[R1,#BUF_STRT]		;		Adjust InPointer to start of QueueBuffer
			B		SetEnqSucc
			
			
SetEnqSucc	STR		R4,[R1,#IN_PTR]			; Store updated value of InPointer				
			MRS		R6, APSR				; Clear C flag
			LDR		R7,=APSR_C_MASK
			BICS	R6,R6,R7
			MSR		APSR, R6
			B		EndEnq
						
											; else
Full		MRS		R6, APSR				; 	Set C flag
			LDR		R7,=APSR_C_MASK	
			ORRS	R6,R6,R7
			MSR		APSR, R6
			B		EndEnq


EndEnq		POP		{R0-R7}
			BX		LR
			ENDP
;****************************************************************
Dequeue		PROC	{R1-R14}
;****************************************************************
; Attempts to get a character from the queue. Success if the
; queue is not empty, failure if it is empty.
; Input
;	R1 : Address of queue record structure
; Output
;	R0 : Dequeued character
;	PSR C Bit : Cleared on success, set on failure
; Local
;	R2 : Number enqueued (number of elements in queue)
;	R3 : Buffer size (size of queue)
;	R4 : OutPointer
;	R5 : BufferPast
;	R6 : APSR
;	R7 : APSR_C_MASK
;****************************************************************
			PUSH	{R1-R7}

			LDRB	R2,[R1,#NUM_ENQD]
			LDRB	R3,[R1,#BUF_SIZE]
			LDR		R4,[R1,#OUT_PTR]
			LDR		R5,[R1,#BUF_PAST]
			
			CMP		R2,#0					; if NumberEnqueued > 0
			BLS		Empty
			LDRB	R0,[R4,#0]				;	Get queue item at OutPointer
			SUBS	R2,R2,#1				;	Decrement NumberEnqueued
			STRB	R2,[R1,#NUM_ENQD]
			ADDS	R4,R4,#1				;	Increment OutPointer
			CMP		R4,R5					;	if OutPointer >= BufferPast
			BLO		SetDeqSucc
			LDR		R4,[R1,#BUF_STRT]		;		Adjust OutPointer to BufferStart
			B		SetDeqSucc
			
										
SetDeqSucc	STR		R4,[R1,#OUT_PTR]		; Store updated value of OutPointer
			MRS		R6, APSR				; Clear C flag
			LDR		R7,=APSR_C_MASK
			BICS	R6,R6,R7
			MSR		APSR, R6
			B		EndDeq
						
											; else
Empty		MRS		R6, APSR				; 	Set C flag
			LDR		R7,=APSR_C_MASK	
			ORRS	R6,R6,R7
			MSR		APSR, R6
			B		EndDeq

EndDeq		POP		{R1-R7}
			BX		LR
			ENDP
;****************************************************************
PutNumHex	PROC	{R0-R14}
;****************************************************************
; Prints to the terminal screen the text hexadecimal representation 
; of the unsigned word value in R0.
; Input
;	R0 : Value to convert to hex (unsigned word value)
; Output
;	None
; Local
;	R1 : Copy of value to convert
;	R2 : Number by which to shift
;	R3 : Least byte mask
;****************************************************************
			PUSH	{R0-R3,LR}

			MOVS	R1,R0
			MOVS	R2,#28
			MOVS	R3,#LEAST_BYTE_MASK
			
LoopHex		MOVS	R0,R1
			ASRS	R0,R0,R2
			ANDS	R0,R0,R3
			CMP		R0,#10
			BHS		HexCodeConv
			ADDS	R0,R0,#0x30
BackHex		BL		PutChar
			SUBS	R2,R2,#4
			CMP		R2,#0
			BEQ		EndHex
			B		LoopHex

HexCodeConv ADDS	R0,R0,#0x37
			B		BackHex

EndHex		MOVS	R0,R1
			ANDS	R0,R0,R3
			CMP		R0,#10
			BHS		HexCode2
			ADDS	R0,R0,#0x30
BackHex2	BL		PutChar
			B		EndHexConv

HexCode2    ADDS	R0,R0,#0x37
			B		BackHex2

EndHexConv	POP		{R0-R3,PC}

			ENDP
;****************************************************************
PutNumUB	PROC	{R0-R14}
;****************************************************************
; Prints to the terminal screen the text decimal representation 
; of the unsigned byte value in R0.
; Input
;	R0 : Value to convert
; Output
;	None
;****************************************************************
			PUSH	{R0,R1,LR}
			
			MOVS	R1,#LEAST_BYTE_MASK
			ANDS	R0,R0,R1
			BL		PutNumU

			POP		{R0,R1,PC}
			ENDP
;****************************************************************
GetStringSB	PROC	{R0-R14}
;****************************************************************
; Inputs a string from the terminal keyboard to memory starting at 
; the address in R0 and adds null termination. It ends terminal 
; keyboard input when the user presses the enter key.
; Input
;	R0 : Pointer to destination string
;	R1 : Buffer Capacity
; Output
;	R0 : string buffer in memory for input from user (via reference by unsigned word address)
; Local Variables:
;	R0 : GetChar Result / Current Character
;	R1 : Memory address of destination string
;	R2 : Index counter
;	R3 : Buffer Capacity
;****************************************************************

			PUSH	{R0-R3,LR}
			
			MOVS	R3,R1					;Initialize R3
			MOVS	R1,R0					;Initialize R1
			MOVS	R2,#0					;Initialize R2
			BL		GetChar					;Initialize R0
			BL		PutChar
			
StartLoop	CMP		R2,R3					;Check if index (number of characters entered) has hit buffer limit
			BEQ		BufferHit				;If it has, go to separate buffer loop
			CMP		R0,#CR					
			BEQ		EndLoop					;while(character != CR){
			STRB	R0,[R1,R2]				;	Store character, then increment pointer
			ADDS	R2,R2,#1				;	GetChar
			BL		GetChar					;}
			BL		PutChar
			B		StartLoop
			
BufferHit	CMP		R0,#CR
			BEQ		EndLoop
			BL		GetChar
			B		BufferHit

EndLoop		MOVS	R0,#NULL				;Store null character at current pointer
			STRB	R0,[R1,R2]
			MOVS	R0,#CR					;Prints carriage return
			BL		PutChar
			MOVS	R0,#LF					;Prints line feed
			BL		PutChar

			POP		{R0-R3,PC}
			ENDP
;****************************************************************
PutStringSB	PROC	{R0-R14}
;****************************************************************
; Displays a null-terminated string to the terminal screen from 
; memory starting at the address in R0
; Input
;	R0 : Pointer to source string
;	R1 : Buffer Capacity
; Output : None
; Local Variables:
;	R0 : Character to output / current character
;	R1 : Address in memory to read from
;	R2 : Index counter
;	R3 : Buffer capacity
;****************************************************************

			PUSH	{R0-R3,LR}
			
			MOVS	R3,R1					;Initialize R3
			MOVS	R1,R0					;Initialize R1
			MOVS	R2,#0					;Initialize R2
			LDRB	R0,[R1,R2]				;Initialize R0

WhileLoop	CMP		R2,R3					;Check if index (number of characters printed) has hit buffer limit
			BEQ		EndWhileLoop			;If it has, break
			CMP		R0,#NULL				;while(character != NULL){
			BEQ		EndWhileLoop			;	PutChar
			BL		PutChar					;	Read next character (increment pointer)
			ADDS	R2,R2,#1				;}
			LDRB	R0,[R1,R2]
			B		WhileLoop
EndWhileLoop

			POP		{R0-R3, PC}
			ENDP
;****************************************************************
PutNumU		PROC	{R0-R14}
;****************************************************************
; Displays the text decimal representation to the terminal
; screen of the unsigned word value in R0
; Input 
;	R0 : Unsigned word value to print
; Output : None
; Local Variables
;	R0 : Divisor (number by which to divide, 10)  / After DIVU : Quotient
;	R1 : Dividend (number to divide, input)       / After DIVU : Remainder
;	R2 : Counter 
;	R3 : ASCII code of 0
;****************************************************************
			PUSH	{R0-R3,LR}
			
			MOVS	R1,R0			;Initialize R1 to be dividend, input
			MOVS	R0,#10			;Initialize R0 to be divisor, 10
			MOVS	R2,#0			;Initialize R2
			MOVS	R3,#'0'			;Initialize R3

			CMP		R1,#0
			BEQ		IfZero
			
DivLoop		BL		DIVU			
			BEQ		IfZero
			PUSH	{R1}
			MOVS	R1,R0					; Make quotient the new dividend (number to divide) 
			MOVS	R0,#10					; Make 10 the new divisor (number by which to divide)
			ADDS	R2,R2,#1				; Increment counter
			B		DivLoop

IfZero		PUSH	{R1}
			ADDS	R2,R2,#1
			B		PrintLoop

PrintLoop	CMP		R2,#0
			BEQ		EndPrint
			POP		{R0}
			ADDS	R0,R0,R3
			BL		PutChar
			SUBS	R2,R2,#1
			B		PrintLoop
EndPrint
			
			POP		{R0-R3, PC}
			ENDP
;***************************************************************
GetChar		PROC	{R1-R13}
;***************************************************************
; Reads a single character from the terminal keyboard into R0.
; Input: None
; Output: R0: Character received
; Local Variables:
;	R1 : Receive Queue Record Structure
;***************************************************************
			PUSH	{R1,LR}
			
GetWhile	CPSID	I
			LDR		R1,=RxQRecord
			BL		Dequeue
			CPSIE	I
			BCS		GetWhile

			POP		{R1,PC}
			ENDP
;***************************************************************
PutChar		PROC	{R1-R13}
;***************************************************************
; Displays the single character from R0 to the terminal screen.
; Input: R0: Character to transmit
; Output: None
; Local Variables:
;	R1 : 
;	R2 : 
;***************************************************************
			PUSH	{R1-R2,LR}
			
PutWhile	CPSID	I
			LDR		R1,=TxQRecord
			BL		Enqueue
			CPSIE	I
			BCS		PutWhile
			
			;enable Tx Interrupt
			MOVS	R1,#UART0_C2_TI_RI
			LDR		R2,=UART0_BASE
			STRB	R1,[R2,#UART0_C2_OFFSET]
			
			POP		{R1-R2,PC}
			ENDP
;****************************************************************
DIVU		PROC	{R2-R14}
;****************************************************************
; Computes unsigned integer division
; Inputs
;	  R0 : divisor (number by which to divide)
;     R1 : dividend (number to divide)
; Outputs
;	  R0 : quotient
;	  R1 : remainder
;	  C ASPR Flag : 0 for valid result, 1 for invalid result
; Locals
;	  R3 : Temp value of quotient
;	  R4 : Holds PSR value
;	  R5 : Holds bit mask
;****************************************************************
			PUSH	{R3-R5}

			CMP		R0, #0				;if (divisor == 0) {
			BEQ		DivBy0				

			CMP		R1, #0				;} else if (dividend == 0) {
			BEQ		Div0				
										;} else {
			CMP		R1, R0				;	while (Dividend >= Divisor){
			BLO		EndEarly			;		
			MOVS	R3, #0
while		SUBS	R1,R1,R0			;		Dividend = Dividend - Divisor
			ADDS    R3,#1				;		Quotient = Quotient + 1
			CMP		R1, R0				;	}
			BHS		while				;}
			MOVS    R0, R3				;
			B		EndWhile							
										
DivBy0		MRS		R4, APSR			;Set C
			LDR		R5,=APSR_C_MASK	
			ORRS	R4,R4,R5
			MSR		APSR, R4
			B		EndSubR
			
Div0		MOVS	R0,#0				;Set outputs to 0
			MOVS	R1,#0
			MRS		R4, APSR			;Set Z
			LDR		R5,=APSR_Z_MASK
			ORRS	R4,R4,R5
			MSR		APSR, R4
			B		EndWhile
			
EndEarly	MOVS	R0,#0				;Set quotient (R0) to 0
			B		EndWhile
			
EndWhile	MRS		R4, APSR			;Clear C
			LDR		R5,=APSR_C_MASK
			BICS	R4,R4,R5
			MSR		APSR, R4
			B		EndSubR
			
EndSubR		POP     {R3-R5}
			BX		LR
			ENDP
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
            IMPORT  HardFault_Handler
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    HardFault_Handler  ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendSV (PendableSrvReq)
                                      ;   pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 transfer 
                                      ;   complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:FTFA command complete/
                                      ;   read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:(reserved)
            DCD    Dummy_Handler      ;26:SPI0
            DCD    Dummy_Handler      ;27:(reserved)
            DCD    UART0_ISR	      ;28:UART0 (status; error)
            DCD    Dummy_Handler      ;29:(reserved)
            DCD    Dummy_Handler      ;30:(reserved)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:(reserved)
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    Dummy_Handler      ;38:PIT
            DCD    Dummy_Handler      ;39:(reserved)
            DCD    Dummy_Handler      ;40:(reserved)
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:(reserved)
            DCD    Dummy_Handler      ;46:PORTA
            DCD    Dummy_Handler      ;47:PORTB
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
prompt		DCB			"Type a queue command (D,E,H,P,S):\0"
promptEnq	DCB			"Character to enqueue:\0"
promptHelp	DCB			"D (dequeue), E (enqueue), H (help), P (print), S (status)\0"
failure		DCB			"Failure:\0"
success		DCB			"Success:\0"
status		DCB			"Status:\0"
in			DCB			"     In=0x\0"
out			DCB			"     Out=0x\0"
num			DCB			"     Num=\0"
;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<
String1		SPACE	MAX_STRING
			ALIGN
QBuffer		SPACE	Q_BUF_SZ
			ALIGN
QRecord		SPACE	Q_REC_SZ
			ALIGN

RxQBuffer	SPACE	XQ_BUF_SZ
			ALIGN
RxQRecord	SPACE	Q_REC_SZ
			ALIGN
TxQBuffer	SPACE	XQ_BUF_SZ
			ALIGN
TxQRecord	SPACE	Q_REC_SZ
;>>>>>   end variables here <<<<<
            ALIGN
            END