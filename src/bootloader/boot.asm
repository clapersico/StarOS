org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT32 HEADER
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0F0h
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0       

; extended boot sector
ebr_drive_number:           db 0
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h
ebr_volume_label:           db 'STAR OS    '
ebr_system_id:              db 'FAT12   '

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
	
.done:
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

	; Prova lettura dal floppy
	mov [ebr_drive_number], dl

	mov ax, 1				; LBA=1 secondo settore disco
	mov cl, 1				; 1 settore da leggere
	mov bx, 0x7E00
	call disk_read
	
	; Stampo la scritta di benvenuto
	mov si, msg_hello
	call puts
	
	cli
	hlt

;
; Gestione errori
;

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h						; Attesa pressione tasto
	jmp 0FFFFh:0				; Salto all'inizio del BIOS

.halt:
	cli
	hlt

;
; Disk routines
;

;
; Convertitore indirizzo da LBA -> a CHS
;   Parametri:
;       - ax: indirizzo LBA
; 
;   Return
;       - cx [bits 0-5]: numero settore
;       - cx [bits 6-15]: cilindro
;       - dh: head
;

lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word[bdb_sectors_per_track]
    inc dx
    mov cx, dx

    xor dx, dx
    div word[bdb_heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al
    pop ax
    ret

;
; Leggi settori dal disco
; Parametri:
;	- ax: indirizzo LBA
;	- cl: numero dei settori da leggere
;	- dl: drive number
;	- es:bx: indirizzo di memoria dove salvare i dati letti
;
disk_read:
	push ax
	push bx
	push cx
	push dx
	push di
	
	push cx
	call lba_to_chs
	pop ax

	mov ah, 02h
	mov di, 3			; retry count

.retry:
	pusha				; salva tutti i registri
	stc				; set carry flag
	int 13h
	jnc .done

	; In caso di fallimento durante la lettura
	popa				; ripristina tutti i registri
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:					; se finiscono i tentativi di lettura
	jmp floppy_error

.done:
	popa

	pop di			; ripristino i registri
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;
; Reset disk controller
; Parametri:
;	- dl: drive number
;

disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_hello: db 'Avvio sistema StarOs. Benvenuto!', ENDL, 0
msg_read_failed:	db 'Lettura dal disco fallita', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h