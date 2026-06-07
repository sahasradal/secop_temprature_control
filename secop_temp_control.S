#riscv32-unknown-elf-as -I. -g secop_temp_control.S -o secop_temp_control.o
#riscv32-unknown-elf-ld -T CH32V003_E.ld -Map=final.map secop_temp_control.o
#riscv32-unknown-elf-objcopy -O ihex -R .bss -R .sbss a.out secop_temp_control.hex

.include "ch32v003_reg1.inc"

# Define ADC Thresholds (NTC: higher value = colder)
.equ ADC_CUTOUT,    646    # ~3°C (Stop compressor if ADC >= 646)
.equ ADC_CUTIN,     626    # ~5°C (Allow start if ADC <= 626)

.section .sbss
# ... variables ...

result1: .space 4
result2: .space 4
mem:  .space 16      		# Allocate 16 bytes




.align 4
.section .text
.global _start
_start:

   	la sp, STACK			# initialize stack pointer
#Enable GPIO clocks & AFIO in APB2 clock register
        
    	la x10,R32_RCC_APB2PCENR	# load address of APB2PCENR register to x10 ,for enabling GPIO A,D,C peripherals
	lw x11,0(x10)			# load contents from peripheral register R32_RCC_APB2PCENR pointed by x10
	li x7,((1<<2)|(1<<4)|(1<<5)|(1<<0)|(1<<14)|(1<<9)|(1<<11))	# 1<<IOPA_EN,1<<IOPC_EN,1<<IOPD_EN,1<<AFIOEN,1<<USART ,1<<ADC enable port A,C,D and AFIO functions
	or x11,x11,x7			# or values 
	sw x11,0(x10)			# store modified enable values in R32_RCC_APB2PCENR

#Enable ADC prescaler in clock configuration register
	la x10,R32_RCC_CFGR0
	lw x11,0(x10)
	li x7,((8<<11))			# 0b01000 ADC prescalar ahb/4 = 8/4 = 2mhz
	or x11,x11,x7
	sw x11,0(x10)

#configure GPIO C
	la x10,R32_GPIOC_CFGLR		# load pointer x10 with address of R32_GPIOD_CFGLR , GPIO configuration register
	lw x11,0(x10)			# load contents from register pointed by x10
	li x7,~(0xf<<0)			#clear pc0. we need to setup PD5 & PD6 for usart tx and rx and pd4 for ADC7, pd3 for ADC4
	and x11,x11,x7			# clear pd4,pd5,pd6 mode and cnf bits for selected pin 
	li x7,(0x1<<0)			# pc0 = output pushpull output 10mhz,
	or x11,x11,x7			# OR value to register
	sw x11,0(x10)			# store in R32_GPIOC_CFGLR

#configure GPIO D 
	la x10,R32_GPIOD_CFGLR		# load pointer x10 with address of R32_GPIOD_CFGLR , GPIO configuration register
	lw x11,0(x10)			# load contents from register pointed by x10
	li x7,~((0xf<<24)|(0xf<<20)|(0xf<<16)|(0xf<<12))	#clear pd4,pd5,pd6. we need to setup PD5 & PD6 for usart tx and rx and pd4 for ADC7, pd3 for ADC4
	and x11,x11,x7			# clear pd4,pd5,pd6 mode and cnf bits for selected pin D4,D5,D6
	li x7,(0x8<<24)|(0xB<<20)	# pd6 = input with PU/PD,pd5= multiplex pushpull output 50mhz,pd4,pd3 analog input for ADC 0b0000
	or x11,x11,x7			# OR value to register
	sw x11,0(x10)			# store in R32_GPIOD_CFGLR

#configure USART baud
	la x10,R32_USART_BRR		# USART BAUD setting
	lw x11,0(x10)			# copy R32_USART_BRR to x11
	li x7,((52<<4)|(1<<0))		# 52.1 in BRR =9600
	or x11,x11,x7			# or registers
	sw x11,0(x10)			# store in R32_USART_BRR

