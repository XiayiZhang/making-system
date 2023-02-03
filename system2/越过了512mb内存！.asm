
NUMsector      EQU    4        ; 设置读取到的软盘最大扇区编号()
NUMheader      EQU    0        ; 设置读取到的软盘最大磁头编号(01)
NUMcylind      EQU    0        ; 设置读取到的软盘柱面编号

mbrseg         equ    7c0h     ;启动扇区存放段地址
newseg         equ    800h     ;跳出MBR之后的新段地址

jmp   start
msgwelcome:     db '------Wlecome VAR Os------','$'
msgstep1:       db 'Step1:now  is   in   mbr','$'
msgmem1:        db 'Memory Address is---','$'
msgcs1:         db 'CS:????H','$'

cylind  db 'Cylind:?? $',0    ; 设置开始读取的柱面编号
header  db 'Header:?? $',0    ; 设置开始读取的磁头编号
sector  db 'Sector:?? $',2    ; 设置从第2扇区开始读
FloppyOK db 'Read OK','$'
Fyerror db 'Read Error' ,'$'

start:

call  inmbr
call  floppyload
jmp   newseg:0        ;通过此条指令跳出MBR区


inmbr:
mov   ax,mbrseg   ;为显示各种提示信息做准备
mov   ds,ax
mov   ax,newseg
mov   es,ax   ;为读软盘数据到内存做准备，因为读软盘需地址控制---ES:BX
call  inmbrshow
call  showcs
call  newline
call  newline
call  newline
ret



inmbrshow:
mov   si,msgwelcome
call  printstr
call  newline
call  newline
mov   si,msgstep1
call  printstr
call  newline
mov   si,msgmem1
call  printstr
ret


printstr:                  ;显示指定的字符串, 以'$'为结束标记
      mov al,[si]
      cmp al,'$'
      je disover
      mov ah,0eh
      int 10h
      inc si
      jmp printstr
disover:
      ret

newline:                     ;显示回车换行
      mov ah,0eh
      mov al,0dh
      int 10h
      mov al,0ah
      int 10h
      ret


showcs:                       ;展示CS的值
      mov  ax,cs

      mov  dl,ah
      call HL4BIT
      mov  dl,  BH
      call  ASCII
      mov  [msgcs1+3],dl

      mov  dl,  Bl
      call  ASCII
      mov  [msgcs1+4],dl

      mov  dl,al
      call HL4BIT
      mov  dl,  BH
      call  ASCII
      mov  [msgcs1+5],dl

      mov  dl,  Bl
      call  ASCII
      mov  [msgcs1+6],dl

      mov  si,  msgcs1
      call printstr

      ret


;-----------------将16进制数字(1位)转换成ASCII码，输入DL,输出DL------
ASCII:   CMP  DL,9
         JG   LETTER  ;DL>OAH
         ADD  DL,30H  ;如果是数字,加30H即转换成ASCII码
         RET
LETTER:  ADD  DL,37H  ;如果是A～F,加37H即转换成ASCII码
         RET

;-----------------取出1个字节Byte的高4位和低4位,输入DL,输出BH和BL----------

HL4BIT:  MOV  DH,dl
         MOV  BL,dl
         SHR  DH,1
         SHR  DH,1
         SHR  DH,1
         SHR  DH,1
         MOV  BH,DH                    ;取高4位
         AND  BL,0FH                   ;取低4位
         RET


floppyload:
     call    read1sector
     MOV     AX,ES
     ADD     AX,0x0020
     MOV     ES,AX                ;一个扇区占512B=200H，刚好能被整除成完整的段,因此只需改变ES值，无需改变BP即可。
     inc   byte [sector+11]
     cmp   byte [sector+11],NUMsector+1
     jne   floppyload             ;读完一个扇区
     mov   byte [sector+11],1
     inc   byte [header+11]
     cmp   byte [header+11],NUMheader+1
     jne   floppyload             ;读完一个磁头
     mov   byte [header+11],0
     inc   byte [cylind+11]
     cmp   byte [cylind+11],NUMcylind+1
     jne   floppyload             ;读完一个柱面

     ret


numtoascii:     ;将2位数的10进制数分解成ASII码才能正常显示。如柱面56 分解成出口ascii: al:35,ah:36
     mov ax,0
     mov al,cl  ;输入cl
     mov bl,10
     div bl
     add ax,3030h
     ret

