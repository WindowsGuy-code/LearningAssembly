global DriverEntry
extern KdPrint
extern ZwQuerySystemInformation
extern strstr
extern ExAllocatePool


%define SYSCALL_FAILED 0x00000011
%define STATUS_SUCCESS 0x00000000
%define ALLOCATION_FAILED 0x00000055
%define sizeofRTL_PROCESS_MODULES 0x0128

section .data:
LoadedMSG db '[PatternDriver] Loaded', 10, 0
UnloadedMSG db '[PatternDriver] Unloaded with code: %d', 10, 0
KernelBaseMSG db '[PatternDriver] Kernel Base address: %d', 10, 0
ErrorMSG db '[PatternDriver] An error occured (%d)', 10, 0
dq len
TargetProc db 'ntoskrnl.exe', 0
dd ImageSize

driverUnloadptr:
  dq DriverUnload

section .text:

; Helper1

FilterLoopDone:
  mov rax, [rdi + 0x10]
  mov r15, [rdi + 0x18]
  mov [ImageSize], r15
  add rsp, 40
  ret

FilterLoop:
  mul edx

  lea rdx, qword ptr [r8 + eax]
  mov r10, [rdx + 0x26] ; OffsetToFileName
  lea r11, [rdx + 0x28] ; FullPathName

  add r11, r10
  mov rcx, [r11]
  mov rdi, [TargetProc]
  call strstr
  cmp rax, 0
  mov rdi, rdx
  je FilterLoopDone

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
  cmp rax, 0
  je FilterLoopDone
  jmp 
  




; Main Routines
DriverUnload:
  lea rcx, [rel UnloadedMSG]
  mov ecx, STATUS_SUCCESS
  call KdPrint
  ret

Error:
  lea rcx, [rel ErrorMSG]
  call KdPrint
  mov rax, STATUS_SUCCESS
  add rsp, 40
  ret

Exit:
  cmp ecx, STATUS_SUCCESS
  jne Error
  lea rcx, [rel UnloadedMSG]
  call KdPrint
  mov rax, STATUS_SUCCESS
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
  call ZwQuerySystemInformation

  mov rcx, [len]
  test rcx, rcx
  mov ecx, SYSCALL_FAILED
  jz Exit

  call ExAllocatePool
  test rax, rax
  mov ecx, ALLOCATION_FAILED
  jz Exit

  mov rcx, 11
  mov rdi, rax
  mov r8, [len]
  lea r9, qword ptr [len]
  call ZwQuerySystemInformation
  cmp rax, STATUS_SUCCESS
  mov rcx, SYSCALL_FAILED
  jne Exit

  mov eax, sizeofRTL_PROCESS_MODULES
  mov edx, dword [rdi]
  lea r8, [rdi + 0x08]
  call Filter
  


  add rsp, 40
  ret
