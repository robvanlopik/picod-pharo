Class {
	#name : #BaselineOfPicodDriver,
	#superclass : #BaselineOf,
	#category : #BaselineOfPicodDriver
}

{ #category : #baseline }
BaselineOfPicodDriver >> baseline: spec [

	<baseline>
	spec for: #common do: [ 
		self declareSerialPortOn: spec.

		spec package: 'PicodDriver' ]
]

{ #category : #'external projects' }
BaselineOfPicodDriver >> declareSerialPortOn: spec [

	spec
		baseline: 'SerialPort'
		with: [ spec repository: 'github://robvanlopik/SerialPort/src:main' ]
]
