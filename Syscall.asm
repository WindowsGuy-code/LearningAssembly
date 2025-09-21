global main
extern printf
extern NtQuerySystemInformation
extern VirtualAlloc
extern RtlExitUserProcess

%define NULL 0
%define STATUS_SUCCESS 0x00000000
%define MEM_COMMIT  0x00001000
%define MEM_RESERVE 0x00002000
%define PAGE_READWRITE 0x04
%define ERROR_NOT_FOUND 0x0404

section .data 

dd len
imgS db 'Image Size: %d', 10, 0
imgA db 'Image address: %d', 10, 0
error db 'Alert Alert: %d', 10, 0
name db 'ntoskrnl.exe', 0

section .text 

Erorr:
  lea rcx, [error]
  mov edx, rax ; rax has error code 
  call printf
  mov rcx, edx ; mov first_arg, erorr_code
  call RtlExitUserProcess


eq:
  mov r15, 1 ; set r 15 to 1 so Filter doesnt repeat when we return
  mov rax, [rdx + 0x10] ; ImageBase
  mov r8, [rdx + 0x18] ; ImageSize
  jmp done

Filter:
  mov ax, 0x0128 ; Size of a single structure nut we have an array
  mov eax, [r10]
  mov r15, eax; all modules ULONG
  mov cx, r15 
  mul cx ; multiply the structure size by the (currently top module)
  lea rdx, [ecx + ax]
  
  mov rbx, [rdx + 0x24]
  movzx rsi, word [rdx + 0x26]
  add rbx, rsi
  
  mov edi, name
  push edi
  push ecx
  mov ecx, -1 
  xor eax, eax 
  repne scasb 
  not ecx 
  pop edi 
  repe cmpsb 
  pop ecx 

  je eq ; found target

; "ntoskrnl.exe"
;
  dec r15 ; move back one structure
  jnz Filter ; if r15 == 0 then we reached the end

done:
  test rax, rax ; if this is true then rax is not filled therefor ntoskrnl was not found
  mov rax, ERROR_NOT_FOUND
  jz Erorr
  
  lea rcx, [imgS]
  mov edx, r8 ; this is from eq
  call printf

  lea rcx, [imgA]
  mov edx, rax ;also from eq
  call printf

  mov rax, STATUS_SUCCESS
  jmp Erorr ; Looooks confusing but we just use Error to exit since its easier



main:
  mov rcx, 11
  mov rdx, NULL
  mov r8, NULL
  lea r9, [len]
  call NtQuerySystemInformation
  cmp rax, STATUS_SUCCESS
  jne Erorr
  ; 
  ;Wie groß ist das ergebniss
  ;
  mov rcx, NULL
  mov rdx, len
  mov r8, MEM_COMMIT
  or r8, MEM_RESERVE
  mov r9, PAGE_READWRITE
  call VirtualAlloc

  ; Ok, wachse so groß wie das ergebniss

  mov r10, rax

  mov rcx, 11
  lea rdx, [rax]
  mov r8, len
  mov r9, NULL
  call NtQuerySystemInformation
  cmp rax, STATUS_SUCCESS
  jne Erorr
  
  xor rax, rax
  jmp Filter


