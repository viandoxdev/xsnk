.section rodata
	dir_map: .short 0, -1, -1, 0, 0, 1, 1, 0
.bss
	# 2048 is the max length
	.comm snake, 4*2048
	.comm snakel, 8
	# dirrection of the head
	# N: 0001 (1), W: 0010 (2), S: 0100 (4), E: 1000 (8)
	.comm dir, 1
	# array of updates:
	# struct update {
	# 	unsigned short x         ( 0 ->  2, 2)
	#	unsigned short y         ( 2 ->  4, 2)
	#	void * ascii             ( 4 -> 12, 8)
	#	unsigned short ascii_len (12 -> 14, 2)
	#	unsigned short has_next  (14 -> 16, 2)
	# }
	.comm draw_updates, 8*16
	.comm apple, 4
	.comm score, 8
.text
	mln: .ascii "\n"
	gfx_snk: .ascii "\033[44m  \033[0m"
	gfx_apl: .ascii "\033[101m  \033[0m"
	gfx_clr: .ascii "  "
	header: .ascii "\033[1mxsnk \033[0m\033[2mv0.1 \033[0m(\033[32m\033[1mESC \033[0mto exit)\n\n"
	err_screensize: .ascii "\033[1m\033[31mERR screen is too small to play !\033[0m\n"
	death_message: .ascii "You died with a score of "

.set NORTH, 1
.set WEST, 2
.set SOUTH, 4
.set EAST, 8

.set TRUE, 1
.set FALSE, 0

.set SYS_WRITE, 1
.set SYS_EXIT, 60
.set STDOUT, 1

.set MIN_WIDTH, 8*2
.set MIN_HEIGHT, 3
ln:
	movq $SYS_WRITE, %rax
	movq $STDOUT, %rdi
	leaq mln(%rip), %rsi
	movq $1, %rdx
	syscall
	ret
# print error and exit
# pointer to err msg goes into %rsi
# length of said msg goes into %rdx
exit_err:
	movq $SYS_WRITE, %rax
	movq $STDOUT, %rdi
	syscall

	movq $SYS_EXIT, %rax
	movq $1, %rdi
	syscall
# querries the size (will be in width and height)
# and make that it is big enough (exits if not)
assert_size:
	call get_size

	# setup error message
	leaq err_screensize(%rip), %rsi
	movq $48, %rdx

	# check width
	leaq width(%rip), %rax
	movq (%rax), %rax
	cmpq $MIN_WIDTH, %rax
	jb exit_err

	# check height
	leaq height(%rip), %rax
	movq (%rax), %rax
	cmpq $MIN_HEIGHT, %rax
	jb exit_err

	ret
# place apple in "random" spot (assumes width and height init)
place_apple:
	# read clock to %rax:%rdx
	rdtsc
	lfence

	# copy low order bits of clock
	movq %rax, %rsi
	shr $2, %rax

	leaq apple(%rip), %rcx

	leaq width(%rip), %rdi
	movq (%rdi), %rdi
	# divide by two the width as a point in the grid is two wide
	shr $1, %rdi
	xorq %rdx, %rdx
	divq %rdi
	movw %dx, (%rcx)

	movq %rsi, %rax
	leaq height(%rip), %rdi
	movq (%rdi), %rdi
	xorq %rdx, %rdx
	divq %rdi
	movw %dx, 2(%rcx)

	ret
# init game (assumes width and height init)
init:
	leaq width(%rip), %rax
	leaq height(%rip), %rdx
	movq (%rax), %rax
	movq (%rdx), %rdx

	# compute center coordinates
	shr $2, %rax
	shr $1, %rdx

	leaq snake(%rip), %rdi

	decw %ax
	movw %ax, (%rdi)
	movw %dx, 2(%rdi)

	decw %ax
	movw %ax, 4(%rdi)
	movw %dx, 6(%rdi)

	decw %ax
	movw %ax, 8(%rdi)
	movw %dx, 10(%rdi)

	decw %ax
	movw %ax, 12(%rdi)
	movw %dx, 14(%rdi)

	leaq snakel(%rip), %rdi
	movq $4, (%rdi)

	call place_apple

	leaq score(%rip), %rdi
	movq $0, (%rdi)

	# set dirrection
	leaq dir(%rip), %rdi
	movq $8, (%rdi)

	ret
