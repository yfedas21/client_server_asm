; Client / Server implementation in Assembly
; Server component
;
; ***************************************************************************************
; Sources:
; - MS documentation at 	
;	https://docs.microsoft.com/en-us/windows/desktop/winsock/about-clients-and-servers
; - Sloan Kelly explanation: https://www.youtube.com/watch?v=WDn-htpBlnU
; - C++ disassembly
; ***************************************************************************************

.686P
.model flat, stdcall
.stack 4096

INCLUDE Irvine32.inc	; for output

INCLUDELIB WS2_32

EXTRN __imp_socket@12:PROC

.data

; ************************* CONSTANTS DEFINED IN CPP FILES ******************************

; ------------------------------------ ws2def.h -----------------------------------------
AF_INET					= 2		; internetwork: UDP, TCP, etc. - IPv4
SOCK_STREAM				= 1		; stream socket (TCP)

; INADDR_ANY in ws2def.h actually is 64 0s
INADDR_ANY				= 7f000001h 	; loopback address [127.0.0.1]

; ----------------------------------- WinSock2.h ----------------------------------------
INVALID_SOCKET			= -1	; the twos complement of 0 (~0), 
								; used because SOCKET is unsigned
; ---------------------------------------------------------------------------------------

hello BYTE "Hello World from Assembly",0

.code 
main PROC
	mov edx, offset hello
	call WriteString
	
	exit
main ENDP
end