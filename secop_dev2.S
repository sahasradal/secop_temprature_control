
#@ 24Mhz clock rpm = 24000000 x 60/ delta ticks = 1440000000/current tick- previous tick

#riscv32-unknown-elf-as -I. -g secop_dev2.S -o secop_dev2.o
#riscv32-unknown-elf-ld -T CH32V003_E.ld -Map=final.map secop_dev2.o
#riscv32-unknown-elf-objcopy -O ihex -R .bss -R .sbss a.out secop_dev2.hex

.include "ch32v003_reg1.inc"

# --- THERMAL CONTROL THRESHOLDS ---
.equ ADC_CUTIN,         670    # 7°C - Warm limit
.equ ADC_CRUISE_ZONE,   685    # ~4°C - Eco slowdown limit
.equ ADC_CUTOUT,        700    # 2°C - Cold cutoff limit

# --- REGISTER TRACKING ALLOCATION ---
# s1 = Compressor State Machine (0 = OFF, 1 = FAST, 2 = ECO)
# a2 = SPEED PULSE COUNTER (Increments inside EXTI interrupt)
# a4 = EMA Filter Value (History Anchor Variable)


################
.section .sbss
# ... variables ...

result1: .space 4
result2: .space 4
mem:  .space 16      		# Allocate 16 bytes
last_systick: .space 4





.align 9
vtable:
  j start		#  
  .word   0x00000000 # RESERVED 1
  .word   NMI_IRQhandler
  .word   HardFault_IRQhandler
  .word   0x00000000 # RESERVED 4
  .word   0x00000000 # RESERVED 5
  .word   0x00000000 # RESERVED 6
  .word   0x00000000 # RESERVED 7
  .word   0x00000000 # RESERVED 8
  .word   0x00000000 # RESERVED 9
  .word   0x00000000 # RESERVED 10
  .word   0x00000000 # RESERVED 11
  .word   SysTick_IRQhandler		# 	
  .word   0x00000000 # RESERVED 13
  .word   SW_Software_IRQhandler
  .word   0x00000000 # RESERVED 15
  .word   WWDG_IRQhandler
  .word   PVD_IRQhandler
  .word   FLASH_IRQhandler
  .word   RCC_IRQhandler
  .word   EXTI7_0_IRQhandler
  .word   AWU_IRQhandler
  .word   DMA1_CH1_IRQhandler
  .word   DMA1_CH2_IRQhandler
  .word   DMA1_CH3_IRQhandler
  .word   DMA1_CH4_IRQhandler
  .word   DMA1_CH5_IRQhandler
  .word   DMA1_CH6_IRQhandler
  .word   DMA1_CH7_IRQhandler
  .word  ADC1_IRQhandler			# ADC1 interrupt vector
  .word  I2C1_EV_IRQhandler
  .word  I2C1_ER_IRQhandler
  .word  USART1_IRQhandler
  .word  SPI1_IRQhandler
  .word  TIM1BRK_IRQhandler
  .word  TIM1UP_IRQhandler
  .word  TIM1TRG_COM_IRQhandler
  .word  TIM1CC_IRQhandler
  .word  TIM2_IRQhandler



.text
.section .isr_vectors
  .weak   NMI_IRQhandler
  .weak   HardFault_IRQhandler
  .weak   SysTick_IRQhandler		
  .weak   SW_Software_IRQhandler
  .weak   WWDG_IRQhandler
  .weak   PVD_IRQhandler
  .weak   FLASH_IRQhandler
  .weak   RCC_IRQhandler
  .weak   EXTI7_0_IRQhandler
  .weak   AWU_IRQhandler
  .weak   DMA1_CH1_IRQhandler
  .weak   DMA1_CH2_IRQhandler
  .weak   DMA1_CH3_IRQhandler
  .weak   DMA1_CH4_IRQhandler
  .weak   DMA1_CH5_IRQhandler
  .weak   DMA1_CH6_IRQhandler
  .weak   DMA1_CH7_IRQhandler
  .weak  ADC1_IRQhandler			# ADC1 interrupt vector
  .weak  I2C1_EV_IRQhandler
  .weak  I2C1_ER_IRQhandler
  .weak  USART1_IRQhandler
  .weak  SPI1_IRQhandler
  .weak  TIM1BRK_IRQhandler
  .weak  TIM1UP_IRQhandler
  .weak  TIM1TRG_COM_IRQhandler
  .weak  TIM1CC_IRQhandler
  .weak  TIM2_IRQhandler


