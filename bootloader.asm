[BITS 16]
[ORG 0x7C00]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov sp, 0x7C00

    mov si, msg
    call print_string

    jmp hang

print_string:
    lodsb
    or al, al
    jz .done

    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x07
    int 0x10

    jmp print_string

.done:
    ret

hang:
    cli
    hlt
    jmp hang

msg db 'Hello, Boot!', 0x0D, 0x0A, 0

times 510-($-$$) db 0

dw 0xAA55
