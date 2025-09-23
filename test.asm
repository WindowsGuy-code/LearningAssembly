global DriverEntry
extern KdPrint
extern ZwQuerySystemInformation
extern strstr
extern ExAllocatePool


%define SYSCALL_FAILED 0x00000011
%define STATUS_SUCCESS 0x00000000
%define ALLOCATION_FAILED 0x00000055
%define sizeofRTL_PROCESS_MODULES 0x0128
%define TARGET_NOT_FOUND 0x0000404
%define e_magic 0x5A4D
%define SIGNATURE_INCORRECT 0x0000401
%define nt_signature 0x50450000
%define STATUS_FAILED 0x50450320

section .data:
LoadedMSG db '[PatternDriver] Loaded', 10, 0
UnloadedMSG db '[PatternDriver] Unloaded with code: %d', 10, 0
KernelBaseMSG db '[PatternDriver] Kernel Base address: %d', 10, 0
KernelSizeMSG db '[PatternDriver] Kernel Size: %d', 10, 0
ErrorMSG db '[PatternDriver] An error occured (%d)', 10, 0
dq len
TargetProc db 'ntoskrnl.exe', 0
dd ImageSize

driverUnloadptr:
  dq DriverUnload

section .text:

; Helper1 [PatternScanning]
IMAGE_FIRST_SECTION:
  sub rsp, 40
  movzx eax, [rcx + 0x14]
  add rcx, 0x18
  add rax, rcx
  add rsp, 40
  ret


specialExit:
  add rsp, 40
  ret

ReturnResults: ; rdi: ptr section rcx: addr
  mov r10, dword ptr [rdi + 0x0C]
  lea rax, [rcx + r10]
  mov rdi, dword ptr [rdi + 0x08]
  add rsp, 40
  ret

SectionLoop: ; rcx addr, rdi: ptr Section r8: numSections r9: Name
  mov r10, rcx
  mov r11, rdi

  xor rax, rax
  movzx rcx, byte ptr [r11]
  movzx rdi, byte ptr [r9]
  call strstr
  test rax, rax
  mov rdi, r11
  mov rcx, r10
  jz ReturnResult

  cmp r9, r12
  mov rax, STATUS_FAILED
  je specialExit
  inc r12
  lea rcx, [rcx + 0x40]
  jmp SectionLoop


FindSection: ;rcx: addr rdi: ptr Section(Name)
  sub rsp, 40
  movzx r10, byte ptr [rcx]
  movzx r11, e_magic
  cmp r10, r11
  xor r11, r11
  mov rax, SIGNATURE_INCORRECT
  je specialExit

  mov r11, dword ptr [rcx + 0x3c]
  lea r12, [rcx + r11]
  
  mov r13, dword ptr [r12]
  cmp r13, nt_signature
  je specialExit

  push rcx
  mov rcx, [r12]
  call IMAGE_FIRST_SECTION
  push rax
  push rdi ; SectionName
  movzx rcx, byte ptr [rax]
  movzx rdi, byte ptr [rdi] ; SectionName
  call strstr
  test rax, rax
  pop r9 ; sectionName
  pop rax ; ptr Section
  mov rdi, rax
  pop rcx ; addr
  jz ReturnResults

  
  lea r8, [r12 + 0x06]
  movzx r8, dword ptr [r8]

  jmp SectionLoop ; rcx addr, rdi: ptr Section r8: numSections r9: Name
  

; Helper2 [Info gathering]

FilterLoopDone:
  mov rax, [rdi + 0x10]
  mov r15, [rdi + 0x18]
  mov [ImageSize], r15
  add rsp, 40
  ret

;Fix the looping here
FilterLoop:
  mul edx

  lea rdx, qword ptr [r8 + eax]
  mov r10, [rdx + 0x26] ; OffsetToFileName
  lea r11, [rdx + 0x28] ; FullPathName

  add r11, r10
  mov rcx, [r11]
  mov rdi, [TargetProc]
  call strstr
  test rax, rax
  mov rdi, rdx
  jz FilterLoopDone

  dec edx
  jmp FilterLoop


Filter:
  add rsp, 40
  lea rdx, qword ptr [rdi + sizeofRTL_PROCESS_MODULES]
  mov r10, [rdx + 0x26]
  lea r11, [rdx + 0x28]

  add r11, r10
  mov rcx, [r11]
  mov rdi, [TargetProc]
  call strstr
  test rax, rax
  jz FilterLoopDone
  jmp FilterLoop


; Main Routines
DriverUnload:
  push rbp
  lea rcx, [rel UnloadedMSG]
  mov edx, STATUS_SUCCESS
  call KdPrint
  pop rbp
  ret

Error:
  push rbp
  lea rcx, [rel ErrorMSG]
  call KdPrint
  mov rax, STATUS_SUCCESS
  pop rbp
  add rsp, 40
  ret

Exit:
  cmp edx, STATUS_SUCCESS
  jne Error
  push rbp ; Align stack (according to msdn kdPrint is like printf)
  lea rcx, [rel UnloadedMSG]
  call KdPrint
  mov rax, STATUS_SUCCESS
  pop rbp
  add rsp, 40
  ret


DriverEntry:
  sub rsp, 40
  mov rdi, qword [driverUnloadPtr]
  mov [rax + 0x32], rdi

  mov rcx, 11
  mov rdi, 0
  mov r8, 0
  lea r9, qword ptr [len]
  call ZwQuerySystemInformation ; SystemInfoClass, SystemInfo len, &len

  mov rcx, [len]
  test rcx, rcx
  mov edx, SYSCALL_FAILED
  jz Exit

  xor rcx, rcx
  mov rdx, rcx
  call ExAllocatePool
  test rax, rax
  mov edx, ALLOCATION_FAILED
  jz Exit

  mov rcx, 11
  mov rdi, rax
  mov r8, [len]
  lea r9, qword ptr [len]
  call ZwQuerySystemInformation
  cmp rax, STATUS_SUCCESS
  mov edx, SYSCALL_FAILED
  jne Exit

  mov eax, sizeofRTL_PROCESS_MODULES
  mov edx, dword [rdi]
  lea r8, [rdi + 0x08]

  xor rax, rax
  call Filter
  test rax, rax
  mov edx, TARGET_NOT_FOUND
  jz Exit

  push rax
  lea rcx, [rel KernelBaseMSG]
  mov edx, rax
  call printf

  lea rcx, [rel KernelSizeMSG]
  mov edx, [ImageSize]
  call printf
  pop rcx

  


  add rsp, 40
  ret