.align 2
.text
.global start
start:

    	li sp, STACK			# load stack pointer with stack end address
	 
    	la t0, vtable			#BASEADDR[31:2],The interrupt vector table base address,which needs to be 1KB aligned
    	ori t0, t0, 3			#BASEADDR[31:2],1: Identify by absolute address,1: Address offset based on interrupt number *4
    	csrrw zero, mtvec,t0		# write t0 mtvec
   	la t0,main
	csrw	mepc,t0
          				#csrw	mepc,t0 :mepc updated with address of main
	mret

  

.align 4

main:
   	li a0,1
	call setup_clock  		# set clock to 24Mhz 
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
	li x7,~((0xf<<24)|(0xf<<20)|(0xf<<16)|(0xf<<12)|(0xf<<8))	#clear pd4,pd5,pd6. we need to setup PD5 & PD6 for usart tx and rx and pd4 for ADC7, pd2 = Multiplexed Push-Pull Output (0b1011) for Hardware TIM1 PWM and PD3 for FG speed input (0x04)
	and x11,x11,x7			# clear pd4,pd5,pd6 mode and cnf bits for selected pin D4,D5,D6,D2
	li x7,((0x8<<24)|(0xB<<20)|(0x0<<16)|(0x4<<12)|(0xB<<8))	# pd6 = input with PU/PD,pd5= multiplex pushpull output 50mhz,pd4,pd3 analog input for ADC 0b0000
	or x11,x11,x7			# OR value to register
	sw x11,0(x10)			# store in R32_GPIOD_CFGLR


# 3. INITIALIZE EXTI3 INTERRUPT FOR SPEED READ ON PD3
    	la t0, R32_AFIO_EXTICR
    	lw t1, 0(t0)
    	li t2, ~(0x3<<6)           	# Clear bits 6:7 for EXTI3 mapping
    	and t1, t1, t2
    	li t2, (0x3<<6)            	# Set EXTI3 to point to Port D# Map EXTI3 to Port D (0b11)
    	or t1, t1, t2
    	sw t1, 0(t0)

    	la t0, R32_EXTI_INTENR
    	li t1, (1<<3)
    	sw t1, 0(t0)     	   	# Enable EXTI line 3
    	la t0, R32_EXTI_RTENR       	# Trigger interrupt on Rising Edge (Low-to-High transition)
	sw t1, 0(t0)
# Enable EXTI3 Interrupt in hardware pipeline (Interrupt ID 20(EXTI0-7) = Bit 20)
    	la t0, R32_PFIC_IENR1
    	li t1, (1<<20)
    	sw t1, 0(t0)

#configure USART baud
	la x10,R32_USART_BRR		# USART BAUD setting
	lw x11,0(x10)			# copy R32_USART_BRR to x11
	li x7,0x09c4			# 52.1 in BRR =9600 (0x0341 @ 8Mhz) (0x09c4 @ 24mhz)
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


    	# 3. INITIALIZE TIMER 1 FOR NON-INVERTED 5kHz PWM
	la t0, R16_TIM1_PSC
    	li t1, 47                  # Prescaler: 24MHz / (47 + 1) = 500kHz base frequency
    	sw t1, 0(t0)
	la t0, R16_TIM1_ATRLR
    	li t1, 100                 # Auto-Reload: Counts to 100 (500kHz / 100 = 5kHz PWM frequency)
    	sw t1, 0(t0)
    
    	# Channel 1: Set to PWM Mode 1 (bits 6:4 = 0b110), Enable Preload (bit 3)
	la t0, R16_TIM1_CHCTLR1
    	li t1, (0x6<<4) | (1<<3)
    	sw t1, 0(t0)
    
    	# Enable Channel 1 Output (bit 0 = 1), Active High polarity (bit 1 = 0)
	la t0, R16_TIM1_CCER 
   	li t1, (1<<0)
    	sw t1, 0(t0)
    
    	# Main Output Enable (BDTR bit 15 is required for advanced TIM1 to release PWM pins)
	la t0, R16_TIM1_BDTR
    	li t1, (1<<15)
    	sw t1, 0(t0)
    
    	# Start Timer 1 (CEN bit 0 = 1)
	la t0, R16_TIM1_CTLR1
    	li t1, (1<<0)
    	sw t1, 0(t0)

	la x10,message1			# load address of label "name" to x10, string to be transmitted
