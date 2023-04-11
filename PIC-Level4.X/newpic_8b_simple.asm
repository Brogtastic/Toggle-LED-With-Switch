#include "p12f1572.inc"

; CONFIG1
; __config 0x31E4
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _BOREN_OFF & _CLKOUTEN_ON
; CONFIG2
; __config 0x1EFF
 __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_OFF & _STVREN_ON & _BORV_LO & _LPBOREN_OFF & _LVP_OFF
 
 ;NOTE:             MCLR OFF
 
    IDATA
previousState db 0		    ; Variable that tracks previous state of button
buttonPressFlag db 0		    ; Flag variable (current state)
 
RES_VECT  CODE    0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program
    
INT_VECT  CODE	  0x0004	    ;interrupt vector
    GOTO  ISR

MAIN_PROG CODE

START
    ; Initialize OSCCON register and set Fosc to 4Mhz
    MOVLW 0x68
    BANKSEL OSCCON
    MOVWF OSCCON
    
    
    ; Initialize RA5 pin to be output
    BANKSEL TRISA
    BCF TRISA, RA5
    BSF TRISA, RA2
    
    ; Individual pull-ups are now enabled
    BANKSEL OPTION_REG
    BCF OPTION_REG, 7
    
    ;Clear this to make input digital
    BANKSEL ANSELA
    CLRF ANSELA
    
    ; Enabled weak pull-up of RA2
    BANKSEL WPUA
    MOVLW 0x04
    MOVWF WPUA
    
    ; Initialize global interrupt enable and peripheral interrupt enable
    BANKSEL INTCON
    BSF INTCON, GIE
    BSF INTCON, PEIE
    
    ; Initialize Timer2 interrupt enable bit
    BANKSEL PIE1
    BSF PIE1, TMR2IE
    
    ; **************************************************************************
    ; Set prescaler to 4, postscaler 10, and enable timer2 in T2CON register
    ; Initialize PR2 so mainscale divides by 250
    ; Interval between interrupts = 1us * 4 * 250 * 15 = 15ms
    ; Need to wait for 50 of these intervals to pass before we get half a second
    ; **************************************************************************
    MOVLW 0x75				    ; 1110101
    BANKSEL PR2
    MOVWF PR2
    MOVLW 0x4D
    BANKSEL T2CON
    MOVWF T2CON
    
;**************************************************************************
; In the main loop we wait until the buttonPressFlag is set in the ISR
; and if it isn't set we loop until it is. If the buttonPressFlag is set
; then that means the button went from not being pressed to being pressed
; so we toggle RA5 and blink the LED. Then we clear the buttonPressFlag
; so we can do it all over again.
;**************************************************************************
LOOP
    BANKSEL buttonPressFlag
    BTFSS buttonPressFlag, 0
    GOTO LOOP
    BANKSEL PORTA
    MOVLW 0x20
    XORWF PORTA, RA5			    ; Toggle RA5 / Blink LED Here.
    BCF buttonPressFlag, 0
    GOTO LOOP
    
    
;***************************************************************************
; In the following ISR, two possible call statements can be made.
; Either RA2 (the button) is clear (pressed) or set (unpressed). 
; Our only goals are to keep track of the button states and set the 
; flag if the button goes from unpressed to pressed. So we have to 
; maintain accuracy of the previousState variable and wait for that
; golden "RA2 is clear and previous state is clear" combination.
; If the button is up and the previous state is up then no action
; is required and we return to the ISR. If the button is up and the
; previous state is down, we just change the previous state to up as well.
; If button is down and previous state is down then no action is required
; because that means the button is being held, not pressed -- no change
; to our LED. If the button is down and the previous state is released,
; that's what we've been waiting for! We set the buttonPressFlag which
; will then lead us to toggle the state in the foreground loop and 
; blink that LED.
;***************************************************************************
ISR
    BANKSEL PIR1
    BCF PIR1, TMR2IF			    ; Clears timer2 interrupt flag 
    
    BANKSEL PORTA
    BTFSC PORTA, RA2
    CALL ButtonUpCheckState		    ; RA2 is set the button is not being pressed, time to check the state

    BTFSS PORTA, RA2
    CALL ButtonDownCheckState		    ; RA2 is clear the button is being pressed, time to check the state
    
    RETFIE
    
ButtonUpCheckState:
    BTFSS previousState, 0		    ; Do nothing if previous state is released
    RETURN				    
    BANKSEL previousState			    
    BCF previousState, 0		    ; Clear previous state if previous state is pressed because it's not being pressed anymore
    RETURN
    
ButtonDownCheckState:
    BTFSC previousState, 0		    ; Do nothing if previous state is pressed (because the button is still being pressed so who cares)
    RETURN
    BANKSEL previousState		    ; If the previous state is released that means the button is actually being pressed 
    BSF previousState, 0		    ; Set previous state to pressed
    BANKSEL buttonPressFlag
    BSF buttonPressFlag, 0
    RETURN
    
    END