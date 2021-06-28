"
I am responsible for listening to the serial port for messages from the picod daemon on a Pico.

instance variables:

	announcer:		the announcer for all async events
	buffer:		the buffer being processed, received from the serial port
	lastLevels:		the latest pin levels reported (unsigned int, but we have only 29 gpio's)
	listenProcess:		the proess that reads from the serial port
	owner:		the PiodDriver that created me
	pinsToMonitor:		a bitmask of pins for which changes should be reported
	port:		the serial port
	running:		Boolean. If false, the listenProcess stops
	resultQueue: shared queue to put received asynchronous reults in, to be retrieved by driver
	statusCheck: if true the status of a result is checked and reported to the Transcript if not OK
	
In principle I only interact with my owner
The listen loop runs in a thread at lowIOPriority. Announcements are sent in another thread at userInterrupPriory
"
Class {
	#name : #PicodListener,
	#superclass : #Object,
	#instVars : [
		'listenProcess',
		'running',
		'lastLevels',
		'port',
		'announcer',
		'buffer',
		'owner',
		'pinsToMonitor',
		'resultQueue',
		'statusCheck'
	],
	#category : #PicodDriver
}

{ #category : #adding }
PicodListener >> addPinsToMonitor: aMask [
	pinsToMonitor := pinsToMonitor bitOr: aMask
]

{ #category : #accessing }
PicodListener >> announcer [
	^ announcer
]

{ #category : #accessing }
PicodListener >> announcer: anObject [
	announcer := anObject
]

{ #category : #'as yet unclassified' }
PicodListener >> findHeader [
 "looks for 16rFF followed by length and CRC
	if found within buffer it checks the CRC of the header
	and return"
	| length crc |

	(buffer at: 1) = 16rFF ifTrue: [ 
		length := buffer unsignedShortAt: 2 bigEndian: true.
		crc := owner hqxCRCOver: (buffer first: 3).
		crc = (buffer unsignedShortAt: 4 bigEndian: true) ifTrue: [ 
			"buffer hex trace. ' ' trace. length printString traceCr."
			^length ].
			].
		"at this point either we had no FF, or the checksum failed, 
		so wee move on to the next positionin the buffer"
		buffer := buffer allButFirst. 
		buffer size >= 5 ifFalse: [ 
			^0 "signal we need to read more" ].
		^self  findHeader
]

{ #category : #initialization }
PicodListener >> initialize [ 	
		super initialize.
		running := false.
		lastLevels := 0.
		announcer := Announcer new.
		pinsToMonitor := 0.
		resultQueue := SharedQueue new.
]

{ #category : #'as yet unclassified' }
PicodListener >> listen [
	"the main loop to listen for answers and events from the Pico"
	| data processingMessage messageLength crc|
	buffer := ByteArray new.
	processingMessage := false.
	
	[ running ] whileTrue: [ 
		data := port readByteArray.
		data size = 0 ifFalse: [ 
			"we got something"
			'read ' trace. data hex traceCr.
			buffer := buffer, data.
			buffer size >= 5 ifTrue: [ 
				processingMessage ifFalse: [ 
					messageLength := self findHeader. "> 5 means we found a message, else we need more data"
					messageLength > 0 ifTrue: [ processingMessage := true ]
					 ].
				processingMessage ifTrue: [ 
					buffer size >= messageLength ifTrue: [ 
						"first check crc"
						crc := owner hqxCRCOver: (buffer first: (messageLength - 2)).
						(crc = (buffer unsignedShortAt: (messageLength - 1) bigEndian: true) )
							ifTrue: [ buffer := buffer allButFirst: 5.
											self processMessage. 
											buffer := buffer allButFirst: (messageLength - 5)] 
							ifFalse: [ "crc error" 
									buffer hex trace. 'crc = ' trace. crc hex traceCr.
								buffer := buffer allButFirst: messageLength. 
											]. 
						
						 ].
					processingMessage := false. "is this in thee right place????"
					 ].
				].
			
		 ].
		5 milliSeconds wait.
	]

]

{ #category : #'as yet unclassified' }
PicodListener >> onPort: aSerialPort [
	port := aSerialPort
]

{ #category : #accessing }
PicodListener >> owner [
		^owner
]

{ #category : #accessing }
PicodListener >> owner: anObject [
	owner := anObject 
]

{ #category : #'as yet unclassified' }
PicodListener >> processAsync [
	"MSG_ASYNC was detected, meaninga change in uart, i2c, spi  
	this has been requested by #activateEvent:mode:count:"
]

{ #category : #'as yet unclassified' }
PicodListener >> processDirectReply [
	"the result will me put into a queue, resultQueue, te be retrieved
	 by the initiating request. Note that there can be more queues to differentiate the originating threads, but this is not implemented. yet."
	
	| length |
	length := buffer unsignedLongAt: 1 bigEndian: true.
	resultQueue nextPut: (buffer from: 3 to: length).
]

{ #category : #'as yet unclassified' }
PicodListener >> processLevelChanges [
	"a level change was detected, or a watchdog timeout
	the buffer can contain more 8-byte reports as indicated by 
	the length of the message (in the first two bytes of the buffer)"
	|  numberOfReports length |
	length := buffer unsignedShortAt: 1 bigEndian: true.
	numberOfReports := (length - 4) // 8.
	0 to: (numberOfReports - 1) do: [ :i | 
		self processLevelReport: (buffer copyFrom: (i * 8 + 5) to: (i * 8 + 12))]
	
]

{ #category : #'as yet unclassified' }
PicodListener >> processLevelReport: aReportBuffer [
	"we have 8 bytes describing levelchanges or watchdog timeout"
	| newLevels tick selectedPins |
	tick := aReportBuffer unsignedLongAt: 1 bigEndian: true.
	newLevels := aReportBuffer unsignedLongAt: 5 bigEndian: true.
	'level report ' trace. aReportBuffer  hex traceCr.
	(newLevels bitAt: 32) = 1 ifTrue: [ "we have watchdog announcemens"
		selectedPins := (pinsToMonitor bitAnd: newLevels).
		
			1 to: 30 do: [ :i | (selectedPins bitAt: i) = 1 ifTrue: [ 
				[announcer announce: (PicodWatchdog new 
					pinNr: (i - 1); tick: tick; levels: lastLevels; yourself) ] 
					forkAt: Processor userInterruptPriority   ] ]  ]    
			  
		ifFalse: [ "we have pin changes"
			selectedPins := (newLevels bitXor: lastLevels) bitAnd: pinsToMonitor  .
			lastLevels := newLevels .
			'monitor   ' trace. pinsToMonitor traceCr.
			'selected  ' trace. selectedPins hex traceCr.
			'newLevels ' trace. newLevels hex traceCr.
			1 to: 30 do: [ :i | (selectedPins bitAt: i) = 1 ifTrue: [ 
					[announcer announce: (PicodPinChange new 
					pinNr: (i - 1); tick: tick; newLevel: (newLevels bitAt: i); 
					levels: newLevels ; yourself) ] 
					forkAt: Processor userInterruptPriority ] ]
			
			  ].
	
]

{ #category : #'as yet unclassified' }
PicodListener >> processMessage [ 	
	"at this point we have a correct message that starts in the buffer
	the length is in the first two bytes
	the flags byte determines what to do with the message"
	| length flags request queue result|
	length := buffer unsignedShortAt: 1 bigEndian: true.
	flags := buffer at: 3.
	request := buffer at: 4.
	"request can be a request code, or one of
	MSG_GPIO_LEVELS(16rFB) MSG_DEBUG(16rFA) MSG_ERROR(16rF9) or MSG_ASYNC(16rF8)"
	request = 16rFB ifTrue: [ self processLevelChanges. ^self ].
	request = 16rFA ifTrue: [ 'debug ' trace. buffer hex traceCr. ^self ].
	request = 16rF9 ifTrue: [ 'error ' trace. buffer hex traceCr. ^self ].
	request = 16rF8 ifTrue: [ self processAsync. ^self ].
	"we still have the replies, direct or later."
	result := (PicodResult new
							requestCode: request;
							status: (buffer at: 5);
							dataBytes: (buffer copyFrom: 6 to: length);
							yourself).
	owner statusCheck ifTrue: [ result checkStatus ].
	((flags bitAt: 7) = 1) ifTrue: [ resultQueue nextPut: result]
		ifFalse: [ announcer announce: (PicodResultReady new result: result) ]
	
	
]

{ #category : #removing }
PicodListener >> removePinsToMonitor: aMask [
	pinsToMonitor := pinsToMonitor bitAnd: aMask bitInvert32
]

{ #category : #accessing }
PicodListener >> resultQueue [
	^ resultQueue
]

{ #category : #accessing }
PicodListener >> resultQueue: anObject [
	resultQueue := anObject
]

{ #category : #accessing }
PicodListener >> start [
	running := true.
	listenProcess := [ self listen ]
			 forkAt: Processor lowIOPriority named: 'Picod listener'
]

{ #category : #accessing }
PicodListener >> statusCheck [
	^ statusCheck
]

{ #category : #accessing }
PicodListener >> statusCheck: anObject [
	statusCheck := anObject
]

{ #category : #accessing }
PicodListener >> stop [ 	
	running := false.
]
