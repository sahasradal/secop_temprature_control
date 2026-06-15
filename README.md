# secop_temprature_control
secop compressor control based on temprature. the adc7 pd4 measures the thermistor + 10k divider. the thermistor at 23degrees C reads 11.36kohm and 15.86 kohm at 5degrees C. the compressor will be cutoff at 3 degree and restarted at 5 degrees with a 5 minute delay to equlise pressure and lockup . PD4 adc /thermistor , PC1 used to control BLDC driver board. when temprature reaches 3 degree the PC1 is turned on which drives the gate of SI2300 mosfet. the BLDC controller V pin is pulled to ground via the drain to source. this will stop the motor. when temprature rises the PC1 is pulled low which opens the mosfet causing the signal from BLDC pot to cause the motor run again. the pot to bldc signal is seriesed through 10k ohm resistor and is connected to drain of mosfet and BLDC board. gate is driven by ch32v003

<img width="702" height="1600" alt="WhatsApp Image 2026-06-04 at 8 01 14 AM" src="https://github.com/user-attachments/assets/8769a66e-c938-40e5-a415-c4be2f9a79e5" />

<img width="702" height="1600" alt="WhatsApp Image 2026-05-20 at 10 18 44 AM" src="https://github.com/user-attachments/assets/6f0bab1c-1813-4da5-b8cb-d002632cc095" />
