#riscv32-unknown-elf-as -I. -g secop_temp_control.S -o secop_temp_control.o
#riscv32-unknown-elf-ld -T CH32V003_E.ld -Map=final.map secop_temp_control.o
#riscv32-unknown-elf-objcopy -O ihex -R .bss -R .sbss a.out secop_temp_control.hex

.include "ch32v003_reg.inc"
.equ RXNE,          0x20     		# Bit 5  - Receive Data Register Not Empty
# Define ADC Thresholds (NTC: higher value = colder)
.equ ADC_CUTOUT,    700    # ~3°C (Stop compressor if ADC >= 646)
.equ ADC_CUTIN,     670    # ~5°C (Allow start if ADC <= 626)

.section .sbss
# ... variables ...

result1: .space 4
result2: .space 4
mem:  .space 16      		# Allocate 16 bytes




.align 4
.section .text
.global start
start:

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
	li x7,~(0xf<<4)			#clear pc1. for compressor contrl
	and x11,x11,x7			# clear pd4,pd5,pd6 mode and cnf bits for selected pin 
	li x7,(0x3<<4)			# pc1 = output pushpull output 10mhz,
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

   	la t0, R32_GPIOC_BSHR
    li t1, (1 << 1)               	# set  PC1 , makes the mosfet SI2300 conduct
    sw t1, 0(t0)


#configure USART baud
	la x10,R32_USART_BRR		# USART BAUD setting
	lw x11,0(x10)				# copy R32_USART_BRR to x11
	li x7,((52<<4)|(1<<0))		# 52.1 in BRR =9600
	or x11,x11,x7				# or registers
	sw x11,0(x10)				# store in R32_USART_BRR

#setup UART control and enable	
	la x10,R32_USART_CTLR1		# load x10 with R32_USART_CTLR1 address
	lw x11,0(x10)				# load to x11 contents
	li x7,(1<<13)|(1<<3)|(1<<2)	# enable USART UE, TX,RX bits		# UE 
	or x11,x11,x7
	sw x11,0(x10)				# store back new values

#disable ADC before configuration
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	li x7,0xfffffffe			#disable ADON bit , 0 written in 0bit
	and x11,x11,x7
	sw x11,0(x10)

#set sequence of conversion channel
	la x10,R32_ADC_RSQR3		# sequence register, if multiple sensors used we can determine the order of conversion
	lw x11,0(x10)
	li x7,(7<<0)				# AIN7 adc channel is written to sequence 1 and AIN4 to sequence 2
	or x11,x11,x7
	sw x11,0(x10)

#set sampling cycles
	la x10,R32_ADC_SAMPTR2		# takes sampling cycles for each measurement
	lw x11,0(x10)
	li x7,(7<<21)				# 0b111/0x7 is 241 cycles for both ain7 and ain4	
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
	li x7,(1<<3)				# reset calibration	
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
	li x7,(1<<2)				# start calibration	
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

	la x10,message1			# load address of label "name" to x10, string to be transmitted
string_loop:
	lb x8,0(x10)			# load 1 byte from 0 offset of "name"
	beqz x8,finish			# if byte in x8 null branch to label "finish"
	call USART_TX			# call subroutine USART_TX to transmit byte
	addi x10,x10,1			# increase pointer by 1 byte
	j string_loop			# jump back to label string_loop until null is encountered
finish:
	call delay1S

    # Initialize State Flag
    # s1 = Compressor State (0 = OFF, 1 = ON) , a4 is the moving exponential average
    li s1, 0
	li a4,0



main_loop:
	# trigger conversion of piezo
	la x10,R32_ADC_CTLR2
	lw x11,0(x10)
	li x7,((1<<22)|(1<<0))			# (1<<SWSTART) start conversion
	or x11,x11,x7
	sw x11,0(x10)

