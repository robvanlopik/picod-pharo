"
I am an announcement that is made when the level of a gpio changes.
I have the following accessors:
#pinNr -- the gpio id that changed 
#newLevel -- the new level of tha pin
#tick -- the microsecond clock tick when this happened (70 minute rolllover)
#levels -- all the pin's levels packed in 32 bits.

PicodDriver>>pinsTowatch: governs which pins can generate this announcement
"
Class {
	#name : #PicodPinChange,
	#superclass : #Announcement,
	#instVars : [
		'pinNr',
		'newLevel',
		'tick',
		'levels'
	],
	#category : #PicodDriver
}

{ #category : #accessing }
PicodPinChange >> levels [ 
		^levels
]

{ #category : #accessing }
PicodPinChange >> levels: aMask [
		levels := aMask
]

{ #category : #accessing }
PicodPinChange >> newLevel [
	^ newLevel
]

{ #category : #accessing }
PicodPinChange >> newLevel: anObject [
	newLevel := anObject
]

{ #category : #accessing }
PicodPinChange >> pinNr [
	^ pinNr
]

{ #category : #accessing }
PicodPinChange >> pinNr: anObject [
	pinNr := anObject
]

{ #category : #accessing }
PicodPinChange >> tick [
	^ tick
]

{ #category : #accessing }
PicodPinChange >> tick: anObject [
	tick := anObject
]
