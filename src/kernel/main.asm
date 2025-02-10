org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start:
	jmp main

; Stampo il benvenuto a schermo
; Parametri
;		- ds:si puntatori alla stringa
puts:
	; Salvo i registri prima di modificarli
	push si
	push ax
	
.loop:
	lodsb
	or al, al
	jz .done
	mov ah, 0x0e
	mov bh, 0
	int 0x10
	jmp .loop
	
.done
	pop ax
	pop si
	ret

main:
	; Preparo i segmenti di dati
	mov ax, 0
	mov ds, ax
	mov es, ax
	
	; Preparo lo stack
	mov ss, ax
	mov sp, 0x7C00	; SP Indice dello stack
	
	; Stampo la scritta di benvenuto
	mov si, msg_hello
	call puts
	
	hlt
	
.halt:
	jmp .halt
	
msg_hello: db 'Benvenuto sul sistema Star!', ENDL, 0
	
times 510-($-$$) db 0
dw 0AA55h