; Client / Server implementation in Assembly
;
; Server component
;
; ***************************************************************************************
; Sources:
; - MS documentation at 	
;	https://docs.microsoft.com/en-us/windows/desktop/winsock/about-clients-and-servers
; - C++ disassembly
; ***************************************************************************************

; .686P
; .model flat				; Defined in SmallWin.inc in the project files ;
; .stack 4096

INCLUDE Irvine32.inc			; for output, Irvine functions

INCLUDELIB WS2_32				; For WinAPI functions 

EXTRN	accept@12:PROC
EXTRN	bind@12:PROC
EXTRN	closesocket@4:PROC
EXTRN	listen@8:PROC
EXTRN	recv@16:PROC
EXTRN	send@16:PROC
EXTRN	socket@12:PROC
EXTRN	WSAStartup@8:PROC
EXTRN	WSACleanup@0:PROC
EXTRN	WSAGetLastError@0:PROC
EXTRN	WriteString@0:PROC
EXTRN	WriteInt@0:PROC
EXTRN	getaddrinfo@16:PROC
EXTRN	freeaddrinfo@4:PROC
EXTRN	shutdown@8:PROC

; create a WSADATA struct, from WinSock2.h
WSADATA STRUCT 
	wVersion		WORD ?
	wHighVersion	WORD ?
	szDescription	BYTE 257 DUP(?)
	szSystemStatus	BYTE 129 DUP(?)
	iMaxSockets		WORD 0
	iMaxUdpDg		WORD 0
	lpVendorInfo	DWORD ?
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
WELCOME					BYTE "Welcome. Connect on localhost:36000. ",0
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
EXIT_MSG				BYTE "Thank you for using the server!",0
VERSION					WORD 514d
DEFAULT_PORT			BYTE "36000",0			; TCP port
DEFAULT_BUFLEN			DWORD 512d	
SD_SEND					DWORD 1d

; --------------------------------- my variables ----------------------------------------
wsData			WSADATA <>		; create a new wsData struct w/ default values
ListenSocket	DWORD -1		; listen on this socket
ClientSocket	DWORD -1		; respond to clients on this socket (per client basis)
hints			addrinfo <>		
result			DWORD 0
iResult			DWORD ?
iSendResult		DWORD ?			; return value from send()
recvbuf			BYTE "SERVER> ", 503 DUP(0)	; 512 bytes - 9 [SERVER> ]

; ***************************************************************************************

