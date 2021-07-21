"
I am an announcement, made when an event happens. Events happen when something changes in an I2C, SPI or UAART channel
 --- not yet implemented ---
"
Class {
	#name : #PicodEvent,
	#superclass : #Announcement,
	#instVars : [
		'eventNr',
		'eventMode',
		'tick'
	],
	#category : #PicodDriver
}