string_loop:
	lb x8,0(x10)			# load 1 byte from 0 offset of "name"
	beqz x8,finish			# if byte in x8 null branch to label "finish"
	call USART_TX			# call subroutine USART_TX to transmit byte
	addi x10,x10,1			# increase pointer by 1 byte
	j string_loop			# jump back to label string_loop until null is encountered
finish:
	call delay1S			# some delay

        # Initialize State Flag
   	# s1 = Compressor State (0 = OFF, 1 = RUNNING FAST, 2 = RUNNING ECO) , a4 is the moving exponential average
    	li s1, 0	# reset  motor state to off
	li a4,0		# reset filter
	li a2,0         # reset speed counter

#setup systick registers
		
	la x10,R32_STK_CTLR 		# systick control register is reset 
	sw zero,0(x10)			# R32_RCC_CTLR = 0
	la x10,R32_STK_CMPR		# Counting comparison low register
	sw zero,0(x10)			# compare register reset to 0
	li x7,0xFFFFFFFF		# count maximun
	sw x7,0(x10)
	la x10,R32_STK_CNTR		# System counter register
	sw zero,0(x10)			# counter reset to 0
	la x10,R32_STK_CTLR 		# systick control register,enable counter,interrupt,clock source 
	li x7,((1<<0)|(1<<3)|(1<<2))	# SYSTICK_CTLR_STE = (1<<0) enable, 1<<3 auto count reload,0<<2 Hclk/8 = 3mhz , 1<<2 = 24 Mhz
	sw x7,0(x10)



# enabling GLOBAL INTERRUPTS
	li t0, 0x88			# load MPIE and MIE bits , 1<<MIE in mstatus is enabling GLOBAL INTERRUPTS
	csrw mstatus,t0 		# csrrw the values in t0,
#####################

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
	lw a5,0(x10)			# Read current temperature value into s0
	andi a5, a5, 0x3FF       	# Clean 10-bit raw sample

	mv a0,a5
	call print_hex_32bit
	li x8,'\r'
	call USART_TX
	li x8,'\n'
	call USART_TX

	# --- REGISTER TRACKING ALLOCATION ---
	# s1 = Compressor State Machine (0 = OFF, 1 = RUNNING FAST, 2 = RUNNING ECO)
	# a4 = EMA Filter Value (History Anchor Variable)


    	# --- EMA FILTER MATH RUNS HERE (5 Clock Cycles) ---
   	# Formula: a4 = (a5 + a4 + a4 + a4) >> 2
    	mv tp, a4                	# tp = Old Average
    	slli gp, tp, 1           	# gp = Old Average * 2
    	add tp, tp, gp           	# tp = Old Average * 3
    	add tp, tp, a5           	# tp = Current Sample + (Old Average * 3)
    	srli a4, tp, 2           	# a4 = tp / 4  (This is our new Filtered Average!)

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

# Read SysTick register count
	li x10,R32_STK_SR
	lw x7,0(x10)
	andi x7,x7,0x1
	beqz x7,xxx              # exit as 1ms mark or compare match has not occured
	sw zero,0(x10)		 # clear systick flag
	#calculate speed based on a2 count for 1ms
	#clear a2 for next round