#setup UART control and enable	
	la x10,R32_USART_CTLR1		# load x10 with R32_USART_CTLR1 address
	lw x11,0(x10)			# load to x11 contents
	li x7,(1<<13)|(1<<3)|(1<<2)	# enable USART UE, TX,RX bits		# UE 
	or x11,x11,x7
	sw x11,0(x10)			# store back new values

#disable ADC before configuration
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	li x7,0xfffffffe		#disable ADON bit , 0 written in 0bit
	and x11,x11,x7
	sw x11,0(x10)

#set sequence of conversion channel
	la x10,R32_ADC_RSQR3		# sequence register, if multiple sensors used we can determine the order of conversion
	lw x11,0(x10)
	li x7,(7<<0)			# AIN7 adc channel is written to sequence 1 and AIN4 to sequence 2
	or x11,x11,x7
	sw x11,0(x10)

#set sampling cycles
	la x10,R32_ADC_SAMPTR2		# takes sampling cycles for each measurement
	lw x11,0(x10)
	li x7,(7<<21)			# 0b111/0x7 is 241 cycles for both ain7 and ain4	
	or x11,x11,x7
	sw x11,0(x10)

#enable adc in control register2
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	li x7,((7<<17)|(1<<0))		# SWSTART trigger for ADC and ADON
	or x11,x11,x7
	sw x11,0(x10)

#reset calibrate ADC
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	li x7,(1<<3)			# reset calibration	
	or x11,x11,x7
	sw x11,0(x10)
check1:
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	andi x11,x11,(1<<3)
	bnez x11,check1

# calibrate ADC
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	li x7,(1<<2)			# start calibration	
	or x11,x11,x7
	sw x11,0(x10)
check2:
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	andi x11,x11,(1<<2)
	bnez x11,check2



    
    # Stabilization delay
    li t1, 1000
adc_delay:
    addi t1, t1, -1
    bnez t1, adc_delay

    # Initialize State Flag
    # s1 = Compressor State (0 = OFF, 1 = ON)
    li s1, 0

main_loop:
	# trigger conversion of piezo
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	li x7,((1<<22)|(1<<0))			# (1<<SWSTART) start conversion
	or x11,x11,x7
	sw x11,0(x10)

wait_adc:
	la x10,R32_ADC_STATR		# adc status register
	lw x11,0(x10)
	andi x11,x11,2			# adc conversion finish flag mask
	beqz x11,wait_adc		# wait till bit 1 is set
	la x10,R32_ADC_RDATAR		# ADC data register
	lw s0,0(x10)			# Read current temperature value into s0
	    


    	# Evaluate Hysteresis
    	li t1, ADC_CUTOUT
    	bge s0, t1, stop_compressor    # Temp <= 3°C -> Turn OFF

    	li t1, ADC_CUTIN
    	ble s0, t1, start_compressor   # Temp >= 5°C -> Turn ON

    	# If inside the deadband, make no state changes
    	j loop_delay

stop_compressor:
    	# Always force the pin low to be safe, update state to 0
    	li t0, GPIOC_BASE
    	li t1, (1 << 16)               # Clear PC0
    	sw t1, GPIO_BSHR(t0)
    	li s1, 0                       # State = OFF
    	j loop_delay

start_compressor:
    	# Check current state tracking register
    	bnez s1, loop_delay            # If s1 == 1, it's already running. Skip everything.

    	# State was 0 (OFF). This is a fresh transition to ON!
    	# Run the 5-minute pressure equalization delay BEFORE turning it on
    	jal ra, delay_5_minutes

    	# Fire up the compressor
    	li t0, GPIOC_BASE
    	li t1, 1                       # Set PC0 HIGH
    	sw t1, GPIO_BSHR(t0)
    
    	li s1, 1                       # Update State = ON

loop_delay:
    	# 1-second sampling delay
    	li t1, 3000000
1:  	addi t1, t1, -1
    	bnez t1, 1b
    	j main_loop

# --- Delay Subroutine ---
delay_5_minutes:
    	li t3, 1800000000
delay_loop:
    	addi t3, t3, -1
    	bnez t3, delay_loop
    	ret