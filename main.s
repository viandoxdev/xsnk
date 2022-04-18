.bss
	# struct position {
	# 	unsigned short x; (0 -> 2, 2)
	# 	unsigned short y; (2 -> 4, 2)
	# } (4 bytes total)
	# array of position of the snake's body
	# 2048 is the max length
	.comm snake, 4*2048
	# length of the snake
	.comm snakel, 8
	# dirrection of the head
	# N: 0001 (1), W: 0010 (2), S: 0100 (4), E: 1000 (8)
	# this is an array because we buffer them
	# the last 4 bytes are unused and to be left empty
	# (they are read by bsr as it only acts on 64 bits)
	.comm dir, 8
	# array of updates:
	# struct update {
	# 	unsigned short x         ( 0 ->  2, 2)
	#	unsigned short y         ( 2 ->  4, 2)
	#	void * ascii             ( 4 -> 12, 8)
	#	unsigned short ascii_len (12 -> 14, 2)
	#	unsigned short has_next  (14 -> 16, 2)
	# } (16 bytes total)
	.comm draw_updates, 8*16
	# position of the apple
	.comm apple, 4
	# score of the game (should be snake_l - 4)
	.comm score, 8
	# boolean indicating wether the score has changed
	.comm score_updated, 1
	# timestamp for the next scheduled update
	.comm next_update, 8
	# struct used in the poll syscall
	# struct pollfd {
	#	int   fd;      (0 -> 4, 4)
	#	short events;  (4 -> 6, 2)
	#	short revents; (6 -> 8, 2)
	# };
	.comm pollfd, 8
	# 8 bytes buffer to read the input
	.comm input, 8
	# quadword for the length of the read input
	.comm inputl, 8
.text
	dir_map: .quad 0, -1, 0, 1, 0
	# duration of a tick, in nanoseconds
	tick_duration: .quad 120000000
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

.set SYS_READ, 0
.set SYS_WRITE, 1
.set SYS_POLL, 7
.set SYS_EXIT, 60
.set STDOUT, 1
.set STDIN, 0
.set POLLIN, 1

.set KEY_ESC,   0x0000001B # begining goes at the end (endianness ?)
.set KEY_UP,    0x00415B1B # \x1b[A
.set KEY_LEFT,  0x00445B1B # \x1b[D
.set KEY_DOWN,  0x00425B1B # \x1b[B
.set KEY_RIGHT, 0x00435B1B # \x1b[C

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
	movq width(%rip), %rax
	cmpq $MIN_WIDTH, %rax
	jb exit_err

	# check height
	movq height(%rip), %rax
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

	movq width(%rip), %rdi
	# divide by two the width as a point in the grid is two wide
	shr $1, %rdi
	xorq %rdx, %rdx
	divq %rdi
	movw %dx, (%rcx)

	movq %rsi, %rax
	movq height(%rip), %rdi
	xorq %rdx, %rdx
	divq %rdi
	movw %dx, 2(%rcx)

	ret
# init game (assumes width and height init)
init:
	movq width(%rip), %rax
	movq height(%rip), %rdx

	# compute center coordinates
	shr $2, %rax
	shr $1, %rdx

	leaq apple(%rip), %rdi
	movw %ax, (%rdi)
	movw %dx, 2(%rdi)
	addw $4, (%rdi)

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

	movq $4, snakel(%rip)
	movq $0, score(%rip)

	# set dirrection
	movq $EAST, dir(%rip)

	# schedule next (first) update
	call get_time
	call merge_timestamp
	addq tick_duration(%rip), %rax
	movq %rax, next_update(%rip)

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
	movq score(%rip), %rax
	call qstring_unsigned

	movq width(%rip), %rax
	shr $1, %rax
	movq qstrl(%rip), %rdx
	shr $1, %rdx
	subq %rdx, %rax
	movq $1, %rdx
	call set_cursor

	movq score(%rip), %rax
	call qprint_unsigned

	# draw snake body
	leaq snake(%rip), %r8
	movq snakel(%rip), %r10
	decq %r10

	draw_full_snake_loop:
		xorq %rax, %rax
		xorq %rdx, %rdx

		movw (%r8, %r10, 4), %ax
		shl $1, %rax
		movw 2(%r8, %r10, 4), %dx

		pushq %r8
		call set_cursor
		popq %r8

		movq $SYS_WRITE, %rax
		movq $STDOUT, %rdi
		leaq gfx_snk(%rip), %rsi
		movq $11, %rdx
		syscall

		decq %r10
		cmpq $0, %r10
		jge draw_full_snake_loop

	ret

