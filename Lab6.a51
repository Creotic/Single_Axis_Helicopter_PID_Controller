FAN		BIT P2.4			;Set FAN		(P2.4)
READ  	BIT P2.5			;Set READ		(P2.5)
WRITE 	BIT P2.6			;Set WRITE		(P2.6)
INTR  	BIT P2.7			;Set INTR		(P2.7)
SW		EQU P0				;Set SW			(P0)
LEDS    EQU P1				;Set LEDS		(P1)
MDATA	EQU P3				;Set MDATA		(P3)
	
SETP	EQU R5
PV		EQU R6
ERROR	EQU R7


FLAG EQU 1					;Set ISR Flag

ORG 0000H
	LJMP INITIAL			;Long Jump INITIAL
	
ORG 000BH
	LJMP TIMER0_ISR			;Long Jump TIMER0_ISR
	
ORG 0030H
	;Initialization (Do this once)
	INITIAL:
		;Set ISR
		MOV	 MDATA, #0FFH	;Initialize P3 to 255
		MOV  SW,	#0FFH	;Initialize P0 to 255
		MOV  LEDS,  #00H	;Initialize P1 to 0
		SETB INTR			;Set INTR (P2.7)
		MOV  TMOD,	#01H	;Enable Timer Mode 1
		MOV  IE,	#82H	;Set Interrupt Enable
		MOV  TL0,	#00H	;Set Timer LOW to 0
		MOV  TH0,	#0FFH	;Set Timer HIGH to 255
		SETB TR0			;Timer On
	
	;Execute MAIN forever
	;Switches will be read into LEDs and PV for the PID control
	;SETP and PV will be divided by 2, subtracted, and the difference 
	;will be added by 127 and put into ERROR. This allows for the
	;fan to constantly adjust itself and stabilize, creating an
	;oscillating effect until it reaches the final value.
	MAIN :
		SETB WRITE			;Turn on WRITE (P2.6)
		JB   INTR,  MAIN	;Loop if INTR is set
		CLR  READ			;Turn on READ (P2.5)
		MOV  A, 	MDATA	;Read P3 (Sensor)
		CPL  A				;Complement A
		MOV  LEDS,  A		;LEDS take A
		MOV  PV,	A		;Processing Value takes A
		SETB READ			;Turn off READ (P2.5)
		
		;SJMP MAIN			;Loop MAIN
		
		;PID PROPORTIONAL CONTROL (SW - MDATA = ERROR)
		;SW / 2 & MDATA / 2 ;Divide 2 by rotating right (clear carry)
		;SETP - PV	
		
		;SW / 2 -> Switches
		MOV A,		SW		;Move SW value into A (switches)
		RRC	A				;Rotate right
		CLR C				;Clear carry (shift right now)
		MOV SETP,	A		;Store into setpoint
		
		;PV / 2 -> MDATA
		MOV A,		PV		;Move MDATA value into A (sensor)
		RRC	A				;Rotate right
		CLR C				;Clear carry (shift right now)
		MOV PV,		A		;Store into PV
		
		;SETP - PV
		MOV  A,		SETP	;A takes SETP
		SUBB A,		PV		;A - PV (A = SETP - PV)
		
		;Add 127 to A (ERROR = A - 127)
		ADD A,		#127	;A + 127
		MOV ERROR,  A		;ERROR takes A
		
		SJMP MAIN			;Loop MAIN
	
	;Utilize if-else statement in TIMER0_ISR
	TIMER0_ISR:
		MOV  R1,    A		;Save Accumulator into temp register R1
		CLR  TR0			;Turn off timer
		MOV  TH0,	#0FFH	;Set Timer high to FF
		JB   FLAG, 	F_HIGH	;If FLAG is set to high jump to F_HIGH (IF)
							;Otherwise run through F_LOW		   (ELSE)
	
	;ELSE
	F_LOW:	
		SETB FLAG			;Set FLAG to 1
		CLR  FAN			;Clear FAN (P2.4) to LOW
		MOV  TL0,	ERROR	;Timer low takes current value of ERROR
		MOV  TH0,	#0FFH	;Set timer high to FF

		SJMP START_PWM		;Start PWM
	
	;IF
	F_HIGH:
		CLR  FLAG			;Set FLAG to 0
		SETB FAN			;Set FAN (P2.4) to HIGH
		MOV  A, 	#0FFH	;Set A to FF (255)
		
		SUBB A, 	ERROR	;A = 255 - ERROR
		MOV  TL0, 	A		;Timer low takes whatever A is
		MOV  TH0,   #0FFH	;Set timer high to FF
		CLR  WRITE			;Turn off WRITE
		NOP
		
	START_PWM:
		SETB TR0			;Turn on timer
		MOV  A,		R1		;Restore Accumulator of what R1 was.
		RETI				;Return
		
END