global main
extern printf

section .data 
msg db 'Hello World', 10, 0

section .text 

main:
  lea rcx, [rel msg]
  call printf
