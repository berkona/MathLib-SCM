# A small math and PRNG library for single-cycle MIPS
# Usage: copy full text of this file into your project file and use 'jal' to access functions
# I have attempted to outline the edge cases of the functions below that I know of,
# but I make no guarantee that I have described all edge cases or that the code will work on your system
# Copyright 2016 Jon Monroe, released under the MIT License

.data

# This is the seed for rand32, modify as needed, 
# but it must be non-zero in all words
# (Maybe just in one word, but I haven't tested that)
# XORSHIFT will always produce zero if the previous value is zero
# so if you're getting a bunch of zeros back from rand32
# you likely haven't initialized randState correctly 
randState: .word 0x3320E3C1, 0x0023A23F, 0x010C2FD3, 0xF6C7F0E7

.text

# $v0 = $a0 * $a1
# Performs *unsigned* multiplication by shifting and adding partial products of a * b
# By definition, a binary mulplication result is 2x the number of digits in the operands.
# So, if trying to multiply very large numbers, the result will overflow,
# producing unexpected results such as sign flipping, result being less than a or b, etc.
# Thus, I can only guarantee it's functionality up to 0x7FFF * 0x7FFF.
# It may or may not work for larger operands, but it's up to you to make sure you handle them right.
mult:
	# p = 0 * X = 0
	# p = 1 * X = X
	# p = digit & X

	# muplicand = $a0
	# multiplier = $a1

	# say m = 10_d, r = 10_d
	# m = 1010_b
	# r = 1010_b

	# p = m * r = 1010_b * 1010_b = 1100100_b
	
	# p = m * r[0] + m * r[1] + m * r[2] ... etc
	# p = 1010 << 1 + 1010 << 3
	# p =   10100 
	#   + 1010000 
	# 	= 1100100

	# load in our multiplier pattern beforehand
	addi $t0 $0 -1

	# load in our bit isolate pattern
	addi $t1 $0 1

	# $v0 = sum = 0
	add $v0 $0 $0

	partialProduct:
	
	ble $a1 $0 end_partialProduct
	
	# isolate single digit
	and $t3 $a1 $t1

	# f(x) = -x
	xor $t3 $t3 $t0
	addi $t3 $t3 1
	# partial_product = $a0 & f(x)
	and $t3 $a0 $t3

	# ret = ret + part
	add $v0 $v0 $t3
	
	# shift multiplicand by 1
	sll $a0 $a0 1
	
	# shift multiplier by 1
	srl $a1 $a1 1
	
	j partialProduct
	end_partialProduct:	

	# product is in $v0

	jr $ra


# Performs *unsigned* division using standard binary long division algorithm
# Accepts the arguments of $a0 = Numerator, $a1 = Divisor
# $v0 will be $a0 / $a1 (i.e., proper division result)
# $v1 will be $a0 % $a1 (i.e., the remainder of division)
# Division by zero will result in wonky-ness
div:
	add $v0 $0 $0
	add $v1 $0 $0
	addi $t0 $0 31
	# select 31st digit and go down to zeroth
	or $t1 $0 $0
	lui $t1 0x8000
	or $t1 $t1 $0
	div_loop:
		# R = R << 1
		sll $v1 $v1 1
		# select ith digit of numerator, N(i)
		and $t2 $a0 $t1
		srlv $t2 $t2 $t0
		# set R(0) to N(i)
		or $v1 $v1 $t2
		# R >= D
		blt $v1 $a1 div_endif
			# R = R - D
			sub $v1 $v1 $a1
			or $v0 $v0 $t1
		div_endif:
		srl $t1 $t1 1
		addi $t0 $t0 -1
	bge $t0 $0 div_loop
	jr $ra


# slow mod using division
# If you want to do x % 2^d where d is a natural number
# Then consider using x & 2^d - 1
# $a0 = Numerator, $a1 = divisor, $v0 = N % D
mod:
   	addi $sp $sp -4
   	sw $ra 0($sp)
   	
   	jal div
   	
	or $v0 $v1 $0
	
	lw $ra 0($sp)
	addi $sp $sp 4
	jr $ra
	

# No arguments, produces a random number in range [0, 1] in $v0
rand2:
	addi $sp $sp -4
	sw $ra 0($sp)
	
	jal rand32
	
	add $t0 $0 1
	and $v0 $v0 $t0
	
	lw $ra 0($sp)
	addi $sp $sp 4
	jr $ra
	

# No arguments, produces a random number in range [0, 3] in $v0
rand4:
	addi $sp $sp -4
	sw $ra 0($sp)
	
	jal rand32
	
	# mod 4 = x and 2'b11
	add $t0 $0 3
	and $v0 $v0 $t0
	
	lw $ra 0($sp)
	addi $sp $sp 4
	jr $ra


# No arguments, produces a random number in range [0, 7] in $v0
rand8:
	addi $sp $sp -4
	sw $ra 0($sp)
	jal rand32
	add $t0 $0 7
	and $v0 $v0 $t0
	lw $ra 0($sp)
	addi $sp $sp 4
	jr $ra


# $a0 = inclusive low, $a1 = exlusive high
# Produces a random int in the range [$a0, $a1)
# is somewhat slow (upwards of 100 cycles) due to division modulus
# If faster random nums are needed, try to use the above rand functions
# If 2^32 % $a1 != 0 the number will be biased by the modulo op.  
# I leave it up to the user whether that's an issue. For one of many strategies to remove it,
# see http://funloop.org/post/2013-07-12-generating-random-numbers-without-modulo-bias.html
randInt:
	addi $sp $sp -8
	sw $ra 0($sp)
	sw $s0 4($sp)

	jal rand32

	add $a0 $v0 $0
	sub $a1 $a1 $s0

	jal mod

	add $v0 $v0 $s0

	lw $ra 0($sp)
	lw $s0 4($sp)
	addi $sp $sp 8

	jr $ra


# Implements a 128 XORSHIFT PRNG
# Accepts no arguments
# $v0 is a random 32-bit number with a theoretical period of 2^128
# Interpret this number as needed for your application
# In practice, it likely doesn't have anywhere near as long a period
# and I make no guarantees as to the statistical properties
# of the random numbers produced by this PRNG
# Using a modulo operation to reduce this number to a range of [0, n)
# where n is not evenly divisible by 2^32 will cause modulo bias
# I chose to use XORSHIFT instead of any other algorithms due to the speed
# at which it can produce decent random numbers on our hardware
# The following implementation will execute in < 20 clocks
rand32:
	# t = x
	lw $t0 randState
	# t ^= t << 11
	sll $t1 $t0 11
	xor $t0 $t0 $t1
	# t ^= t >> 8
	srl $t1 $0 8
	xor $t0 $t0 $t1

	# x = y
	lw $t1 randState + 4
	sw $t1 randState
	# y = z
	lw $t1 randState + 8
	sw $t1 randState + 4
	# z = w
	lw $t1 randState + 12
	sw $t1 randState + 8

	# w ^= w >> 19
	lw $t1 randState + 12
	srl $t2 $t1 19
	xor $t1 $t1 $t2
	# w ^= t
	xor $t1 $t1 $t0

	# save w & return w
	sw $t1 randState + 12
	or $v0 $t1 $0
	jr $ra