xxx:




    	# --- STATE MACHINE CONTROL LOGIC ---
check_state:
    	li t0, 1
    	beq s1, t0, state_running_fast
    	li t0, 2
    	beq s1, t0, state_running_eco
state_off:
    	# Compressor is currently stopped. Check if it got too warm.
    	# Higher temperature translates to lower ADC values on NTC.
    	li t0, ADC_CUTIN
    	bge a4, t0, maintain_off   # Filtered average is still below target, keep waiting
    
    	# Temperature reached 7°C limit! Engage Compressor (Fast Cooling Mode)
    	call run_5_min_delay 	# Safety delay block for pressure release
    	li s1, 1                   # Update state track variable to 1 (Fast)
    	li a0, 90                  # Target 90% Duty Cycle for maximum pull-down
    	call set_pwm_speed
    	j maintain_off

state_running_fast:
    	# Compressor running max out. Check if we entered the safe/moderate zone.
    	li t0, ADC_CRUISE_ZONE
    	blt a4, t0, keep_running   # Not cold enough yet, stay at max speed
    
    	# Reached the Cruise Zone (~4°C). Switch down to Eco Mode!
    	li s1, 2                   # Update state track variable to 2 (Eco)
    	li a0, 30                  # Target 30% Duty Cycle for low-vibration cruise
    	call set_pwm_speed
    	j keep_running
state_running_eco:
    	# Compressor running quiet. Check if we reached final cutout goal.
    	li t0, ADC_CUTOUT
    	blt a4, t0, keep_running   # Still above 2°C, keep cruising in eco mode
    
    	# Target reached! Shut down compressor entirely
    	li s1, 0                   # Update state track variable to 0 (OFF)
    	li a0, 0                   # Target 0% Duty Cycle
    	call set_pwm_speed

keep_running:
maintain_off:
    	# Simple loop delay to manage execution pacing (~100ms sample interval)
    	li t0, 200000
delay_loop:
    	addi t0, t0, -1
    	bnez t0, delay_loop
    	j main_loop                # Return back to main iteration loop


####SUBROUTINES#########

	# Function: Push updated duty cycle directly to TIM1
set_pwm_speed:
    	addi sp,sp,-8
	sw ra,0(sp)
	sw t0,4(sp)
    	la t0, R16_TIM1_CH1CVR
    	sw a0, 0(t0)     	# Write the a0 argument value directly to compare register
	lw t0,4(sp)
	lw ra,0(sp)
	addi sp,sp,8
    	ret
    	
	# Function: Safety Countdown (Simulated placeholder for delay loop)

run_5_min_delay:
    	addi sp,sp,-8
	sw ra,0(sp)
	sw t2,4(sp)
    	li t2, 482400400      #(2010010 x 60 x 5=603003000), testing at 1 minute 120600100,241200200,361800300,482400400,603000500
delay_loop:
    	addi t2, t2, -1
    	bnez t2, delay_loop
	lw t2,4(sp)
	lw ra,0(sp)
	addi sp,sp,8
    	ret

# --- EXTI3 INTERRUPT SERVICE ROUTINE (ISR) ---
# This special label intercepts the hardware jump whenever pin PD3 goes High.
.global EXTI7_0_IRQhandler
.align 2
EXTI7_0_IRQhandler:
    	# 1. Clear the hardware flag so the interrupt doesn't lock up or re-trigger loop
	addi sp,sp,-8
	sw t0,0(sp)
	sw t1,4(sp)
    	la t0, R32_EXTI_INTFR
    	li t1, (1<<3)              	# Bit 3 = Line 3 Flag
    	sw t1, 0(t0)      		# Writing a 1 to this register clears the flag in RISC-V hardware

    	# 2. Track the Speed Pulse
    	addi a2, a2, 1             	# Increment our speed pulse register tracking counter

    	# 3. Exit the hardware vector block
	lw t1,4(sp)
	lw t0,0(sp)
	addi sp,sp,8
    	mret                       	# Machine-mode interrupt return

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
display_frame:
	addi sp,sp,-16
	sw ra,0(sp)
	sw s1,4(sp)
	sw a0,8(sp)
	sw s0,12(sp)

	li s1,12			# total number of bytes to transmit -sync,pid,data(8),CS
	la x10,frame_buffer		# load address of label "name" to x10, string to be transmitted