; $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ ;
;																						;
;									-Program Logic-										;
;																						;
;		1. Initialize winsock (call WSAStartup)											;
;		2. Create a socket (call socket)												;
;		3. Bind the ip address and port to a socket (call bind)							;
;			a. Use localhost (127.0.0.1:54000)											;
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
	; ------- Display Welcome -------
	mov edx, OFFSET WELCOME
	call WriteString
	call crlf

	; ------- Initialize winsock (call WSAStartup) -------
	lea eax, DWORD PTR wsData
	push eax
	movzx ecx, WORD PTR VERSION
	push ecx
	call WSAStartup@8 
	mov iResult, eax
	
	; ------- Check if winsock was initialized successfully -------
	.IF iResult != 0		
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
	lea eax, result
	push eax
	lea ecx, DWORD PTR hints
	push ecx
	mov ebx, OFFSET DEFAULT_PORT
	push ebx
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
	mov eax, result		; eax contains the location, 
	mov ecx, [eax+12]				; i.e. result->ai_family, etc
	push ecx
	mov ebx, result	
	mov edx, [ebx+8]
	push edx
	mov ecx, result			; repeated because correct eax is crucial
	mov eax, [ecx+4]
	push eax
	call socket@12
	mov DWORD PTR ListenSocket, eax		; holds the socket (essentially an id)

	; ------- Check if the listen socket is valid -------
	.IF ListenSocket == INVALID_SOCKET
		mov edx, OFFSET FAIL_SOCK
		call WriteString
		call WSAGetLastError@0
		mov eax, DWORD PTR result	
		push eax
		call freeaddrinfo@4			; release reserved addr / port
		call WSACleanup@0			; clean up instance
		jmp end_it
	.ENDIF

	; ------- Setup the TCP listening socket -------
	mov eax, result		; make sure eax is legit
	mov edx,  [eax+16]
	push edx
	mov eax, result		; make sure eax is legit
	mov ecx,  [eax+24]
	push ecx
	mov edx, DWORD PTR ListenSocket
	push edx
	call  bind@12
	mov iResult, eax

	; ------- Check if socket bound correctly -------
	.IF iResult == SOCKET_ERROR
		mov edx, OFFSET FAIL_BIND
		call WriteString
		call WSAGetLastError@0
		mov eax, DWORD PTR result
		push eax
		call freeaddrinfo@4			
		mov eax, DWORD PTR ListenSocket
		push eax
		call closesocket@4
		call WSACleanup@0
		jmp end_it
	.ENDIF

	; ------- Free dynamically-alloc addr info ------
	mov eax, DWORD PTR result		
	push eax
	call freeaddrinfo@4	

	; ------- Specify socket for listening -------
	mov ebx, SOMAXCONN ;2147483647    Or SOMAXCONN
	push ebx
	mov eax, DWORD PTR ListenSocket
	push eax
	call listen@8
	mov iResult, eax

	; ------- Check if designated properly -------
	.IF iResult == SOCKET_ERROR
		mov edx, OFFSET FAIL_LIST
		call WriteString
		call WSAGetLastError@0
		mov eax, DWORD PTR ListenSocket
		push eax
		call closesocket@4
		call WSACleanup@0		
		jmp end_it
	.ENDIF

	; ------- Accept a client socket -------
	push 0
	push 0
	mov eax, DWORD PTR ListenSocket
	push eax
	call accept@12
	mov ClientSocket, eax

	; ------- Check if client accepted -------
	.IF ClientSocket == INVALID_SOCKET
		mov edx, OFFSET FAIL_ACCP
		call WriteString
		call WSAGetLastError@0
		mov eax, DWORD PTR ListenSocket
		push eax
		call closesocket@4
		call WSACleanup@0
		jmp end_it
	.ENDIF

	; ------- Close listen socket (implies only one connection allowed) -------
	mov eax, DWORD PTR ListenSocket
	push eax
	call closesocket@4

	; ------- Receive until client disconnects -------
	.REPEAT
		; ---- receive data from client ----
		push 0
		mov eax, DWORD PTR DEFAULT_BUFLEN
		push eax
		lea ecx, DWORD PTR recvbuf+8		; where the buffer will be written to
		push ecx
		mov edx, DWORD PTR ClientSocket
		push edx
		call recv@16
		mov iResult, eax		; iResult contains 7 
		add iResult, 6			; size of [SERVER> ] - size of crlf

		; -- clear crlf -- 
		mov eax, iResult				; eax contains 5 if hello entered
		lea ebx, DWORD PTR recvbuf		; ebx contains &recvbuf
		add DWORD PTR ebx, eax			; ebx contains &(recvbuf + iResult)
		mov DWORD PTR [ebx], 0h			; clear crlf
		mov DWORD PTR [ebx+1], 0h

		call crlf

		.IF iResult > 0
			mov edx, OFFSET RECV_BYTE
			call WriteString
			sub iResult, 8
			mov eax, iResult
			call WriteInt
			call crlf

			; -- Echo the buffer back to the sender --
			push 0

			; - Add crlf at the end of buf -			; iResult = 5
			add iResult, 10			; iResult + SRVR> + crlf = iResult		
			mov eax, DWORD PTR iResult				
			push eax		; pushing 15
			sub eax, 2		; eax = 13, iResult = 15
			lea ebx, recvbuf
			add DWORD PTR ebx, eax		; &(recvbuf + 13)
			mov DWORD PTR [ebx], 0dh		; cr
			mov DWORD PTR [ebx+1], 0ah		; lf
			lea ecx, DWORD PTR recvbuf
			push ecx
			mov edx, DWORD PTR ClientSocket
			push edx
			call send@16
			mov iSendResult, eax

			.IF iSendResult == SOCKET_ERROR
				mov edx, OFFSET FAIL_SEND
				call WriteString
				call WSAGetLastError@0
				mov eax, DWORD PTR ClientSocket
				push eax
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
			mov eax, DWORD PTR ClientSocket
			push eax
			call closesocket@4
			call WSACleanup@0
			jmp end_it

		.ENDIF
	.UNTIL iResult <= 0

	; ------- Shut down the connection -------
	mov eax, SD_SEND
	push eax
	mov ebx, DWORD PTR ClientSocket
	push ebx
	call shutdown@8
	mov iResult, eax

	; ------- Check if clean shutdown -------
	.IF iResult == SOCKET_ERROR
		mov edx, OFFSET FAIL_SHUT
		call WriteString
		call WSAGetLastError@0
		mov eax, DWORD PTR ClientSocket
		push eax
		call closesocket@4
		call WSACleanup@0
		jmp end_it
	.ENDIF

	; ------- Clean up -------
	mov eax, DWORD PTR ClientSocket
	push eax
	call closesocket@4
	call WSACleanup@0

	end_it:
		exit
main ENDP
end