# update game state
update:
	pushq %r15

	# update dirrection

	# compute how many dirrections they currently are - 1
	bsrq dir(%rip), %rax
	shrq $3, %rax

	# dir is an array, the first element is the current
	# dirrection. On update, if there are buffered dirrections
	# dir should be shifted (first one is dropped and replaced by
	# the second). To do that we consider dir as a 32 bit number
	# and bitshift 0 or 8 bits.

	# rcx holds how many bits to shift dir
	movq $0, %rcx
	movq $8, %rdx
	cmpq $0, %rax
	cmova %rdx, %rcx
	shrl %cl, dir(%rip)

	leaq draw_updates(%rip), %r15
	leaq snake(%rip), %rax
	movq snakel(%rip), %rdx
	decq %rdx
	# put coordinates of tail into %rcx
	movl (%rax, %rdx, 4), %ecx

	# write update
	movl %ecx, (%r15) # write x and y
	leaq gfx_clr(%rip), %rcx
	movq %rcx, 4(%r15) # write ascii
	movw $2, 12(%r15) # write ascii_len
	movw $TRUE, 14(%r15) # write has  next
	# move pointer to next update entry
	addq $16, %r15

	# rdx still holds snake_len - 1
	incq %rdx # increase

	# this loop shifts all the elements of the snake
	# i.e: A,B,C,D,E -> A,A,B,C,D,E
	# (E is out of the array, but still in memory)

	update_shift_snake:
		movl -4(%rax, %rdx, 4), %ecx
		movl %ecx, (%rax, %rdx, 4)
		decq %rdx

		test %rdx, %rdx
		jnz update_shift_snake

	# move the head
	xorq %rsi, %rsi
	xorq %rdi, %rdi
	# rsi is the x, rdi is the y
	movw (%rax), %si
	movw 2(%rax), %di

	xorq %rcx, %rcx
	movb dir(%rip), %cl
	# log2 of dir
	bsrq %rcx, %rcx

	leaq dir_map(%rip), %rdx
	addq (%rdx, %rcx, 8), %rsi
	addq 8(%rdx, %rcx, 8), %rdi

	# put new head in array
	movw %si, (%rax)
	movw %di, 2(%rax)

	# write update
	movw %si, (%r15) # x
	movw %di, 2(%r15) # y
	leaq gfx_snk(%rip), %rdx
	movq %rdx, 4(%r15) # ascii
	movw $11, 12(%r15) # ascii_len
	# this could be overwritten later
	movw $FALSE, 14(%r15) # has next
	# advance update pointer
	addq $16, %r15

	# death check
	movq width(%rip), %rcx
	shrq $1, %rcx
	movq height(%rip), %rdx

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
	movq snakel(%rip), %rdx
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

	incq score(%rip)
	movb $TRUE, score_updated(%rip)
	incq snakel(%rip)
	# overwrite first update (the one that removes the tail)
	# to not do anything
	leaq draw_updates(%rip), %rax
	leaq gfx_snk(%rip), %rcx
	movq %rcx, 4(%rax)
	movw $11, 12(%rax)

	call place_apple

	# overwrite has_next of last update
	movw $TRUE, -2(%r15)
	# add apple to updates
	movl apple(%rip), %eax
	movl %eax, (%r15) # x and y
	leaq gfx_apl(%rip), %rax
	movq %rax, 4(%r15)
	movw $12, 12(%r15)
	movw $FALSE, 14(%r15)

	update_apple_check_end:

	popq %r15
	ret
