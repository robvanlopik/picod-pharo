"
I am an announcement that is triggered when the result of a request comes in, where the request has been done with the attribute async: true.
I have one attributes, the result containing requestCode, status and dataBytes.

"
Class {
	#name : #PicodResultReady,
	#superclass : #Announcement,
	#instVars : [
		'result'
	],
	#category : #PicodDriver
}

{ #category : #accessing }
PicodResultReady >> result [
	^ result
]

{ #category : #accessing }
PicodResultReady >> result: anObject [
	result := anObject
]
