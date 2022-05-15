"
I represent the result of a request to the picod daemon.

I am either put into a queue to be used by the requester, or put into an PicodResultReady announcement.

I contain the requestCode, statusCode and dataBytes of the result.

#stattusText returns the text corresponding to the status code.
This is used in PicoDriver>>statusCheck. If this is true, the text is written to the transcript for ll transactions (only if non-zero).)

"
Class {
	#name : #PicodResult,
	#superclass : #Object,
	#instVars : [
		'requestCode',
		'status',
		'dataBytes'
	],
	#category : #PicodDriver
}

{ #category : #testing }
PicodResult >> checkStatus [
	"if status not OK, print status text to console"
		status = 0 ifTrue: [ ^nil ].
		self statusText traceCr .
]

{ #category : #accessing }
PicodResult >> dataBytes [
	^ dataBytes
]

{ #category : #accessing }
PicodResult >> dataBytes: anObject [
	dataBytes := anObject
]

{ #category : #printing }
PicodResult >> printOn: aStream [
	aStream
		nextPutAll: 'PicodResult ';
		nextPutAll: ' ';
		print:  self requestCode;
		nextPutAll:  ' ';
		nextPutAll: self statusText;
		nextPutAll: ' ';
		nextPutAll: dataBytes hex.
]

{ #category : #accessing }
PicodResult >> requestCode [
	^ requestCode
]

{ #category : #accessing }
PicodResult >> requestCode: anObject [
	requestCode := anObject
]

{ #category : #accessing }
PicodResult >> status [
	^ status
]

{ #category : #accessing }
PicodResult >> status: anObject [
	status := anObject
]

{ #category : #'accessing-testing' }
PicodResult >> statusText [
	"returns a string describing the status code"

	status = 0 ifTrue: [^'okay'].
	status = 1 ifTrue: [ ^'bad channel'].
	status = 2 ifTrue: [^'channel closed'].
	status = 3 ifTrue: [^'bad GPIO'].
	status = 4 ifTrue: [^'bad parameter'].
	status = 5 ifTrue: [^'bad write'].
	status = 6 ifTrue: [^'bad read'].
	status = 7 ifTrue: ['no reply expected'].
	status = 8 ifTrue: [^'GPIO already in use'].
	status = 9 ifTrue: [^'unknown command'].
	status = 10 ifTrue: [^'command timed out'].
	status = 11 ifTrue: [^'invalid command when master'].
	status = 12 ifTrue: [^'invalid command when slave'].
	status = 13 ifTrue: [^'invalid configuration item' ].
	^('unknown status code: ', status printString)
]