draw_update:
	pushq %r15

	leaq score_updated(%rip), %rax
	cmpb $TRUE, (%rax)
	jne draw_updates_score_end

	movb $FALSE, (%rax)

	movq score(%rip), %rax
	call qstring_unsigned

	movq width(%rip), %rax
	shr $1, %rax
	movq qstrl(%rip), %rdx
	shr $1, %rdx
	subq %rdx, %rax
	movq $1, %rdx
	call set_cursor

	movq score(%rip), %rax
	call qprint_unsigned

	draw_updates_score_end:

	leaq draw_updates(%rip), %r15

	draw_update_loop:
		xorq %rax, %rax
		xorq %rdx, %rdx

		movw (%r15), %ax
		shlq $1, %rax
		movw 2(%r15), %dx
		call set_cursor

		xorq %rdx, %rdx
		movq $SYS_WRITE, %rax
		movq $STDOUT, %rdi
		movq 4(%r15), %rsi
		movw 12(%r15), %dx
		syscall

		# save has_next to rax
		movw 14(%r15), %ax

		# clear entry
		movq $0, (%r15)
		movq $0, 8(%r15)

		addq $16, %r15

		cmpq $TRUE, %rax
		je draw_update_loop

	popq %r15
	ret
handle_input:
	# length of dir -1
	bsrq dir(%rip), %rax
	shrq $3, %rax

	cmpq $1, inputl(%rip)
	je hi_1
	cmpq $3, inputl(%rip)
	je hi_3

	# if message isn't 1 or 3 bytes long, ignore,
	# as it isn't something we care about
	jmp hi_end

	hi_1:
		cmpb $KEY_ESC, input(%rip)
		je exit
	hi_3:
		# if the buffer is full, skip
		cmpq $3, %rax
		jae hi_end

		leaq dir(%rip), %rdx

		cmpl $KEY_UP, input(%rip)
		je hi_up

		cmpl $KEY_LEFT, input(%rip)
		je hi_left

		cmpl $KEY_DOWN, input(%rip)
		je hi_down

		cmpl $KEY_RIGHT, input(%rip)
		je hi_right

		# input isn't known, ignore
		jmp hi_end

		hi_up:
			cmpb $SOUTH, (%rdx, %rax, 1)
			je hi_end # can't go north when snake goes south
			movb $NORTH, 1(%rdx, %rax, 1)
			jmp hi_end
		hi_left:
			cmpb $EAST, (%rdx, %rax, 1)
			je hi_end # can't go west when snake goes east
			movb $WEST, 1(%rdx, %rax, 1)
			jmp hi_end
		hi_down:
			cmpb $NORTH, (%rdx, %rax, 1)
			je hi_end # can't go south when snake goes north
			movb $SOUTH, 1(%rdx, %rax, 1)
			jmp hi_end
		hi_right:
			cmpb $WEST, (%rdx, %rax, 1)
			je hi_end # can't go east when snake goes west
			movb $EAST, 1(%rdx, %rax, 1)
			jmp hi_end # for symmetry
	hi_end:
		# clear inpupt buffer, this ensures that after each read,
		# all bytes past the read length are 0.
		movq $0, input(%rip)
	ret
cleanup:
	call leave_alt
	call unset_raw
	call show_cursor
	ret
death:
	call cleanup

	movq $SYS_WRITE, %rax
	movq $STDOUT, %rdi
	leaq death_message(%rip), %rsi
	movq $25, %rdx
	syscall

	movq score(%rip), %rax
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

	# setup pollfd
	leaq pollfd(%rip), %rax
	movl $STDIN, (%rax)
	movw $POLLIN, 4(%rax)

	loop:
		call get_time
		call merge_timestamp
		movq %rax, %rdx
		movq next_update(%rip), %rax
		subq %rdx, %rax
		# jump if rax is negative meaning we passed our deadline
		js update_game
		xorq %rdx, %rdx
		# divide by 1M (ns -> ms)
		movq $1000000, %rdi
		divq %rdi

		movq %rax, %rdx # timeout
		movq $SYS_POLL, %rax
		leaq pollfd(%rip), %rdi
		movq $1, %rsi # number of fd
		syscall

		# if rax is 0, the poll stoppe because of the timeout
		# so we jump to update
		test %rax, %rax
		jz update_game

		# if we're still here that means the poll worked and there
		# is things to be read

		# read single char
		movq $SYS_READ, %rax
		movq $STDIN, %rdi
		leaq input(%rip), %rsi
		movq $8, %rdx # read 3 bytes
		syscall

		# write number of read bytes to inputl
		movq %rax, inputl(%rip)

		call handle_input
		# jump back to begining of loop to see if there is more input
		jmp loop

		update_game:

		call update
		call draw_update
		movq tick_duration(%rip), %rax
		addq %rax, next_update(%rip)
		jmp loop

	exit:

	call cleanup

	movq $SYS_EXIT, %rax
	movq $0, %rdi
	syscall

