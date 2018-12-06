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


; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
;
;									-Program Logic-
;
;		1. Initialize winsock (call WSAStartup)
;		2. Create a socket (call socket)
;		3. Bind the ip address and port to a socket (call bind)
;			a. Use localhost (127.0.0.1:5400)
;		4. Tell winsock the socket is a listening socket (call listen)
;		5. Wait for a client connection (call accept)
;		6. After client connects, get client info
;			a. client hostname
;			b. service name
;			c. display host info to console
;		7. Close the listening socket (call closesocket)
;		8. While-loop to accept data from client (as long as they send)
;		9. Receive data from client (call recv)
;		10. If the client sends any data, echo it back to them
;		11. After the client disconnects, close the client socket (call closesocket)
;		12.	Clean up winsock
;
; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

.686P
.model flat			
.stack 4096

INCLUDE Irvine32.inc			; for output, Irvine functions

INCLUDELIB WS2_32				; For WinAPI functions 
INCLUDELIB UCRT					; For memset 

EXTRN	accept@12:PROC
EXTRN	bind@12:PROC
EXTRN	closesocket@4:PROC
EXTRN	htons@4:PROC
EXTRN	listen@8:PROC
EXTRN	ntohs@4:PROC
EXTRN	recv@16:PROC
EXTRN	send@16:PROC
EXTRN	socket@12:PROC
EXTRN	WSAStartup@8:PROC
EXTRN	WSACleanup@0:PROC
EXTRN	getnameinfo@28:PROC
EXTRN	inet_ntop@16:PROC
EXTRN	memset:PROC

.data

; ************************* CONSTANTS DEFINED IN CPP FILES ******************************

; ------------------------------------ ws2def.h -----------------------------------------
AF_INET					= 2		; internetwork: UDP, TCP, etc. - IPv4
SOCK_STREAM				= 1		; stream socket (TCP)
INADDR_ANY				= 7f000001h 	; loopback address [127.0.0.1], MODIFIED
NI_MAXHOST				= 1025	; max size of FQDN
NI_MAXSERV				= 32	; max size of a service name

; ----------------------------------- WinSock2.h ----------------------------------------
INVALID_SOCKET			= -1	; the 2s comp of 0 (~0), because SOCKET is unsigned
SOCKET_ERROR			= -1	; synonymous to INVALID_SOCKET in this context
SOMAXCONN				= 7fffffffh		; maxinmum # of pending connections in queue

; --------------------------------- my constants ----------------------------------------
BUF_SIZE				= 4096	; the size of the buffer client sends data into
; ***************************************************************************************

errStr BYTE "Hello World from Assembly",0

.code 
main PROC
	push	0
	push	1
	push	2
	call	DWORD PTR socket@12

	exit
main ENDP
end