wait_adc:
	la x10,R32_ADC_STATR			# adc status register
	lw x11,0(x10)
	andi x11,x11,2				# adc conversion finish flag mask
	beqz x11,wait_adc			# wait till bit 1 is set
	la x10,R32_ADC_RDATAR		# ADC data register
	lw a5,0(x10)				# Read current temperature value into s0
	andi a5, a5, 0x3FF       	# Clean 10-bit raw sample


	# --- EMA FILTER MATH RUNS HERE ---
    # Formula: s4 = (a5 + s4 + s4 + s4) >> 2
    mv tp, a4                	# t5 = Old Average
    slli gp, tp, 1           	# t6 = Old Average * 2
    add tp, tp, gp           	# t5 = Old Average * 3
    add tp, tp, a5           	# t5 = Current Sample + (Old Average * 3)
    srli a4, tp, 2           	# s4 = t5 / 4  (This is our new Filtered Average!)





	mv a0,a4
	call print_hex_32bit
	li x8,'\r'
	call USART_TX
	li x8,'\n'
	call USART_TX


	mv a0,s1
	call print_hex_32bit
	li x8,'\r'
	call USART_TX
	li x8,'\n'
	call USART_TX


		    


    # Evaluate Hysteresis
    li t1, ADC_CUTOUT

	mv a0,t1
	call print_hex_32bit
	li x8,'\r'
	call USART_TX
	li x8,'\n'
	call USART_TX

    bgeu a4, t1, stop_compressor    # Temp <= 3°C -> Turn OFF


    li t1, ADC_CUTIN
    bleu a4, t1, start_compressor   # Temp >= 5°C -> Turn ON

    # If inside the deadband, make no state changes
	j loop_delay

stop_compressor:
    # Always force the pin low to be safe, update state to 0
    la t0, R32_GPIOC_BSHR
    li t1, (1 << 1)              	# set PC1 for mosfet to start conducting , pulls BLDC signal line 0
    sw t1, 0(t0)
    li s1, 0                       # State = OFF
	
	mv a0,s1
	call print_hex_32bit
	li x8,'\r'
	call USART_TX
	li x8,'\n'
	call USART_TX
    	

    j loop_delay

start_compressor:
    # Check current state tracking register
    bnez s1, loop_delay            # If s1 == 1, it's already running. Skip everything.

    # State was 0 (OFF). This is a fresh transition to ON!
    # Run the 5-minute pressure equalization delay BEFORE turning it on
    call delay_5_minutes
   	# Fire up the compressor
   	la t0, R32_GPIOC_BSHR
   	li t1, (1<<17)                  # clear PC1 , mosfet stops conducting , BLDC signal line will return to set speed
   	sw t1, 0(t0)
    
    li s1, 1                       	# Update State = ON
	
	mv a0,s1
	call print_hex_32bit
	li x8,'\r'
	call USART_TX
	li x8,'\n'
	call USART_TX
    j loop_delay

loop_delay:
    	# 1-second sampling delay
    	li t1, 3000000
DL:  	addi t1, t1, -1
    	bnez t1, DL
    	j main_loop

# --- Delay Subroutine ---
delay_5_minutes:
	addi sp,sp,-8
	sw ra,0(sp)
	sw t2,4(sp)
    	li t2, 361800300      #(2010010 x 60 x 5=603003000), testing at 1 minute 120600100,241200200,361800300,482400400,603000500
delay_loop:
    addi t2, t2, -1
    bnez t2, delay_loop
	lw t2,4(sp)
	lw ra,0(sp)
	addi sp,sp,8
    	ret



###################################################################
USART_TX:
	addi sp,sp,-16			# add space in stack
	sw ra,0(sp)			# push ra
	sw x7,4(sp)			# push x7
	sw x10,8(sp)			# push x10
	sw x11,12(sp)			# push x11
TX_loop:
	la x10,R32_USART_STATR		# load address of usart status register
	lw x11,0(x10)			# load contents of status register in x11
	andi x11,x11,(1<<7)		# mask out 7th bit, transmit buffer empty flag
	beqz x11,TX_loop		# if 0 transmit buffer full, wait until bit is set
	#li x8,0x30
	mv x7,x8			# move byte in x8(s0) to x7(t2) ( call USART_TX with byte in x8)
	la x10,R32_USART_DATAR		# x10 has the address of data register
	sb x7,0(x10)			# store byte in x7 to data register
TC_check:
	la x10,R32_USART_STATR		# get contents of status register again
	lw x11,0(x10)
	andi x11,x11,(1<<6)		# check transmit complete bit
	beqz x11,TC_check		# wait if bit is 0 , when transmit complete = 1
		
	lw x11,12(sp)			# pop x11
	lw x10,8(sp)			# pop x10
	lw x7,4(sp)			# pop x7
	lw ra,0(sp)			# pop ra
	addi sp,sp,16			# set SP back 16 bytes
	ret				# return to caller

 