frame_loop:
	lbu x8,0(x10)			# 
	call print_hex_byte
	li x8, 0x20             	# Load space character " "
	call USART_TX			# call subroutine USART_TX to transmit byte
	addi x10,x10,1			# 
	addi s1,s1,-1			#
	beqz s1,frame_end		# 
	j frame_loop			# 
frame_end:
	# Print New Line at end of frame
    	li x8, 0x0D             	# \r
    	call USART_TX
    	li x8, 0x0A             	# \n
    	call USART_TX
	lw s0,12(sp)
	lw a0,8(sp)
	lw s1,4(sp)
	lw ra,0(sp)
	addi sp,sp,16
	ret
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

#==========================================
display_register:
	addi sp,sp,-16
	sw ra,0(sp)
	sw s1,4(sp)
	sw a0,8(sp)
	sw s0,12(sp)

	li s1,4				# total number of bytes to transmit 
	la x10,modulo			# load address of label "name" to x10, string to be transmitted
	addi x10,x10,3
reg_loop:
	lbu x8,0(x10)			# 
	call print_hex_byte
	li x8, 0x20             	# Load space character " "
	call USART_TX			# call subroutine USART_TX to transmit byte
	addi x10,x10,-1			# 
	addi s1,s1,-1			#
	beqz s1,reg_end			# 
	j reg_loop			# 
reg_end:
	# Print New Line at end of frame
    	li x8, 0x0D             	# \r
    	call USART_TX
    	li x8, 0x0A             	# \n
    	call USART_TX
	lw s0,12(sp)
	lw a0,8(sp)
	lw s1,4(sp)
	lw ra,0(sp)
	addi sp,sp,16
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
############################################################	
displayresult2:        
		addi sp,sp,-16
		sw ra,0(sp)
		sw x6,4(sp)
		sw a0,8(sp)
		sw x8,12(sp)
		li x6,10		# counter loaded with number of bytes, 6bytes for -xxx.x
		la a0,mem		# load ddress of mem where bytes are stored

writeloop2:
		lb x8,0(a0)		# load 1 bytes from msb >>> lsb
		call USART_TX
		
		addi a0,a0,1
		addi x6,x6,-1
		bnez x6,writeloop2

		lw x8,12(sp)
		lw a0,8(sp)
		lw x6,4(sp)
		lw ra,0(sp)
		addi sp,sp,16
		ret   

###################################################################
# Function: setup_clock
# a0: 0=8MHz, 1=24MHz, 2=48MHz
setup_clock:
	addi sp,sp,-20
	sw ra,0(sp)
	sw t0,4(sp)
	sw t1,8(sp)
	sw t2,12(sp)
	sw tp,16(sp)
    	li t0, R32_RCC_CTLR
    	li t1, R32_FLASH_ACTLR

    	# --- 1. Handle Flash Wait States ---
    	# At 48MHz, we MUST have 1 wait state. 
    	# At 8/24MHz, 0 wait states is optimal for speed.
    	li t2, 2
    	blt a0, t2, .Llow_speed_flash

       	li t2, 0x01                # 1 Wait State (for 48MHz)# Bit 0: Latency (1 wait state)   
    	sw t2, 0(t1)               # FLASH_ACTLR
    	j .Lclock_logic

.Llow_speed_flash:
    	sw x0, 0(t1)               # 0 Wait States (for 8/24MHz)

