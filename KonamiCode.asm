; Program to check if user inputs Konami Code (U-U-D-D-L-R-L-R-B-A) before pressing START

; iNES Header

DB $4E, $45, $53, $1A, $02, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00

ORG $8000

; Controller input masks.  Each one is set to value of that button alone.

BUTTON_A		EQU		#%00000001
BUTTON_B		EQU 		#%00000010
BUTTON_START		EQU		#%00001000
CONTROLLER_UP		EQU	 	#%00010000
CONTROLLER_DOWN 	EQU		#%00100000
CONTROLLER_LEFT 	EQU		#%01000000
CONTROLLER_RIGHT	EQU		#%10000000

; Other defines

BUFFER_SIZE		EQU		#$0A
NORMAL_NBR_LIVES	EQU		#$02
KC_NBR_LIVES		EQU		#$1C

; Variables

Buffer = $00			; Starting address of input buffer.  Buffer is from $0 - $9
BufferHead = $10		; Pointers to head and tail of buffer.
BufferTail = $12
BufferFull = $14		; 1 if full, 0 else
RemainingLives = $20
CurrentInput = $30
LastInput = $32
	
; Set up
; Basic Init sequence from nesdev.com

Reset_Vector:
	sei        ; ignore IRQs
    	cld        ; disable decimal mode
    	ldx #$40
    	stx $4017  ; disable APU frame IRQ
    	ldx #$ff
    	txs        ; Set up stack
    	inx        ; now X = 0
    	stx $2000  ; disable NMI
    	stx $2001  ; disable rendering
    	stx $4010  ; disable DMC IRQs

    ; Clear the vblank flag, so we know that we are waiting for the
    ; start of a vertical blank and not powering on with the
    ; vblank flag spuriously set
    
	bit $2002

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized

@vblankwait1:  
    	bit $2002
    	bpl @vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS.  Conveniently, X is still 0.
    txa

@clrmem:
	sta $000,x
    	sta $100,x
    	sta $300,x
    	sta $400,x
    	sta $500,x
    	sta $600,x
    	sta $700,x  ; Remove this if you're storing reset-persistent data

    	inx
    	bne @clrmem

@vblankwait2:
	bit $2002
    	bpl @vblankwait2

; Start of actual program code

	lda #<Buffer		; Set up buffer
	sta BufferHead
	sta BufferTail

	lda NORMAL_NBR_LIVES	; Begin with 2 (remaining) lives
	sta RemainingLives
	lda #$00
	sta LastInput		; clear input variables
	sta CurrentInput
	sta BufferFull
	tay			; Zero Y offset for indirect addressing
	
TitleLoop:
	jsr ReadController	; Strobe controller
	lda CurrentInput
	cmp #$00		; Loop until player provides input
	beq TitleLoop
	cmp LastInput		; Debounce input
	beq TitleLoop
	
	cmp BUTTON_START	; If START pressed, no more input
	beq  GameStart

	lda BufferFull		; Is buffer full?
	cmp #$01
	beq BufferIsFull

	lda CurrentInput	; No, store input at head
	sta (BufferHead),Y
	inc BufferHead		; increment head
	lda BufferHead 		; Is buffer full now?
	cmp #<Buffer + BUFFER_SIZE
	bne TitleLoop		; No, we're done
	lda #$01		; Yes, set flag...
	sta BufferFull
	lda #<Buffer		; ...and reset head to start
	sta BufferHead
	inc BufferTail		; also eject oldest element
	bne TitleLoop		; done for this input
	
BufferIsFull:
	lda CurrentInput	; if full, head is treated the same
	sta (BufferHead),Y
	inc BufferHead
	lda BufferHead
	cmp #<Buffer + BUFFER_SIZE	; reached max size?
	bne +			; no, move on
	lda #<Buffer		; yes, reset head
	sta BufferHead
+
	inc BufferTail		; now full, so increment tail each time
	lda BufferTail
	cmp #<Buffer + BUFFER_SIZE	; is tail at end?
	bne TitleLoop			; No, we're done
	lda #<Buffer			; yes, wrap around
	sta BufferTail
	jmp TitleLoop			; loop until START is pressed.
	
GameStart:
	
; Read input from Buffer and compare to Konami code

	lda BufferHead		; Is head at start of buffer?
	cmp #<Buffer
	bne +			; yes, put it at end
	adc #<Buffer + BUFFER_SIZE
+
	dec BufferHead		; now subtract 1 to undo last increment
	lda BufferTail		; do same for tail
	cmp #<Buffer
	bne +
	adc #<Buffer + BUFFER_SIZE
+
	dec BufferTail
	
	ldx #$00		; set up memory offsets
	ldy #$00
-
	lda (BufferTail),Y		; Compare tail value to KC entry at offset X
	cmp KonamiCode,X
	bne ExitLoop			; Exit loop if not same
	inx				; Get next code offset...
	txa				; ...but first check if we've read all 10 entries
	cmp BUFFER_SIZE
	beq +				; If so, we're done
	inc BufferTail			; Otherwise, increment tail
	lda BufferTail
	cmp #<Buffer + BUFFER_SIZE	; Are we at end of buffer?
	bne -				; No, get next code entry
	lda #<Buffer			; yet, reset to 0
	sta BufferTail
	jmp -			; do next comparison
	
+	
	lda KC_NBR_LIVES		; If all KC entries match input, give player 30 lives
	sta RemainingLives
	jmp ExitLoop			; Skip code value bytes
	
ReadController:

; Strobe controller, then read all 8 buttons and store in accumulator

	lda CurrentInput
	sta LastInput

	lda #$01
	sta $4016
	lda #$00
	sta $4016
	ldx #8
-
	pha
	lda $4016
	and #$03
	cmp #$01
	pla
	ror a
	dex
	bne -
	sta CurrentInput
	rts
	
KonamiCode:
DB	CONTROLLER_UP, CONTROLLER_UP, CONTROLLER_DOWN, CONTROLLER_DOWN, CONTROLLER_LEFT, CONTROLLER_RIGHT, CONTROLLER_LEFT, CONTROLLER_RIGHT, BUTTON_B, BUTTON_A

ExitLoop:
	jmp ExitLoop

NMI_Vector:
	rti
BRK_Vector:
	rti

ORG $FFFA
DW NMI_Vector, Reset_Vector, BRK_Vector

INCBIN "mario.chr"
