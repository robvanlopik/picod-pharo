"
I am an announcement that is generated when a gpio pin has no activity for a certain amount of time.
My accessors adaptToFloat: 
#pinNr -- the pin raising the announcement  
#tick -- the time at which the announcement was detected by the daemon.
#levels -- the state of all 32 gpios coded in 32 bits

I am enabled by: 
PicodDriver>>setWatchdogOnPin:timeout:

the timeout starts counting after the first level change of the pin. It happens only once.
"
Class {
	#name : #PicodWatchdog,
	#superclass : #Announcement,
	#instVars : [
		'pinNr',
		'tick',
		'levels'
	],
	#category : #PicodDriver
}

{ #category : #accessing }
PicodWatchdog >> levels [
	^ levels
]

{ #category : #accessing }
PicodWatchdog >> levels: anObject [
	levels := anObject
]

{ #category : #accessing }
PicodWatchdog >> pinNr [
	^ pinNr
]

{ #category : #accessing }
PicodWatchdog >> pinNr: anObject [
	pinNr := anObject
]

{ #category : #accessing }
PicodWatchdog >> tick [
	^ tick
]

{ #category : #accessing }
PicodWatchdog >> tick: anObject [
	tick := anObject
]
