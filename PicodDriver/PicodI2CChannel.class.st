"
I represent an I2C channel. On the PicoRP2040 there are two of me. with id's 0 and 1.
I get created by a call of i2cOpenChannel to the PicodDriver.
I hold the chosen gpio's for sda and scl.
And I hold a set of PicodI2CConnections that communicate with individual devices on my channel.
I can be closed by a call to PicodDriver>>i2cCloseChannel:  but only if my set of i2CConnections is empty.
"
Class {
	#name : #PicodI2CChannel,
	#superclass : #Object,
	#instVars : [
		'id',
		'sda',
		'scl',
		'i2cConnections'
	],
	#category : #PicodDriver
}

{ #category : #adding }
PicodI2CChannel >> addConnection: anI2CConnection [
	i2cConnections add: anI2CConnection
]

{ #category : #accessing }
PicodI2CChannel >> connections [
		^i2cConnections
]

{ #category : #testing }
PicodI2CChannel >> hasDevices [
	^i2cConnections notEmpty 
]

{ #category : #accessing }
PicodI2CChannel >> id [
	^ id
]

{ #category : #accessing }
PicodI2CChannel >> id: anObject [
	id := anObject
]

{ #category : #initialization }
PicodI2CChannel >> initialize [
		super initialize.
		i2cConnections := Set new
]

{ #category : #removing }
PicodI2CChannel >> removeConnection: anI2CConnection [
	"remove an i2c connection from this channel"
	i2cConnections remove: anI2CConnection.
]

{ #category : #accessing }
PicodI2CChannel >> scl [
	^ scl
]

{ #category : #accessing }
PicodI2CChannel >> scl: anObject [
	scl := anObject
]

{ #category : #accessing }
PicodI2CChannel >> sda [
	^ sda
]

{ #category : #accessing }
PicodI2CChannel >> sda: anObject [
	sda := anObject
]
