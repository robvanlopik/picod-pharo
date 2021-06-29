Class {
	#name : #BaselineOfPicodDriver,
	#superclass : #BaselineOf,
	#category : #BaselineOfPicodDriver
}

{ #category : #baselines }
BaselineOfPicodDriver >> baseline: spec [
 	<baseline>
	spec
		for: #common 	
		do: [ 
			spec package: 'PicodDriver' ].
	
]