draw_full:
	call clear_screen
	
	xorq %rax, %rax
	xorq %rdx, %rdx
	# draw apple
	leaq apple(%rip), %rdi
	movw (%rdi), %ax
	movw 2(%rdi), %dx
	shl $1, %rax
	call set_cursor

	movq $SYS_WRITE, %rax
	movq $STDOUT, %rdi
	leaq gfx_apl(%rip), %rsi
	movq $12, %rdx
	syscall

	# draw score
	leaq score(%rip), %rax
	movq (%rax), %rax
	call qstring_unsigned 

	leaq width(%rip), %rax
	movq (%rax), %rax
	shr $1, %rax
	leaq qstrl(%rip), %rdx
	movq (%rdx), %rdx
	shr $1, %rdx
	subq %rdx, %rax
	movq $1, %rdx
	call set_cursor

	movq $SYS_WRITE, %rax
	movq $STDOUT, %rdi
	leaq qstr(%rip), %rsi
	leaq qstrl(%rip), %rdx
	movq (%rdx), %rdx
	syscall

	# draw snake body
	leaq snake(%rip), %r8
	leaq snakel(%rip), %r10
	movq (%r10), %r10
	# multiply length by two as there are two
	# components to each elements
	shl $1, %r10
	xorq %r9, %r9

	draw_full_snake_loop:
		xorq %rax, %rax
		xorq %rdx, %rdx

		movw (%r8, %r9, 2), %ax
		shl $1, %rax
		incq %r9
		movw (%r8, %r9, 2), %dx

		pushq %r9
		pushq %r8
		call set_cursor
		popq %r8
		popq %r9

		movq $SYS_WRITE, %rax
		movq $SYS_EXIT, %rdi
		leaq gfx_snk(%rip), %rsi
		movq $11, %rdx
		syscall
		incq %r9

		cmp %r10, %r9
		jb draw_full_snake_loop

	ret

