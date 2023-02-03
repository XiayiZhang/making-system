org 0x7c00;调用bios中断，初始化屏幕。
mov ax,3
int 0x10;初始化寄存器
mov ax,0
mov ds,ax
mov es,ax
mov SI,msg 
mov sp,0x7c00
call print;调用print
;print 出的string
msg:
    DB "Booting...",10,13,0;\n\r,print实现
print:
    mov ah, 0x0e
.near:
    mov al, [si]
    cmp al, 0
    jz .end
    int 0x10
    inc si
    jmp .near
.end:
    ret;魔数0x55,0xaa or 0xaa55
times 510-($-$$) db 0
db 0x55,0xaa
call print
msg:
    DB"加载完成，请输入指令！"
print:
    mov ah,0x0e
