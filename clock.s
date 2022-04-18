.bss
	.lcomm timespec, 16
	.comm secs, 8
	.comm nsecs, 8
.text
.globl secs
.globl nsecs
.globl get_time
.globl merge_timestamp
.globl split_timestamp
.globl sleep
.globl sleep_until
.set CLOCK_MONOTONIC, 1
.set TIMER_ABSTIME, 1
.set CLOCK_GETTIME, 228
.set CLOCK_NANOSLEEP, 230

get_time:
	movq $CLOCK_GETTIME, %rax
	movq $CLOCK_MONOTONIC, %rdi
	leaq timespec(%rip), %rsi
	syscall
	
	leaq secs(%rip), %rax
	leaq nsecs(%rip), %rdi
	movq (%rsi), %rdx
	movq %rdx, (%rax)
	movq 8(%rsi), %rdx
	movq %rdx, (%rdi)

	movq (%rsi), %rax
	movq 8(%rsi), %rdx
	
	ret
# converts %rax:%rdx (s:ns) timestamp into
# %rax (ns) timestamp
merge_timestamp:
	pushq %rdx
	movq $1000000000, %rdx
	mulq %rdx
	popq %rdx
	addq %rdx, %rax

	ret
# converts %rax (ns) timestamp into
# %rax:%rdx (s:ns) timestamp
split_timestamp:
	xorq %rdx, %rdx
	movq $1000000000, %rdi
	divq %rdi

	ret
# sleeps %rax seconds and %rdx nanoseconds
sleep:
	leaq timespec(%rip), %rdi
	movq %rax, (%rdi)
	movq %rdx, 8(%rdi)

	movq $CLOCK_NANOSLEEP, %rax
	movq $CLOCK_MONOTONIC, %rdi
	xorq %rsi, %rsi
	leaq timespec(%rip), %rdx
	xorq %r10, %r10
	syscall
	ret
# sleep until the timestamp specified by %rax seconds and %rdx nanoseconds
sleep_until:
	leaq timespec(%rip), %rdi
	movq %rax, (%rdi)
	movq %rdx, 8(%rdi)

	movq $CLOCK_NANOSLEEP, %rax
	movq $CLOCK_MONOTONIC, %rdi
	movq $TIMER_ABSTIME, %rsi
	leaq timespec(%rip), %rdx
	xorq %r10, %r10
	syscall
	ret