.Lclock_logic:
    	# --- 2. Branch based on a0 ---
    	li t2, 0
    	beq a0, t2, .Lset_8        # Case 0
    	li t2, 1
    	beq a0, t2, .Lset_24       # Case 1
    	# Else, fall through to 48MHz

    	# --- 48MHz Logic (HSI x 2 PLL) ---
    	# Ensure HSI Prescaler is DIV1 before enabling PLL
    	lw t2, 0x04(t0)            # Read RCC_CFGR0
    	li tp, ~(0xF0)         	   # Mask for HSIPRE bits
    	and t2, t2, tp
    	sw t2, 0x04(t0)            # HSIPRE = DIV1

    	# Enable PLL
    	lw t2, 0(t0)               # Read RCC_CTLR
    	li tp, (1 << 24)           # PLLON
    	or t2, t2, tp
    	sw t2, 0(t0)

.Lwait_pll_ready:
    	lw t2, 0(t0)
    	li tp, (1 << 25)           # PLLRDY
    	and t2, t2, tp
    	beqz t2, .Lwait_pll_ready

    	# Switch System Clock (SW) to PLL
    	lw t2, 0x04(t0)
    	li tp, ~0x03               # Clear SW bits
    	and t2, t2, tp
    	ori t2, t2, 0x02           # 02 = PLL selected
    	sw t2, 0x04(t0)

.Lwait_pll_switch:
    	lw t2, 0x04(t0)
    	andi t2, t2, 0x0C          # Mask SWS (System Clock Switch Status)
    	li tp, 0x08                # 08 = PLL used as SYSCLK
    	bne t2, tp, .Lwait_pll_switch
	j exit_clk_set
    	#ret

.Lset_8:
    	# Set HSIPRE to DIV3 (24MHz / 3 = 8MHz)
    	lw t2, 0x04(t0)
    	li tp, ~(0x1F << 27)       # Clear HSIPRE
    	and t2, t2, tp
    	li tp, (2 << 27)           # 2 = DIV3 for HSI
    	or t2, t2, tp
    
    	# Ensure SW is back to HSI (00)
    	li tp, ~0x03
    	and t2, t2, tp
    	sw t2, 0x04(t0)
	j exit_clk_set
    	#ret

.Lset_24:
    	# Set HSIPRE to DIV1 and SW to HSI
    	lw t2, 0x04(t0)
    	li tp, ~(0xF << 4 | 0x03) # Clear HSIPRE and SW bits
    	and t2, t2, tp
    	sw t2, 0x04(t0)
exit_clk_set:
	lw tp,16(sp)
	lw t2,12(sp)
	lw t1,8(sp)
	lw t0,4(sp)
	lw ra,0(sp)
	addi sp,sp,20
    	ret


#############################################################
# Optimized RV32I Division (Quotient in a0, Remainder in a1)
# a0 = dividend, a1 = divisor (t0,t1,t2,a0,a1)
	    
div_fast:
	    addi sp,sp,-16
	    sw ra,0(sp)
	    sw t0,4(sp)
	    sw t1,8(sp)
	    sw t2,12(sp)
	    beqz a1, div_by_zero   # If delta is 0, return 0
	    li t0, 32          # Loop counter
	    li t1, 0           # Clear remainder
loop:
	    slli t1, t1, 1     # Shift remainder
	    srli t2, a0, 31    # Get MSB of dividend
	    or   t1, t1, t2    # Pull MSB into remainder
	    slli a0, a0, 1     # Shift dividend (building quotient here)

	    bltu t1, a1, skip  # If Rem < Divisor, skip sub
	    sub  t1, t1, a1    # Subtract divisor
	    ori  a0, a0, 1     # Set quotient bit
skip:
	    addi t0, t0, -1
	    bnez t0, loop
	    mv a1, t1          # Move remainder to a1 for return
	    j end_fast_div
div_by_zero:
	    li a0,0            # answer is 0 if div by 0
end_fast_div:
	    lw t2,12(sp)
	    lw t1,8(sp)
	    lw t0,4(sp)
	    lw ra,0(sp)
	    addi sp,sp,16
	    ret

###################################################################################


.align 4
.section .rodata
.global message
message1: .asciz "compressor control 1 online\r\n "

#############################################################



