; Client / Server implementation in Assembly
;
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
EXTRN	WriteString@0:PROC
EXTRN	WriteInt@0:PROC

; create a WSADATA struct, from WinSock2.h
WSADATA STRUCT 
	wVersion		WORD 514d 
	wHighVersion	WORD 514d
	szDescription	BYTE 257 DUP(?)
	szSystemStatus	BYTE 129 DUP(?)
	iMaxSockets		WORD 0
	iMaxUdpDg		WORD 0
	;lpVendorInfo	BYTE PTR ?
WSADATA ENDS

sockaddr_in STRUCT
	sin_family		WORD ?
	sin_port		WORD ?
	sin_addr		DWORD ?
	sin_zero		BYTE 8 DUP(?)
sockaddr_in ENDS

sockaddr STRUCT
	sa_family		WORD ?
	sa_data			BYTE 14 DUP(?)
sockaddr ENDS

addrinfo STRUCT
	ai_flags		DWORD ?
	ai_family		DWORD ?
	ai_socktype		DWORD ?
	ai_protocol		DWORD ?
	size_t			DWORD ?
	ai_canonname	DWORD ?
	ai_addr			DWORD ?
	ai_next			DWORD ?
addrinfo ENDS

.data
; ************************* CONSTANTS DEFINED IN CPP FILES ******************************

; ------------------------------------ ws2def.h -----------------------------------------
AF_INET					= 2		; internetwork: UDP, TCP, etc. - IPv4
SOCK_STREAM				= 1		; stream socket (TCP)
INADDR_ANY				= 0h	; defined as ULONG, I'll use it as a DWORD
NI_MAXHOST				= 1025	; max size of FQDN
NI_MAXSERV				= 32	; max size of a service name

; ----------------------------------- WinSock2.h ----------------------------------------
INVALID_SOCKET			= -1	; the 2s comp of 0 (~0), because SOCKET is unsigned
SOCKET_ERROR			= -1	; synonymous to INVALID_SOCKET in this context
SOMAXCONN				= 7fffffffh		; maxinmum # of pending connections in queue

; --------------------------------- my constants ----------------------------------------
BUF_SIZE				= 4096	; the size of the buffer client sends data into
FAIL_WSAS				BYTE "Can't initialize winsock! Quitting... ",0
FAIL_SOCK				BYTE "Can't create a socket! Quitting... ",0
FAIL_RECV				BYTE "Error in recv(). Quitting... ",0
CONN_PORT				BYTE " connected on port ",0
HOST_GONE				BYTE "Client disconnected... ",0
VERSION					WORD 514d

; --------------------------------- my variables ----------------------------------------
wsData		WSADATA <>		; create a new wsData struct w/ default values
hint		sockaddr_in <>	; address structure
wsOk		DWORD ?			; 0 is winsock is initialized successfully
listening	DWORD ?			; socket "handle" that identifies the created socket
ipAddress	DWORD 7F000001h	; the ip address I will be using (loopback)
servPort	WORD 0F0D2h		; port 54000 IN BIG ENDIAN!!!
hints		addrinfo <>		; 
result		addrinfo <> 

; ***************************************************************************************

; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ ;
;																						;
;									-Program Logic-										;
;																						;
;		1. Initialize winsock (call WSAStartup)											;
;		2. Create a socket (call socket)												;
;		3. Bind the ip address and port to a socket (call bind)							;
;			a. Use localhost (127.0.0.1:5400)											;
;		4. Tell winsock the socket is a listening socket (call listen)					;
;		5. Wait for a client connection (call accept)									;
;		6. After client connects, get client info										;
;			a. client hostname															;
;			b. service name																;
;			c. display host info to console												;	
;		7. Close the listening socket (call closesocket)								;
;		8. While-loop to accept data from client (as long as they send)					;
;		9. Receive data from client (call recv)											;
;		10. If the client sends any data, echo it back to them							;
;		11. After the client disconnects, close the client socket (call closesocket)	;
;		12.	Clean up winsock															;
;																						;
; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ ;

.code 
main PROC

	; ------- Initialize winsock (call WSAStartup) -------
	lea eax, DWORD PTR wsData
	push eax
	movzx ecx, WORD PTR VERSION
	push ecx
	call WSAStartup@8 ; took out "DWORD PTR"
	mov DWORD PTR wsOk, eax
	
	; ------- Check if winsock was initialized successfully -------
	.IF wsOk != 0		
		mov edx, offset FAIL_WSAS
		call WriteString
		jmp end_it
	.ENDIF

	; ------- Create a listening socket -------
	push 0
	mov edx, SOCK_STREAM		; specify the TCP protocol
	push edx
	mov edx, AF_INET			; specify the IP family (v4)
	push edx
	call socket@12
	mov listening, eax

	; ------- Check if socket() returned a valid socket -------
	.IF listening == INVALID_SOCKET
		mov edx, offset FAIL_SOCK
		call WriteString
		call WSACleanup@0	; terminates use of ws2_32.dll on all threads
		jmp end_it
	.ENDIF

	; ------- Create the address structure to bind -------
	mov dx, AF_INET
	mov hint.sin_family, dx
	mov dx, servPort
	mov hint.sin_port, dx
	mov edx, INADDR_ANY
	mov hint.sin_addr, edx

	; ------- Bind the socket -------
	push 16			; sizeof(hint)
	lea eax, DWORD PTR hint
	push eax
	lea eax, DWORD PTR listening
	push eax
	call bind@12		; void function, nothing returned

	end_it:
		exit
main ENDP
end