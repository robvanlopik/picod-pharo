"
I represent the I2C connection to a single device; I am characterised by the i2c channel I m on, and the bus address of my device.
I can write and read bytes, words and block to a device, directly or pointed to by a register.
Word operations are little-endian, unless specified otherwise.

I am listed in my PicodI2CChannel's list of connections.
"
Class {
	#name : #PicodI2CConnection,
	#superclass : #Object,
	#instVars : [
		'channelNr',
		'picodDriver',
		'i2cAddress'
	],
	#category : #PicodDriver
}

{ #category : #accessing }
PicodI2CConnection >> channelNr [
	^ channelNr
]

{ #category : #accessing }
PicodI2CConnection >> channelNr: anObject [
	channelNr := anObject
]

{ #category : #'initialize-release' }
PicodI2CConnection >> close [ 
	"deregister at the picodDriver and make myself unusable"
		
		picodDriver i2cRemoveConnection: self.
		channelNr := nil.
]

{ #category : #accessing }
PicodI2CConnection >> i2cAddress [
	^ i2cAddress
]

{ #category : #accessing }
PicodI2CConnection >> i2cAddress: anObject [
	i2cAddress := anObject
]

{ #category : #accessing }
PicodI2CConnection >> picodDriver [
	^ picodDriver
]

{ #category : #accessing }
PicodI2CConnection >> picodDriver: anObject [
	picodDriver := anObject
]

{ #category : #accessing }
PicodI2CConnection >> read8BitsAt: anInteger [

	^ self readByteAt: anInteger
]

{ #category : #reading }
PicodI2CConnection >> readByteAt: aRegister [
	picodDriver i2cWrite: channelNr  address: i2cAddress 
	  data: aRegister asByteArray  noStop: true timeOut: 0.1 wait: true.
	^(picodDriver i2cRead: channelNr address: i2cAddress count: 1 ) first
]

{ #category : #reading }
PicodI2CConnection >> readDataBlock: count At: aRegister [
	picodDriver i2cWrite: channelNr  address: i2cAddress 
	  data: aRegister asByteArray  noStop: true timeOut: 0.1 wait: true.
	^(picodDriver i2cRead: channelNr address: i2cAddress count: count ) dataBytes
]

{ #category : #reading }
PicodI2CConnection >> readWordAt: aRegister [
	picodDriver i2cWrite: channelNr  address: i2cAddress 
	  data: aRegister asByteArray  noStop: true timeOut: 0.1 wait: true.
	^(picodDriver i2cRead: channelNr address: i2cAddress count: 2 ) unsignedShortAt: 1
]

{ #category : #reading }
PicodI2CConnection >> readWordBigAndianAt: aRegister [
	picodDriver i2cWrite: channelNr  address: i2cAddress 
	  data: aRegister asByteArray  noStop: true timeOut: 0.1 wait: true.
	^(picodDriver i2cRead: channelNr address: i2cAddress count: 2 ) 
		unsignedShortAt: 1 bigEndian: true
]

{ #category : #accessing }
PicodI2CConnection >> write8BitsAt: anInteger data: anInteger2 [ 
	self writeByteAt: anInteger data: anInteger2
]

{ #category : #writing }
PicodI2CConnection >> writeByteAt: register data: aByte [
	| payLoad |
	payLoad := ByteArray with: register with: aByte.
	picodDriver i2cWrite: channelNr address: i2cAddress  data: payLoad
			 noStop: false timeOut: 0.1  wait: true.
]

{ #category : #writing }
PicodI2CConnection >> writeByteAt: register value: aByte [
	| payLoad |
	payLoad := ByteArray with: register with: aByte.
	picodDriver i2cWrite: channelNr address: i2cAddress  data: payLoad
			 noStop: false timeOut: 0.1  wait: true.
]

{ #category : #writing }
PicodI2CConnection >> writeDataBlock: aByteArray at: aRegister [
	| payLoad |
	payLoad := aRegister asByteArray, aByteArray.
	picodDriver i2cWrite: channelNr address: i2cAddress  data: payLoad
			 noStop: false timeOut: 0.1  wait: true.
]

{ #category : #writing }
PicodI2CConnection >> writeWordAt: register data: aWord [
	| payLoad |
	payLoad := ByteArray with: register with: (aWord \\ 256) with: (aWord // 256).
	picodDriver i2cWrite: channelNr address: i2cAddress  data: payLoad
			 noStop: false timeOut: 0.1  wait: true.
]

{ #category : #writing }
PicodI2CConnection >> writeWordBigEndianAt: register data: aWord [
	| payLoad |
	payLoad := ByteArray with: register with: (aWord // 256) with: (aWord \\ 256).
	picodDriver i2cWrite: channelNr address: i2cAddress  data: payLoad
			 noStop: false timeOut: 0.1  wait: true.
]