# update game state
update:
	pushq %r15

	leaq draw_update(%rip), %r15
	leaq snake(%rip), %rax
	leaq snakel(%rip), %rdx
	movq (%rdx), %rdx
	decq %rdx
	# put coordinates of tail into %rcx
	movl (%rax, %rdx, 4), %ecx

	# write update
	movl %ecx, (%r15) # write x and y
	leaq gfx_clr(%rip), %rcx
	movq %rcx, 4(%r15) # write ascii
	movw $11, 12(%r15) # write ascii_len
	movw $TRUE, 14(%r15) # write has  next
	# move pointer to next update entry
	addq $2, %r15

	# rdx still holds snake_len - 1
	incq %rdx # increase
	# rdi is the index
	xorq %rdi, %rdi

	# this loop shifts all the elements of the snake
	# i.e: A,B,C,D,E -> A,A,B,C,D,E
	# (E is out of the array, but still in memory)

	update_shift_snake:
		movl (%rax, %rdi, 4), %ecx
		incq %rdi
		movl %ecx, (%rax, %rdi, 4)

		cmp %rdx, %rdi
		jb update_shift_snake
	
	# move the head
	xorq %rsi, %rsi
	xorq %rdi, %rdi
	# rsi is the x, rdi is the  y
	movw (%rax), %si
	movw 2(%rax), %di

	leaq dir(%rip), %rcx
	# log2 of dir
	bsrq (%rcx), %rcx
	shl $1, %rcx # rcx is now 0, 2, 4, 6

	leaq dir_map(%rip), %rdx
	addq (%rdx, %rcx, 2), %rsi
	addq 2(%rdx, %rcx, 2), %rdi

	# put new head in array
	movw %si, (%rax)
	movw %di, 2(%rax)

	# write update
	movw %si, (%r15) # x
	movw %di, 2(%r15) # y
	leaq gfx_snk(%rip), %rdx
	movq %rdx, 4(%r15) # ascii
	movw $7, 12(%r15) # ascii_len
	# this could be overwritten later
	movw $FALSE, 14(%r15) # has next
	# advance update pointer
	addq $16, %r15

	# death check
	leaq width(%rip), %rcx
	movq (%rcx), %rcx
	shrq $1, %rcx
	leaq height(%rip), %rdx
	movq (%rdx), %rdx

	# the coordinates of the head remains in rsi and rdi
	cmp $0, %rsi
	jl death
	cmp %rcx, %rsi
	jge death

	cmp $0, %rdi
	jl death
	cmp %rdx, %rdi
	jge death
	
	leaq snake(%rip), %rax
	leaq snakel(%rip), %rdx
	movq (%rdx), %rdx
	movq $1, %rcx

	# move coordinates of head into rdi
	movl (%rax), %edi

	update_body_check:
		cmpl (%rax, %rcx, 4), %edi
		je death

		incq %rcx
		cmpq %rdx, %rcx
		jb update_body_check

	# apple check
	# coordinates of head is in rdi
	leaq apple(%rip), %rdx
	cmpl (%rdx), %edi
	jne update_apple_check_end

	leaq score(%rip), %rax
	incq (%rax)
	leaq snakel(%rip), %rax
	incq (%rax)
	# overwrite first update (the one that removes the tail)
	# to not do anything
	leaq draw_update(%rip), %rax
	leaq gfx_snk(%rip), %rcx
	movq %rcx, 4(%rax)
	movq $7, 12(%rax)

	call place_apple
	# overwrite hass_next of last update
	movw $TRUE, -2(%r15)
	# add apple to updates
	leaq apple(%rip), %rax
	movl (%rax), %eax
	movl %eax, (%r15) # x and y
	leaq gfx_apl(%rip), %rax
	movq %rax, 4(%r15)
	movq $8, 12(%r15)
	movq $FALSE, 14(%r15)

	update_apple_check_end:

	popq %r15
	ret
draw_update:
	pushq %r15
	leaq draw_update(%rip), %r15

	draw_update_loop:
		xorq %rax, %rax
		xorq %rdx, %rdx

		movw (%r15), %ax
		movw 2(%r15), %dx
		call set_cursor

		xorq %rdx, %rdx
		movq $SYS_WRITE, %rax
		movq $STDOUT, %rdi
		movq 4(%r15), %rsi
		movw 12(%r15), %dx
		syscall

		cmpw $TRUE, 14(%r15)
		je draw_update_loop

	popq %r15
	ret
death:
	movq $SYS_WRITE, %rax
	movq $STDOUT, %rdi
	leaq death_message(%rip), %rsi
	movq $25, %rdx
	syscall

	leaq score(%rip), %rax
	movq (%rax), %rax
	call qprint_unsigned
	call ln

	movq $SYS_EXIT, %rax
	movq $0, %rdi
	syscall
.globl _start
_start:
	movq $SYS_WRITE, %rax
	movq $STDOUT, %rdi
	leaq header(%rip), %rsi
	movq $54, %rdx
	syscall

	call assert_size
	call enter_alt
	call set_raw
	call hide_cursor

	call init
	call draw_full

	movq $1, %rax
	movq $0, %rdx
	call sleep
	call update
	call draw_update

	movq $1, %rax
	movq $0, %rdx
	call sleep
	call update
	call draw_update

	movq $1, %rax
	movq $0, %rdx
	call sleep
	call update
	call draw_update

	movq $1, %rax
	movq $0, %rdx
	call sleep
	call update
	call draw_update
	
	call leave_alt
	call unset_raw
	call show_cursor

	movq $SYS_EXIT, %rax
	movq $0, %rdi
	syscall