readinfo:       ;显示当前读到哪个扇区、哪个磁头、哪个柱面
     mov si,cylind
     call  printstr
     mov si,header
     call  printstr
     mov si,sector
     call  printstr
     ret



read1sector:                      ;读取一个扇区的通用程序。扇区参数由 sector header  cylind控制

       mov   cl, [sector+11]      ;为了能实时显示读到的物理位置
       call  numtoascii
       mov   [sector+7],al
       mov   [sector+8],ah

       mov   cl,[header+11]
       call  numtoascii
       mov   [header+7],al
       mov   [header+8],ah

       mov   cl,[cylind+11]
       call  numtoascii
       mov   [cylind+7],al
       mov   [cylind+8],ah

       MOV        CH,[cylind+11]    ; 柱面从0开始读
       MOV        DH,[header+11]    ; 磁头从0开始读
       mov        cl,[sector+11]    ; 扇区从1开始读

        call       readinfo        ;显示软盘读到的物理位置
        mov        di,0
retry:
        MOV        AH,02H            ; AH=0x02 : AH设置为0x02表示读取磁盘
        MOV        AL,1              ; 要读取的扇区数
        mov        BX,    0          ; ES:BX表示读到内存的地址 0x0800*16 + 0 = 0x8000
        MOV        DL,00H            ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
        INT        13H               ; 调用BIOS 13号中断，磁盘相关功能
        JNC        READOK            ; 未出错则跳转到READOK，出错的话则会使EFLAGS寄存器的CF位置1
           inc     di
           MOV     AH,0x00
           MOV     DL,0x00         ; A驱动器
           INT     0x13            ; 重置驱动器
           cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃
           jne     retry

           mov     si, Fyerror
           call    printstr
           call    newline
           jmp     exitread
READOK:    mov     si, FloppyOK
           call    printstr
           call    newline
exitread:
           ret


times 510-($-$$) db 0
db 0x55,0xaa

;-------------------------------------------------------------------------------
;------------------此为扇区分界线，线上为第1扇区，线下为第2扇区-----------------
;-------------------------------------------------------------------------------

jmp    newprogram

msgstep2:       db 'Step2:now  jmp  out  mbr','$'
mesmem2:        db 'Memory address is---','$'
msgcs2:         db 'CS:????H','$'

newprogram:
mov     ax,newseg      ;跳转到新地址8000H之后，全部寄存器启用新的段地址
mov     ds,ax
mov     es,ax
call  outmbr
call  showcsnew
jmp   $


outmbr:
call  newlinenew
call  newlinenew
mov   si,msgstep2-512
call  printstrnew
call  newlinenew
mov   si,mesmem2-512
call  printstrnew
ret



showcsnew:                       ;展示CS的值
      mov  ax,cs

      mov  dl,ah
      call HL4BITnew
      mov  dl,  BH
      call  ASCIInew
      mov  [msgcs2+3-512],dl

      mov  dl,  Bl
      call  ASCIInew
      mov  [msgcs2+4-512],dl

      mov  dl,al
      call HL4BITnew
      mov  dl,  BH
      call  ASCIInew
      mov  [msgcs2+5-512],dl

      mov  dl,  Bl
      call  ASCIInew
      mov  [msgcs2+6-512],dl

      mov  si,  msgcs2-512
      call printstrnew
      ret

printstrnew:                  ;显示指定的字符串, 以'$'为结束标记
      mov al,[si]
      cmp al,'$'
      je disovernew
      mov ah,0eh
      int 10h
      inc si
      jmp printstrnew
disovernew:
      ret

newlinenew:                     ;显示回车换行
      mov ah,0eh
      mov al,0dh
      int 10h
      mov al,0ah
      int 10h
      ret

      ;-----------------将16进制数字(1位)转换成ASCII码，输入DL,输出DL------
ASCIInew:   CMP  DL,9
         JG   LETTERnew  ;DL>OAH
         ADD  DL,30H  ;如果是数字,加30H即转换成ASCII码
         RET
LETTERnew:  ADD  DL,37H  ;如果是A～F,加37H即转换成ASCII码
         RET

;-----------------取出1个字节Byte的高4位和低4位,输入DL,输出BH和BL----------

HL4BITnew:  MOV  DH,dl
         MOV  BL,dl
         SHR  DH,1
         SHR  DH,1
         SHR  DH,1
         SHR  DH,1
         MOV  BH,DH                    ;取高4位
         AND  BL,0FH                   ;取低4位
         RET