################################################################################
#Helper: Read one byte from UART (polling)

read_byte:
	addi sp,sp,-8
	sw ra,0(sp)
	sw a1,4(sp)
rb_loop:
	la a0,R32_USART_STATR
	lw a1,0(a0)
	andi a1,a1, RXNE		# RXNE=0x20
	beqz a1,rb_loop       		# Wait until RXNE == 1
	la a0,R32_USART_DATAR  		# Read the byte into a0
	lbu a0,0(a0)
	lw a1,4(sp)
	lw ra,0(sp)
	addi sp,sp,8
	ret
###################################################################################

######################################################################################
# Input: x8 = Byte to print as Hex
# Uses: x7, x8, x9
print_hex_byte:
    	addi sp, sp, -16
    	sw ra, 0(sp)
    	sw x8, 4(sp)            # Save original byte
    	sw x7, 8(sp)
    	sw x9,12(sp)

   	 mv x9, x8               # Copy to x9
    
    	# Process High Nibble
    	srli x8, x9, 4          # Shift right 4 bits
    	call nibble_to_ascii
    	call USART_TX
    
    	# Process Low Nibble
    	andi x8, x9, 0x0F       # Mask lower 4 bits
    	call nibble_to_ascii
    	call USART_TX

    	lw x9,12(sp)
    	lw x7, 8(sp)
    	lw x8, 4(sp)            # Restore x8
    	lw ra, 0(sp)
    	addi sp, sp, 16
    	ret

nibble_to_ascii:
    	addi sp, sp, -12
    	sw ra, 0(sp)
	sw x7,4(sp)
	sw x8,8(sp)
    	li x7, 10
    	blt x8, x7, is_digit
    	addi x8, x8, 7          # Offset for A-F
is_digit:
    	addi x8, x8, 48         # Add ASCII '0'
	lw x0,8(sp)
	lw x7,4(sp)
    	lw ra, 0(sp)
    	addi sp, sp, 12
    	ret


#############################################################
# =============================================
# Simple 32-bit Hex Print (MSB first),value in a0
# =============================================
print_hex_32bit:
    addi sp, sp, -12
    sw ra, 0(sp)
    sw x8, 4(sp)
    sw t0, 8(sp)

    mv t0, a0               # t0 = value to print

    # Byte 3
    srli x8, t0, 24
    call print_hex_byte

    # Byte 2
    srli x8, t0, 16
    andi x8, x8, 0xFF
    call print_hex_byte

    # Byte 1
    srli x8, t0, 8
    andi x8, x8, 0xFF
    call print_hex_byte

    # Byte 0
    mv x8, t0
    andi x8, x8, 0xFF
    call print_hex_byte
    lw t0, 8(sp)
    lw x8, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 12
    ret

#############################################################
###############################################################
string_reader:
	addi sp,sp,-8
	sw ra,0(sp)
	sw x8,4(sp)
sr_loop:
	lb x8,0(a2)			# load 1 byte from 0 offset of a2 pointing address
	beqz x8,sr_finish		# if byte in x8 null branch to label "finish"
	call USART_TX			# call subroutine USART_TX to transmit byte
	addi a2,a2,1			# increase pointer by 1 byte
	j sr_loop			# jump back to label string_loop until null is encountered
sr_finish:
	lw x8,4(sp)
	lw ra,0(sp)
	addi sp,sp,8
	ret				# 

###################################################################################
delay1S: 
	addi sp,sp,-8 			# push RA
	sw ra,0(sp) 			# push RA
	sw t1,4(sp)
	li t1,2010010 			# load an arbitarary value 20000000 to t1 register 
loop1s:
	addi t1,t1,-1 			# subtract 1 from t1
	bne t1,zero,loop1s 		# if t1 not equal to 0 branch to label loop
	lw t1,4(sp)
	lw ra,0(sp) 			# POP RA
	addi sp,sp,8 			# pop RA
	ret 
########################################################

.align 4
.section .rodata
.global message
message1: .asciz "compressor control online\r\n "




