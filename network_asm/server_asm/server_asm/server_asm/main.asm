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
EXTRN	WSAGetLastError@0:PROC
EXTRN	getnameinfo@28:PROC
EXTRN	inet_ntop@16:PROC
EXTRN	memset:PROC
EXTRN	WriteString@0:PROC
EXTRN	WriteInt@0:PROC
EXTRN	getaddrinfo@16:PROC
EXTRN	freeaddrinfo@4:PROC
EXTRN	shutdown@8:PROC

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
	ai_flags		DWORD 0
	ai_family		DWORD 0
	ai_socktype		DWORD 0
	ai_protocol		DWORD 0
	size_t			DWORD 0
	ai_canonname	DWORD 0
	ai_addr			DWORD 0
	ai_next			DWORD 0
addrinfo ENDS

.data
; ************************* CONSTANTS DEFINED IN CPP FILES ******************************

; ------------------------------------ ws2def.h -----------------------------------------
AF_INET					= 2		; internetwork: UDP, TCP, etc. - IPv4
SOCK_STREAM				= 1		; stream socket 
IPPROTO_TCP				= 6		; use TCP 
AI_PASSIVE				= 1		; Socket addr will be used in bind() call
INADDR_ANY				= 0h	; defined as ULONG, I'll use it as a DWORD
NI_MAXHOST				= 1025	; max size of FQDN
NI_MAXSERV				= 32	; max size of a service name

; ----------------------------------- WinSock2.h ----------------------------------------
INVALID_SOCKET			= -1	; the 2s comp of 0 (~0), because SOCKET is unsigned
SOCKET_ERROR			= -1	; synonymous to INVALID_SOCKET in this context
SOMAXCONN				= 7fffffffh		; maxinmum # of pending connections in queue
NULL					= 0		; as defined in vcruntime.h

; --------------------------------- my constants ----------------------------------------
BUF_SIZE				= 4096	; the size of the buffer client sends data into
FAIL_WSAS				BYTE "Can't initialize winsock! Quitting... ",0
FAIL_RESO				BYTE "Can't resolve server address and port! Quitting... ",0
FAIL_SOCK				BYTE "Can't create socket! ERROR: ",0
FAIL_BIND				BYTE "Can't bind the socket! ERROR: ",0
FAIL_LIST				BYTE "Can't initialize socket for listening! ERROR: ",0
FAIL_ACCP				BYTE "Can't accept client connection! ERROR: ",0
FAIL_SEND				BYTE "Can't send back to client! ERROR: ",0
FAIL_RECV				BYTE "Can't recv(), ERROR: ",0
RECV_BYTE				BYTE "Bytes received: ",0
SENT_BYTE				BYTE "Bytes sent: ",0
CONN_CLSE				BYTE "Connection closing... ",0
CONN_PORT				BYTE " connected on port ",0
HOST_GONE				BYTE "Client disconnected... ",0
FAIL_SHUT				BYTE "Shutdown failed with error: ",0
VERSION					WORD 514d
DEFAULT_PORT			BYTE "54000",0
DEFAULT_BUFLEN			DWORD 512d
SD_SEND					DWORD 1d

