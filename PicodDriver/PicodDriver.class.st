Class {
	#name : #PicodDriver,
	#superclass : #Object,
	#instVars : [
		'port'
	],
	#category : #PicodDriver
}

{ #category : #utilities }
PicodDriver >> commandPacket: aRequest [
	"transform aRequest, a ByteArray, into a packet ready to send.
	Includes calculating 2 CRcs. Packet:
	16rFF, total lenght (hibyte,lowbyte), crc1(h,b), request, crc2(h,b)
	lenght and crcs are stored Big-endian!
	"
	| length packet preamble crc |
	length := (aRequest size) + 7.
	preamble := ByteArray with: 16rFF with: (length // 256) with: (length \\ 256).
	crc := self hqxCRCOver: preamble.
	packet := preamble,
					(ByteArray with: (crc // 256) with: (crc \\ 256)),
					aRequest.
	crc := self hqxCRCOver: packet.
	^( packet,
		(ByteArray with: (crc // 256) with: (crc \\ 256))).
	
	
]

{ #category : #connection }
PicodDriver >> connectOnPort: aPortName [
	self connectOnPort: aPortName baudRate: 230400.
]

{ #category : #connection }
PicodDriver >> connectOnPort: portName baudRate: aNumber [
	
	self isConnected ifTrue: [^self ].
	port := SerialPort new baudRate: aNumber.
	port openPort: portName.
	
	self isConnected ifTrue: [ 
		self startListener.
		self setup ]
	
	
]

{ #category : #utilities }
PicodDriver >> digitalWrite: aGPIO value: oneOrZero [
	"write a zero or one to a GPIO pin 0-29"
	"CMD_GPIO_WRITE = 14 "
	| commandData  |
	
	commandData := ByteArray new: 8.
	commandData unsignedLongAt: 1 put: (1 << aGPIO) bigEndian: true.
	commandData unsignedLongAt: 5 put: (oneOrZero << aGPIO) bigEndian: true.
	self sendCommand: 14 flags: 0 data: commandData
	
	
]

{ #category : #crc }
PicodDriver >> hqxCRCOver: aByteArray [ 
 "calculate the XModem checksum
 see: https://crccalc.com/"
	| crc |
	crc := CRC new
		width: 16;
		polynome: 16r1021;
		registerFill: 0;
		reflectInput: false;
		reflectOutput: false;
		message: aByteArray;
		finallyXorWith: 0;
		yourself.
	^crc run. 
]

{ #category : #testing }
PicodDriver >> isConnected [
	^port notNil
]

{ #category : #utilities }
PicodDriver >> reset [
	"Resets the Pico (frees GPIO, close I2C, SPI, serial, PWM)"
	"RESET_PICO = 96"
	self sendCommand: 96 flags: 0 data: #() asByteArray
]

{ #category : #utilities }
PicodDriver >> sendCommand: aCommand flags: aFlagByte data: aByteArray [
	"prepare the request packet using commandPacket and send it
	the bytearray has to be correctly formatted by the sender"
	| length message|
	length := aByteArray size + 4.
	message := ByteArray with: (length // 256) with: (length \\ 256)
										with: aFlagByte with: aCommand.
	
	port nextPutAll: (self commandPacket: (message , aByteArray)) 
]

{ #category : #initialization }
PicodDriver >> setup [
 	
]

{ #category : #initialization }
PicodDriver >> startListener [

]
