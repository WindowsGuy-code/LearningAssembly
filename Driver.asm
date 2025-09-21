extern KdPrint
extern MmGetSystemRoutineAddress
extern ExAllocatePool
extern NonPagedPool
extern IMAGE_FIRST_SECTION

global DriverEntry

%define NULL 0
%define STATUS_SUCCESS 0x00000000
%deifne STATUS_ERROR_UNKNOWN 0x00000001

section .data 
Foundstr db 'Found Pattern: %d', 10, 0 
hello db 'PatternDriver loaded', 10, 0 
bye db 'Unloading PatternDriver', 10, 0
errmsg db '[PatternDriver] Error: %d', 10, 0
Foundaddr db '[PatternDriver] Found Kernel base: %d', 10, 0
FoundSize db '[PatternDriver] Found Kernel Size: %d', 10, 0
text db '.text', 0
data db '.data', 0
rodata db '.rodata'


uniSys:
  dw 'Z', 'w', 'Q', 'u', 'e', 'r', 'y', 'S', 'y', 's', 't', 'e', 'm', 'I', 'n', 'f', 'o', 'r', 'm', 'a', 't', 'i', 'o', 'n', 0

FullUniSys:
  dw 48
  dw 50
  dq uniSys

dq zwQuerySystemInfo
dd len
targetName db 'ntosklrnl.exe', 0

section .text 

DriverUnload:
  push rcx
  lea rcx, [rel bye]
  call KdPrint
  pop rcx
  mov rax, rcx 
  ret

error:
  lea rcx, [rel errmsg]
  mov ecx, STATUS_ERROR_UNKNOWN
  call KdPrint
  mov rcx, STATUS_ERROR_UNKNOWN
  jmp DriverUnload


eq:
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
  
  mov edi, [targetName]
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

doneModule:
  test rax, rax ; if this is true then rax is not filled therefor ntoskrnl was not found
  jz error

  lea rcx, [Foundaddr]
  mov ecx, rax
  call KdPrint

  lea rcx, [FoundSize]
  mov ecx, r8
  call KdPrint


patternfilter:
  
  mov ax, 40 
  mov cx, r11
  mul cx
  pop rcx
  lea rdi, [rax + ax]
  mov rdx, [rdi + 0x08]
  lea rcx, [r11 + rdx]
  mov rdx, [rax + 0x0C]
  
  mov edi, byte ptr [rax]
  push ecx
  mov ecx, -1 
  xor eax, eax 
  repne scasb 
  not ecx 
  repe cmpsb
  pop ecx 
  je findPattern
  dec r11 
  jmp patternfilter
  

  

  
  
;


findPattern:
  

PatternScanImage:
  mov r10w, [rcx]
  push rcx
  cmp r10w, 0x4D5A
  jne error
  lea r11, [r10 + 0xC8]
  lea r9, [r10 + r11]
  mov edx, [r9]
  cmp edx, 0x50450000
  jne error 
  
  mov rcx, r9
  call IMAGE_FIRST_SECTION
  lea rdx, [r9 + 4]
  mov r11, [rdx + 2]
; esi: input
  mov edi, byte ptr [rax]
  push ecx
  mov ecx, -1 
  xor eax, eax 
  repne scasb 
  not ecx 
  repe cmpsb
  pop ecx 
  pop r14
  jne patternfilter
  mov rdi, [rax + 0x08]
  lea rcx, [rcx + rdi]
  mov rdx, [rax + 0x0C]
  jmp findPattern













DriverEntry:
  sub rsp, 40
  lea rcx, [rel hello]
  call KdPrint 

  lea rcx, [FullUniSys]
  call MmGetSystemRoutineAddress
  mov [zwQuerySystemInfo], rax
  mov rdi, rax 
  
  mov rcx, 11
  mov rdx, NULL
  mov r8, NULL
  lea r9, [len]
  call rdi

  mov rdi, [len]
  test [len], rdi
  jz error
  

  mov rcx, NonPagedPool 
  mov rdx, [len]
  call ExAllocatePool
  mov rdx, rax
  mov rcx, 11
  mov rdi, [zwQuerySystemInfo]
  mov r8, [len]
  mov r9, NULL
  call rdi
  cmp rax, STATUS_SUCCESS
  jne error

  xor rax, rax 
  jmp Filter


  

  
  