; --------------------------------- my variables ----------------------------------------
wsData			WSADATA <>		; create a new wsData struct w/ default values
wsOk			DWORD ?			; 0 is winsock is initialized successfully
ListenSocket	DWORD -1		; listen on this socket
ClientSocket	DWORD -1		; respond to clients on this socket (per client basis)
ipAddress		DWORD 7F000001h	; the ip address I will be using (loopback)
servPort		WORD 0F0D2h		; port 54000 IN BIG ENDIAN!!!
hints			addrinfo <>		
result			addrinfo <> 
iResult			DWORD ?
iSendResult		DWORD ?			; return value from send()
recvbuf			BYTE 512 DUP(?)	; buffer client sends messages into

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
	call WSAStartup@8 
	mov DWORD PTR wsOk, eax
	
	; ------- Check if winsock was initialized successfully -------
	.IF wsOk != 0		
		mov edx, OFFSET FAIL_WSAS
		call WriteString
		jmp end_it
	.ENDIF

	; ------- Zeroed out memory at init -------

	; ------- Set up hints structure -------
	mov hints.ai_family, AF_INET
	mov hints.ai_socktype, SOCK_STREAM
	mov hints.ai_protocol, IPPROTO_TCP
	mov hints.ai_flags, AI_PASSIVE

	; ------- Resolve the server addr / port ------
	lea edx, DWORD PTR result
	push edx
	lea edx, DWORD PTR hints
	push edx
	push OFFSET DEFAULT_PORT
	push 0
	call getaddrinfo@16
	mov iResult, eax

	; ------- Check if addr / port resolved ------
	.IF iResult != 0
		mov edx, OFFSET FAIL_RESO
		call WriteString
		call WSACleanup@0
		jmp end_it
	.ENDIF

	; ------- Create a listen socket for clients to connect to -------
	mov eax, DWORD PTR result		; eax contains the location, 
	mov edx, [eax+12]				; i.e. result->ai_family, etc
	push edx
	mov edx, [eax+8]
	push edx
	mov edx, [eax+4]
	push edx
	call socket@12
	mov ListenSocket, eax		; holds the socket (an identifier)

	; ------- Check if the listen socket is valid -------
	.IF ListenSocket == INVALID_SOCKET
		mov edx, OFFSET FAIL_SOCK
		call WriteString
		call WSAGetLastError@0
		push DWORD PTR result		
		call freeaddrinfo@4			; release reserved addr / port
		call WSACleanup@0			; clean up instance
		jmp end_it
	.ENDIF

	; ------- Setup the TCP listening socket -------
	mov eax, DWORD PTR result		; make sure eax is legit
	mov edx, [eax+16]
	push edx
	mov edx, [eax+24]
	push edx
	mov edx, ListenSocket
	push edx
	call bind@12
	mov iResult, eax

	; ------- Check if socket bound correctly -------
	.IF iResult == SOCKET_ERROR
		mov edx, OFFSET FAIL_BIND
		call WriteString
		call WSAGetLastError@0
		push DWORD PTR result		
		call freeaddrinfo@4			
		push ListenSocket
		call closesocket@4			
		jmp end_it
	.ENDIF

	; ------- Free dynamically-alloc addr info ------
	push DWORD PTR result		
	call freeaddrinfo@4	

	; ------- Specify socket for listening -------
	push SOMAXCONN
	push ListenSocket
	call listen@8
	mov iResult, eax

	; ------- Check if designated properly -------
	.IF iResult == SOCKET_ERROR
		mov edx, OFFSET FAIL_LIST
		call WriteString
		call WSAGetLastError@0
		push ListenSocket
		call closesocket@4
		call WSACleanup@0		
		jmp end_it
	.ENDIF

	; ------- Accept a client socket -------
	push NULL
	push NULL
	push ListenSocket
	call accept@12
	mov ClientSocket, eax

	; ------- Check if client accepted -------
	.IF ClientSocket == INVALID_SOCKET
		mov edx, OFFSET FAIL_ACCP
		call WriteString
		call WSAGetLastError@0
		push ListenSocket
		call closesocket@4
		call WSACleanup@0
		jmp end_it
	.ENDIF

	; ------- Close listen socket (implies only one connection allowed) -------
	push ListenSocket
	call closesocket@4

	; ------- Receive until client disconnects -------
	.REPEAT
		; ---- receive data from client ----
		push 0
		push DEFAULT_BUFLEN
		push DWORD PTR recvbuf
		push ClientSocket
		call recv@16

		.IF iResult > 0
			mov edx, OFFSET RECV_BYTE
			call WriteString
			mov eax, iResult
			call WriteInt
			call crlf

			; -- Echo the buffer back to the sender --
			push 0
			push iResult
			push DWORD PTR recvbuf
			push ClientSocket
			call send@16
			mov iSendResult, eax

			.IF iSendResult == SOCKET_ERROR
				mov edx, OFFSET FAIL_SEND
				call WriteString
				call WSAGetLastError@0
				push ClientSocket
				call closesocket@4
				call WSACleanup@0
				jmp end_it
			.ENDIF

			mov edx, OFFSET SENT_BYTE
			call WriteString
			mov eax, iSendResult
			call WriteInt
			call crlf

		.ELSEIF iResult == 0
			mov edx, OFFSET CONN_CLSE
			call WriteString
			jmp end_it

		.ELSE
			mov edx, OFFSET FAIL_RECV
			call WriteString
			call WSAGetLastError@0
			push ClientSocket
			call closesocket@4
			call WSACleanup@0
			jmp end_it

		.ENDIF
	.UNTIL iResult <= 0

	; ------- Shut down the connection -------
	push SD_SEND
	push ClientSocket
	call shutdown@8
	mov iResult, eax

	; ------- Check if clean shutdown -------
	.IF iResult == SOCKET_ERROR
		mov edx, OFFSET FAIL_SHUT
		call WriteString
		call WSAGetLastError@0
		push ClientSocket
		call closesocket@4
		call WSACleanup@0
		jmp end_it
	.ENDIF

	; ------- Clean up -------
	push ClientSocket
	call closesocket@4
	call WSACleanup@0

	end_it:
		exit
main ENDP
end