"
I am a driver for the picod daemon running on an Raspberry pico microprocessor.
My serial communication is 8 bits and protected by XModem CRC-16 cheksums.

I accept commands to be send to the Pico, to manipulate gpio's , eseentially on/off, pwm , servos or adc.

I also support higher level protocols like i2c, uart and spi.

Listening for answer is done by a PiocListener, that i started. I can wait for an anser, or simply continue, in which case the PicodListener will generate an announcement.

I am started with 
```pico := PicodDriver new connectOnPort: 'COM3' (baudrate: 230400)


For the Collaborators Part: State my main collaborators and one line about how I interact with them. 

Public API and Key Messages

- message one   
- message two 
- (for bonus points) how to create instances.

   One simple example is simply gorgeous.
 
Internal Representation and Key Implementation Points.

    Instance Variables
	listener:		<Object>
	port:		<Object>


    Implementation Points
"
Class {
	#name : #PicodDriver,
	#superclass : #Object,
	#instVars : [
		'port',
		'listener',
		'i2cChannels',
		'statusCheck'
	],
	#category : #PicodDriver
}

{ #category : #'analog pins' }
PicodDriver >> analogClose: channel [
	"Closes an ADC channel and frees any associated GPIO"
	"ADC_CLOSE = 41"
	self sendCommand: 41 flags: 0 data: (ByteArray with: channel)
]

{ #category : #'analog pins' }
PicodDriver >> analogRead: channel [
	"read an analog channel; returns 0..4095
	channels 0-3 correspond to GPIO 26..29
	channel 3 is connected to a voltage divider to measure VSYS
	channel 4 is in internal temperature sensor
	code CMD_ADC_READ = 40"
	
	^self analogRead: channel wait: true
]

{ #category : #'analog pins' }
PicodDriver >> analogRead: channel wait: bool [
	"read an analog channel; returns 0..4095
	channels 0-3 correspond to GPIO 26..29
	channel 3 is connected to a voltage divider to measure VSYS
	channel 4 is in internal temperature sensor
	code CMD_ADC_READ = 40"
	| flag result|
	flag := 16r80.
	bool ifTrue: [ flag := 16r40 ].
	
	result := self sendCommand: 40 flags: flag data: channel asByteArray .
	bool ifFalse: [ ^nil ].
	"dataBytes contains the channel in its first byte"
	^(result dataBytes unsignedShortAt: 2 bigEndian: true). "shoulduse a message to result"
]

{ #category : #'digital pins' }
PicodDriver >> closeGpio: aPin [

	"close a single GPIO
	CMD_GPIO_CLOSE = 11"

	| mask dataBytes |
	mask := 1 << (aPin id).
	dataBytes := ByteArray new: 4.
	dataBytes unsignedLongAt: 1 put: mask bigEndian: true.
	self sendCommand: 11 flags: 0 data: dataBytes
]

{ #category : #'digital pins' }
PicodDriver >> closeGpios: aGpioList [
	"close a list of GPIO's
	CMD_GPIO_CLOSE = 11"
	| mask dataBytes |
	mask := 0.
	aGpioList do: [  :number | mask := mask bitOr: (1 << number) ].
	dataBytes := ByteArray new: 4.
	dataBytes unsignedLongAt: 1 put: mask bigEndian:true.
	self sendCommand: 11 flags: 0 data: dataBytes.
]

{ #category : #utilities }
PicodDriver >> commandPacket: aRequest [
	"transform aRequest, a ByteArray, into a packet ready to send.
	Includes calculating 2 CRcs. Packet:
	16rFF, total lenght (hibyte,lowbyte), crc1(h,b), request, crc2(h,b)
	lenght and crcs are stored Big-endian!
	"
	| length packet preamble crc |
	length := (aRequest size) + 7.
	preamble := ByteArray with: 16rFF with: (length // 256) with: (length \\ 256).
	crc := self hqxCRCOver: preamble.
	packet := preamble,
					(ByteArray with: (crc // 256) with: (crc \\ 256)),
					aRequest.
	crc := self hqxCRCOver: packet.
	^( packet,
		(ByteArray with: (crc // 256) with: (crc \\ 256))).
	
	
]

{ #category : #connection }
PicodDriver >> connectOnPort: aPortName [
	self connectOnPort: aPortName baudRate: 230400.
]

{ #category : #connection }
PicodDriver >> connectOnPort: portName baudRate: aNumber [
	
	self isConnected ifTrue: [^self ].
	port := SerialPort new baudRate: aNumber.
	port openPort: portName.
	
	self isConnected ifTrue: [ 
		self startListener.
		self setup ]
	
	
]

{ #category : #utilities }
PicodDriver >> daemonVersion [ 
	"return the daemon version, a dotted quad"
	"command PD_VERSION = 99"
	^(self sendCommand: 99 flags: 16r40 data: #() asByteArray) dataBytes

	
]

{ #category : #'digital pins' }
PicodDriver >> digitalRead: aPin [
	"read a single gpio pin"
	^(self digitalReadAll bitAt: aPin)
]

{ #category : #'digital pins' }
PicodDriver >> digitalReadAll [
	"read bitmask of state of all gpios
	code GPIO_READ = 13"
	| result |
	result := self sendCommand: 13 flags: 16r40 data: #() asByteArray.
	^(result dataBytes unsignedLongAt: 1 bigEndian: true)
]

{ #category : #'digital pins' }
PicodDriver >> digitalWrite: aGPIO value: oneOrZero [
	"write a zero or one to a GPIO pin 0-29"
	"CMD_GPIO_WRITE = 14 "
	| commandData  |
	
	commandData := ByteArray new: 8.
	commandData unsignedLongAt: 1 put: (1 << aGPIO) bigEndian: true.
	commandData unsignedLongAt: 5 put: (oneOrZero << aGPIO) bigEndian: true.
	self sendCommand: 14 flags: 0 data: commandData
	
	
]

{ #category : #'digital pins' }
PicodDriver >> digitalwrite: aPinList values: aValueList [
]

{ #category : #connection }
PicodDriver >> disconnect [ 
	self isConnected ifTrue: [ 
		self stopListener.
		port close.
		port := nil ]
	
]

{ #category : #'as yet unclassified' }
PicodDriver >> getFunctions [

	"return a ByteArray with the current function of all pins. 
	Each element can have a 4 bit value
	0000 - FUNC_XIP
	0001 - FUNC_SPI
	0010 - FUNC_UART
	0011 - FUNC_I2C
	0100 - FUNC_PWM
	0101 - FUNC_SIOT
	0101 - FUNC_GPIO (alias for SIO)
	0110 - FUNC_PIO0
	0111 - FUNC_PIO1
	1000 - FUNC_GPCK
	1001 - FUNC_USB
	1111 - FUNC_NULL
	command FUNCTION_GET = 26
	"

	| result series |
	result := self sendCommand: 26 flags: 16r40 data: #(  ) asByteArray.
	series := result dataBytes
		          groupsOf: 4
		          atATimeCollect: [ :block | block reverse ].
	result := ByteArray new: 32.
	series flattened withIndexDo: [ :byte :i | 
		result at: (2 * i - 1) put: (byte bitAnd: 16r0F).
		result at: (2 * i) put: (byte bitAnd: 16rF0) >> 4 ].
	^ result
]

{ #category : #crc }
PicodDriver >> hqxCRCOver: aByteArray [ 
 "calculate the XModem checksum
 see: https://crccalc.com/"
	| crc |
	crc := CRC new
		width: 16;
		polynome: 16r1021;
		registerFill: 0;
		reflectInput: false;
		reflectOutput: false;
		message: aByteArray;
		finallyXorWith: 0;
		yourself.
	^crc run. 
]

{ #category : #i2c }
PicodDriver >> i2cCloseChannel: channel [
	"close the channel, but only if no i2c connections left
	CODE_I2C_CLOSE = 51"
	(i2cChannels at: (channel + 1)) hasDevices ifTrue: [ ^self error: 'channel still has connections' ]. 
	self sendCommand: 51 flags: 0  data: channel asByteArray.
	i2cChannels at: (channel + 1) put: nil
	
]

{ #category : #i2c }
PicodDriver >> i2cCloseChannelForced: channel [
	"first close connections then close channel"
	(i2cChannels at: (channel + 1)) connections do: [ :conn | conn close ].
	self i2cCloseChannel: channel
]

{ #category : #i2c }
PicodDriver >> i2cOpenChannel: channel sda: gpio1 scl: gpio2 baudRate: number [
	"Opens an I2C channel (master or slave).
	channel:= the channel to open (0 or 1).
             sda:= the GPIO to use for the I2C data.
                   channel 0: one of 0, 4, 8, 12, 16, 20, 24, 28.
                   channel 1: one of 2, 6, 10, 14, 18, 22, 26.
             scl:= the GPIO to use for the I2C clock.
                   channel 0: one of 1, 5, 9, 13, 17, 21, 25, 29.
                   channel 1: one of 3, 7, 11, 15, 19, 23, 27.
            baud:= the baud rate in bits per second (default 100000).
      slave_addr:= the slave address if a slave (0 is master).

      Returns a tuple of status and the set baud rate."
	"CMD_I2C_OPEN = 50"
	| result buffer |
	(i2cChannels at: (channel + 1)) ifNotNil: [  self error: 'channel already open' ].
	buffer := ByteArray new: 8.
	buffer unsignedLongAt: 1 put: number bigEndian: true.
	buffer at: 5 put: channel.
	buffer at: 6 put: gpio1.
	buffer at: 7 put: gpio2.
	buffer at: 8 put: 0.
	result := self sendCommand: 50 flags: 16r40 data: buffer.
	(result status = 0) ifTrue: [ i2cChannels at: (channel + 1) put: 
				 (PicodI2CChannel new
					id: channel;
					sda: gpio1;
					scl: gpio2 ;
					yourself) ].
	^result status

]

{ #category : #i2c }
PicodDriver >> i2cOpenConnectionOn: channel i2cAddress: i2cAddress [
	"give access to an i2c device with the specified address,
	connected to the pins specified in the i2c channel"
	"we should first check whether the specified channel has been opened"
	| connection |
	(i2cChannels at: (channel + 1)) ifNil: [ ^self error: 'channel not open' ].
	connection := PicodI2CConnection new channelNr: channel; 
				picodDriver: self; i2cAddress: i2cAddress;  yourself.
	(i2cChannels at: (channel + 1)) addConnection: connection.
	^connection
]

{ #category : #i2c }
PicodDriver >> i2cRead: channel  address: i2cAddres count: aNumber [
	"simplified i2cRead with noStop=False, timeout=0.1 and wait=true
	Note: timeout is not 1 like in Python, because #sendCommand only waits 100 milliseconds
	for an answer"
	^self i2cRead: channel address: i2cAddres  count: aNumber  noStop: false  timeOut: 0.1  wait: true 
]

{ #category : #i2c }
PicodDriver >> i2cRead: channel address: i2cAddrress count: aNumber noStop: aBool timeOut: seconds wait: aBool2 [
	"Returns count bytes from an address on an I2C channel.

      channel:= the channel (0 or 1).
         addr:= the I2C address of the device to read.
        count:= the number of bytes to read.
       nostop:= set to True for no stop condition.
      timeout:= how long to wait in seconds for the call to complete.

      A tuple of status and a bytearray containing the read
      bytes is returned."
	"CMD_I2C_READ = 52 "
	| result requestBuffer flag stop|
	flag := 16r80.
	aBool2 ifTrue: [ flag := 16r40 ].
	stop := 0.
	aBool ifTrue: [ stop := 1 ].
	requestBuffer := ByteArray new: 9.
		requestBuffer unsignedLongAt: 1 put: ((seconds * 1000000) rounded)  bigEndian: true;
			unsignedShortAt: 5 put: aNumber  bigEndian: true;
			at: 7 put: channel;
			at: 8 put: i2cAddrress ;
			at: 9 put: stop.
	result := self sendCommand: 52 flags: flag data: requestBuffer .
	aBool2 ifFalse: [ ^nil ].
	^result dataBytes 
	
]

{ #category : #i2c }
PicodDriver >> i2cRemoveConnection: anI2CConnection [
	"remove the connection from its channel"
	(i2cChannels at: ((anI2CConnection channelNr) + 1)) removeConnection: anI2CConnection 
	
]

{ #category : #i2c }
PicodDriver >> i2cWrite: channel address: i2cAddress data: dataBytes noStop: aBoolean timeOut: seconds wait: aBoolean2 [
  "    Writes data to an address on an I2C channel.

      channel:= the channel (0 or 1).
         addr:= the I2C address of the device to write.
         data:= the bytes to write.
       nostop:= set to True for no stop condition.
      timeout:= how long to wait in seconds for the call to complete.

      If OK returns 0, otherwise returns a non-zero status code.
	CMD_I2C_WRITE = 53"
	| result requestBuffer flag stop length|
	flag := 16r80.
	aBoolean2 ifTrue: [ flag := 16r40 ].
	stop := 0.
	aBoolean ifTrue: [ stop := 1 ].
	length := dataBytes size.
	requestBuffer := ByteArray new: 9.
	requestBuffer unsignedLongAt: 1 put: ((seconds * 1000000) rounded)  bigEndian: true;
			unsignedShortAt: 5 put: length  bigEndian: true;
			at: 7 put: channel;
			at: 8 put: i2cAddress ;
			at: 9 put: stop.
	requestBuffer := requestBuffer , dataBytes.
	result := self sendCommand: 53 flags: flag data: requestBuffer .
	aBoolean2 ifFalse: [ ^nil ].
	^result status
]

{ #category : #testing }
PicodDriver >> isConnected [
	^port notNil
]

{ #category : #misc }
PicodDriver >> millisFromT1: tick1 toT2: tick2 [
	"uniform method to get the time in milliseconds between two timestamps
	take care of clock rollover"
	| diff |
	diff := tick2 - tick1.
	(diff > 0) ifTrue: [ ^diff/1000.0 ].
	^(diff + (1 << 32))/1000.0
]

{ #category : #'digital pins' }
PicodDriver >> openGpios: aPinList [
	"open Gpios in the list. It is not clear in which cases this is necessary,
	 but a pin must be open to change its pullup/down resistor
	CMD_GPIO_OPEN = 10"
	| pinMask dataBytes |
	dataBytes := ByteArray new: 4.
	pinMask := 0.
	aPinList do: [ :pin | pinMask := pinMask bitOr: (1 << pin)].
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	^self sendCommand: 10 flags: 16r40 data: dataBytes
	
]

{ #category : #'event processing' }
PicodDriver >> pinsToUnWatch: aList [
	"input a list of GPIO numbers to stop watching.
	CMD_ALERT_SELECT = 32"
	| mask dataBytes|
	mask:= 0.
	aList do: [ :pin | mask:= mask bitOr: (1 << pin) ].
	dataBytes := ByteArray new: 8.
	dataBytes unsignedLongAt: 1 put: mask bigEndian: true.
	dataBytes unsignedLongAt: 5 put: 0 bigEndian: true.
	self sendCommand: 32 flags: 0 data: dataBytes.
	listener removePinsToMonitor: mask.
]

{ #category : #'event processing' }
PicodDriver >> pinsToWatch: aList [
	"input a list of GPIO numbers to watch. Use #pinsToUnwatch to undo.
	CMD_ALERT_SELECT = 32"
	| mask dataBytes|
	mask:= 0.
	aList do: [ :pin | mask:= mask bitOr: (1 << pin) ].
	dataBytes := ByteArray new: 8.
	dataBytes unsignedLongAt: 1 put: mask bigEndian: true.
	dataBytes unsignedLongAt: 5 put: mask bigEndian: true.
	self sendCommand: 32 flags: 0 data: dataBytes.
	listener addPinsToMonitor: mask.
]

{ #category : #pullupdown }
PicodDriver >> pullForPin: aPin [
	"get the pull state: 0 = none, 1 = down, 2 = up, 3 = both"
	"CMD_PULLS_GET = 21"
	| result pulls0to15 pulls16to31 |
	result := self sendCommand: 21 flags: 16r40 data: #().
	pulls0to15 := result dataBytes unsignedLongAt: 1 bigEndian: true.
	pulls16to31 := result dataBytes unsignedLongAt: 5 bigEndian: true.
	aPin < 16 ifTrue: [^(pulls0to15 >> (aPin * 2)) bitAnd: 2r11 ].
	^(pulls16to31 >> ((aPin - 16) * 2)) bitAnd: 2r11
]

{ #category : #pullupdown }
PicodDriver >> pullsBoth: aList [
"pulsBoth = 2r11 or byte 116rff"
	| pinMask dataBytes|
	pinMask := 0.
	dataBytes := ByteArray new: 12 withAll: 255.
	aList do: [  :pin | pinMask := pinMask bitOr: (1 << pin) ].
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	self sendCommand: 20 flags: 0 data: dataBytes
]

{ #category : #pullupdown }
PicodDriver >> pullsDown: aList [
	"pullDown = 2r01 or byte 16r55"
	| pinMask dataBytes|
	pinMask := 0.
	dataBytes := ByteArray new: 12 withAll: 16r55.
	aList do: [  :pin | pinMask := pinMask bitOr: (1 << pin) ].
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	self sendCommand: 20 flags: 0 data: dataBytes
]

{ #category : #pullupdown }
PicodDriver >> pullsNone: aList [
	| pinMask dataBytes|
	pinMask := 0.
	dataBytes := ByteArray new: 12 withAll: 0.
	aList do: [  :pin | pinMask := pinMask bitOr: (1 << pin) ].
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	self sendCommand: 20 flags: 0 data: dataBytes
]

{ #category : #pullupdown }
PicodDriver >> pullsUp: aList [
	"pullUp = 2r10 or byte 16raa"
	| pinMask dataBytes|
	pinMask := 0.
	dataBytes := ByteArray new: 12 withAll: 16raa.
	aList do: [  :pin | pinMask := pinMask bitOr: (1 << pin) ].
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	self sendCommand: 20 flags: 0 data: dataBytes
]

{ #category : #'pwm-servo' }
PicodDriver >> pwmOnPin: aGpio value: aPercentage frequency: pps [
	"Starts hardware PWM pulses on a single GPIO.
      gpioAB:= the GPIO.
      frequency:= 7.46 Hz to 31250000 Hz.
      dutycycle:= the percentage high time, 0% to 100%"
	"CMD_PWM = 63"	
	| norm div newf steps high |
	"simple transcription of Python code"
	norm := 125000000 / pps.
	div := (norm / 65536) rounded + 1.
	newf := 125000000 / div.
	steps := (newf / pps) rounded.
	high := (aPercentage * steps / 100.0) rounded.
	^(self txRaw: aGpio mode: 63 clockDiv: (div bitAnd: 255) steps: steps high: high) status.
	
	
]

{ #category : #announcements }
PicodDriver >> removeSubscription: aSubscription [
	listener announcer removeSubscription: aSubscription 
]

{ #category : #utilities }
PicodDriver >> reset [
	"Resets the Pico (frees GPIO, close I2C, SPI, serial, PWM)"
	"RESET_PICO = 96"
	self sendCommand: 96 flags: 0 data: #() asByteArray
	
]

{ #category : #utilities }
PicodDriver >> sendCommand: aCommand flags: aFlagByte data: aByteArray [
	"prepare the request packet using commandPacket and send it
	the bytearray has to be correctly formatted by the sender
	flags = reply <<6"
	| length message retries result|
	"('send ', aCommand printString, ' ', aByteArray hex) traceCr."
	length := aByteArray size + 4.
	message := ByteArray with: (length // 256) with: (length \\ 256)
										with: aFlagByte with: aCommand.
	port nextPutAll: (self commandPacket: (message , aByteArray)) .
	(aFlagByte = 0) ifTrue: [ ^nil ].
	(aFlagByte bitAt: 8) = 1 ifTrue: [ ^self ]. "async request, result in announcement"
	retries := 50.
	[ retries > 0 ] whileTrue: [ 
		 result := listener resultQueue nextOrNil .
		result ifNotNil: [ (result requestCode = aCommand) ifTrue: [ ^result ]
			  ].
		retries := retries - 1.
		10 milliSeconds wait. ].
	^nil
]

{ #category : #'pwm-servo' }
PicodDriver >> servoOnPin: aGpio pulseWidth: microSeconds [
	^self servoOnPin: aGpio pulseWidth: microSeconds frequency: 50
	
]

{ #category : #'pwm-servo' }
PicodDriver >> servoOnPin: aGpio pulseWidth: microSeconds frequency: pps [
	"set the pulseWidth to microseconds (0 or 500-2500"
	"frequency 40 - 500 Hz"
	"CMD_SERVO = 64"
	| norm div newf steps micros high |
	norm := 125000000 / pps.
	div := (norm / 65536) rounded + 1.
	newf := 125000000 / div.
	steps := (newf / pps) rounded.
	micros := 1000000 * steps / newf.
	high := (microSeconds * steps / micros) rounded.
	^(self txRaw: aGpio mode: 64 clockDiv: (div bitAnd: 255) steps: steps high: high) status
]

{ #category : #'pwm-servo' }
PicodDriver >> servoPwmClose: aGpio [
	"Stops PWM/Servo pulses and frees the associated GPIO."
	"CMMD_PWM_ CLOSE = 65"
	self sendCommand: 65 flags: 0 data: (ByteArray with: aGpio)
]

{ #category : #'event processing' }
PicodDriver >> setDebounceOnPin: aPin duration: millis [
	"A level change for the GPIO will only be reported once the level
   has been stable for at least millis milliseconds.
	CMD_ALERT_DEBOUNCE = 30"
	| dataBytes |
	dataBytes := ByteArray new: 5.
	dataBytes at: 1 put: aPin.
	dataBytes unsignedLongAt: 2 put: ((millis * 1000) rounded) bigEndian: true.
	self sendCommand: 30 flags: 0 data: dataBytes.
]

{ #category : #'digital pins' }
PicodDriver >> setGpioInput: aPin [

	"set one gpio to input
	CMD_GPIO_SET_IN+OUT = 12"

	| pinMask dataBytes |
	pinMask := 1 << aPin.
	dataBytes := ByteArray new: 8 withAll: 0. "preset input"
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	self sendCommand: 12 flags: 0 data: dataBytes
]

{ #category : #'digital pins' }
PicodDriver >> setGpioOutput: aPin value: aValue [

	"set one gpios to output with preset aValue
	CMD_GPIO_SET_IN+OUT = 12"

	| pinMask dataBytes valueMask |
	pinMask := 1 << aPin.
	valueMask := 0.
	(aValue = 1) ifTrue: [ valueMask := 1 << aPin ].
	dataBytes := ByteArray new: 12 withAll: 1. "preset output"
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	dataBytes unsignedLongAt: 9 put: valueMask bigEndian: true.
	self sendCommand: 12 flags: 0 data: dataBytes
]

{ #category : #'digital pins' }
PicodDriver >> setGpiosInput: aPinList [
	"set the gpios listed to inputs
	CMD_GPIO_SET_IN+OUT = 12"
	| pinMask dataBytes | 
	pinMask := 0.
	aPinList do: [  :pin | pinMask := pinMask bitOr: (1 << pin) ].
	dataBytes := ByteArray new: 8 withAll: 0. "preset input"
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	self sendCommand: 12 flags: 0 data: dataBytes 
	
	
]

{ #category : #'digital pins' }
PicodDriver >> setGpiosOutput: aPinList values: aValueList [
	"set the gpios listed to inputs
	CMD_GPIO_SET_IN+OUT = 12"
	| pinMask dataBytes valueMask | 
	pinMask := 0.
	aPinList do: [  :pin | pinMask := pinMask bitOr: (1 << pin) ].
	valueMask := 0.
	aValueList do: [  :pin | valueMask := valueMask bitOr: (1 << pin) ].
	dataBytes := ByteArray new: 12 withAll: 1. "preset output"
	dataBytes unsignedLongAt: 1 put: pinMask bigEndian: true.
	dataBytes unsignedLongAt: 9 put: valueMask bigEndian: true.
	self sendCommand: 12 flags: 0 data: dataBytes 
	
	
]

{ #category : #'event processing' }
PicodDriver >> setWatchdogOnPin: pinNr timeOut: duration [
	"set a watchdog timer on the pin specified; if the pin does not change
	during the next duration milliseconds a PicodWatchdog announcement
	will be triggered. Note that in pico-python duration is in seconds, 
	and internally in microseconds. We use milliseconds to be compatible
	with PiGPIO. Max is 60 seconds.
	CMD_ALERT_WATCHDOG = 31"
	| dataBytes |
	dataBytes := ByteArray new: 5.
	dataBytes at: 1 put: pinNr.
	dataBytes unsignedLongAt: 2 put: (duration * 1000) rounded bigEndian: true.
	self sendCommand: 31 flags: 0  data: dataBytes.
	"the pin must also be in the to-monitor list"
	listener addPinsToMonitor: (1 << pinNr)
]

{ #category : #initialization }
PicodDriver >> setup [
	i2cChannels := Array new: 2.
 	
]

{ #category : #initialization }
PicodDriver >> startListener [
	listener := PicodListener new onPort: port.
	listener owner: self.
	statusCheck := false.
	listener start


]

{ #category : #debugging }
PicodDriver >> statusCheck [
	^statusCheck
]

{ #category : #debugging }
PicodDriver >> statusCheck: aBoolean [
	statusCheck := aBoolean
]

{ #category : #utilities }
PicodDriver >> stopListener [
	listener stop.

]

{ #category : #'pwm-servo' }
PicodDriver >> txRaw: aPin mode: aCode clockDiv: aByte steps: nrOfSteps high: aNumber [ 
	"generic call, used by servoOnPin: and pwmOnPin: "
	| dataBytes |
	dataBytes := ByteArray new: 6.
	dataBytes at: 1 put: aPin;
					at: 2 put: aByte;
					unsignedShortAt: 3 put: nrOfSteps bigEndian: true;
					unsignedShortAt: 5 put: aNumber bigEndian: true.
	^self sendCommand: aCode flags: 16r40 data: dataBytes 
]

{ #category : #announcements }
PicodDriver >> when: anEvent do: aBlock [ 
	listener announcer when: anEvent do: aBlock
]
