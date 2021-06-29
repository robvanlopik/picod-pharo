# Picod - Pharo

Picod is a daemon program that runs on the Raspberry Pico (http://abyz.me.uk/picod/index.html). It uses serial communication (either UART or USB) to communicate with a host. Functionally it is more or less equivalent to having a Firmata sketch on an Arduino microprocessor or the PiGPIO daemon on a Raspberry Pi. The communication protocol is specific to Picod. It uses eight bits and CRC checks. The original comes with a Python library. Just like PiGPIO it has an elaborate callback mechanism for Python. And just like the PiGPIO driver for Pharo this has here been implemented using announcements.

### Starting

First you will have to put the picod.uf2 file on the Pico. The driver is started with something like:
```myPico := PicodDriver new connectOnPort: '/dev/ttyACM0'. ```

Optionally you can include ```baudRate:``` , which defaults to 230400 and doesn't make much sense for a USB serial port anyway

### Commands

Some commands/request have no return value. Commands that do return a value have two flavours (where this makes sense). Either the result is returned by the method itself, or the result is returned in an announcement (```PicodResultAvailable```). For example:

```v := pico analogRead: channelNr```  returns the value, while
​```pico analogRead: channelNr wait: false``` returns immediately and the result will be transmitted in an announcement when it becomes available.

Results are instances of ```PicodResult``` and contain the operations code, the status and the actual result bytes. A status of 0 means OK. Wait:true calls return the value only.

For testing you can do:

```myPico statusCheck: true. "This will write the text for non-zero result codes to the Transcript"```

#### Simple I/O operations.

##### Digital I/O

Some digital I/O operations are specified for a number of pins at once. Internally the pins are represented by single bits in a 64-bit word, but here we use arrays of gpio numbers. So we have

```smalltalk
myPico digitalWrite: 25 value: 1. "set pin 25 to 1; 25 happens to be the on-board LED"
myPico digitalWrite: #(1 3 5) values: #(1 1 0). "set pins 1 3 and 5 to 1, 1 and 0 respectively"
level := myPico digitalRead: 2.
myPico closeGpios: #(0 2). "frees pins 0 and 2 for other uses"
```

Pull up or down can beset for pins. We have four methods that operate on collections of pins: ```#pullsNone: #pullsUp: #pullsDown and #pullsBoth: ```

```#pullForPin: ``` returns the pull value for an individual pin. Before you can change the pull resistors you must first open the pins you want to modify with```#openGpios:```.

##### Servo/PWM

All gpio's are capable of outputting servo or PWM signals, but not fully independently. You will have to read the docs. Methods are:

```smalltalk
myPico pwmOnPin: 12 value: 30 frequency: 1000. "30% pwm at 1000 Hz"
myPico servoOnPin: 13 pulseWidth: 1000. "1000 microsecond pulse (90 degrees) at 50 Hz"
myPico servoPWMClose: 13. "Free gpio 13 for other uses"
```

##### Analog

```voltage := myPico analogRead: 3 "read analog channel 3"```

reads channel 3 adc, which happens to be connected to a voltage diver between VSYS and ground;

To free the gpio pin for other uses, you have to execute

```myPico analogClose: 3```

#### I2C

The RP2040 has two I2C channels, 0 and 1. First a channel must be opened and associated the the gpio's to be used as *sda* and *scl*:

```myPico i2cOpenChannel: channel sda: sdapin scl: sclPin baudRate: aNumber```

BaudRate usually is 100000. Channel is 0 or 1 and each channel allows only certain combinations of pins (see comments). After that you can read and write bytes to and from that channel. A special selector ```noStop``` is available to keep the Pico from releasing the bus, so you can write a register address and follow up by reading the data. I2C operations have been objectified in the class ```PicodI2CConnection```.

An instance of ```PicodI2CConnection``` is specific for one device and is determined by its I2C channel and the device bus address:

```myI2CDevice := myPico i2cOpenConnectionOn: channel i2cAddres: anI2CAddress```

where channel (0 or 1) should have been opened before and anI2CAddress is de device address (0-255).

Now you have the operations that are also available in the Firmata and PiGPIO drivers like:

```smalltalk
a := myI2CDevice readByteAt: 0. "read 8 bits at register 0"
myI2CDevice writeWordAt: 2 data: 16r3AC5. "write 16r3AC5 to register 2, lowest byte first" 
myI2CDevice writeWordBigEndianAt: 2 data: 16r3AC5. "same but high byte first"
```

A device is closed with ```#close``` . Only by closing the channel with ```#i2cCloseChannel:``` you free the associated gpios. This is only possible when there are no more active i2cConnections on that channel; otherwise use ```i2cCloseChannelForced:``` to close all devices for you.

### Asynchronous operations

Picod supports a number of asynchronous operations. All are implemented using the announcement framework.

#### Pin level changes

```#pinsToWatch```: is the method to specify which pins can generate an announcement on level change. There is only one type of announcement, ```PicodPinChange``` with accessors ```pinNr```,  ```newLevel``` and ```tick```. The latter is a timestamp with an accuracy of some microseconds that rolls over every 72 minutes.

You can also get a notification (```PicodWatchdog```)  that is triggered when a pin does not change during a specified period. The watchdog is set with ```#setWatchdogOnPin:timeout:```. The watchdog timer starts after the first level change.

#### Asynchronous results

A command/request can specify ```wait: false```. In that case an announcement, ```PicodResultAvailable``` will be triggered with one method,  ```result```  that returns the ```PicodResult `` (see above). The result contains the request code that generated this result.

#### Events

Events stem from UART, I2C, GPIO, SPI operations. You can specify which event to watch. This is not yet implemented.

#### Subscribing

To subscribe to announcements we have for example:

```myPico when: PicodPinChange do: [:ann | ('pin ', ann pinNr printString, ' has changed') traceCr.].```

### Notes

This driver was developed and tested on a Raspberry Pi 4. I suppose it will run on other Linuxes as well, but I don't have one. It does *not* work on Windows because Pharo SerialPort can not communicate with the RP2040 (Pico) although Windows shows its corresponding COM port. I am trying to investigate. It seems specific to both the SerialPlugin and the RP2040 USB implementation that is based on TinyUSB. But Python and PuTTY communicate OK with the RP2040. 



