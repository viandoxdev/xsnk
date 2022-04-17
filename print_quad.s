.data
	# longest possible number in 64 bits
	qstr: .ascii "00000000000000000000"
	qstrl: .quad 0
.text
.globl qstr
.globl qstrl
.globl qprint_signed
.globl qprint_unsigned
.globl qstring_signed
.globl qstring_unsigned

qstr_rev:
	leaq qstr(%rip), %r8
	leaq qstrl(%rip), %rdx
	movq (%rdx), %rdx

	# rax is the left end index
	# rdx is the right end index
	xorq %rax, %rax
	decq %rdx

qstrrevloop:
	movb (%r8, %rax, 1), %dil
	movb (%r8, %rdx, 1), %cl
	movb %dil, (%r8, %rdx, 1)
	movb %cl, (%r8, %rax, 1)

	incq %rax
	decq %rdx

	cmpq %rdx, %rax
	# important as %rdx can be -1
	jl qstrrevloop

	ret
# convert number in %rax to string (as unsigned)
# result goes into qstr and qstrl.
qstring_unsigned:
	leaq qstr(%rip), %r8
	leaq qstrl(%rip), %r9

	movq $10, %rdi
	# rsi holds the length
	xorq %rsi, %rsi

qstruloop:
	xorq %rdx, %rdx

	# %rax <- %rax / 10
	# %rdx <- %rax % 10
	divq %rdi
	# 48 is '0'
	addq $48, %rdx
	# put resulting char into the string
	movb %dl, (%r8, %rsi, 1)
	incq %rsi

	test %rax, %rax
	jnz qstruloop
	
	# move length into qstrl
	movq %rsi, (%r9)
	# reverse the string
	call qstr_rev

	ret
# convert number in %rax to string (as signed)
# result goes into qstr and qstrl.
qstring_signed:
	# for comments see qstring_unsigned
	leaq qstr(%rip), %r8
	leaq qstrl(%rip), %r9

	# save to check for the sign later
	movq %rax, %rcx
	# compute absolute of rax
	negq %rax
	cmovs %rcx, %rax

	movq $10, %rdi
	xorq %rsi, %rsi
qstrsloop:
	xorq %rdx, %rdx
	divq %rdi
	addq $48, %rdx
	movb %dl, (%r8, %rsi, 1)
	incq %rsi

	test %rax, %rax
	jnz qstrsloop

	# add minus sign at the end of the string
	movb $45, (%r8, %rsi, 1)
	# rdi is 0, rdx is 1
	xorq %rdi, %rdi
	movq $1, %rdx
	# set rdi to 1 if rcx is negative (rcx is the original number)
	test %rcx, %rcx
	cmovs %rdx, %rdi
	# add rdi into the length of the string
	addq %rdi, %rsi
	
	movq %rsi, (%r9)
	call qstr_rev
	ret
# print number in %rax
qprint_unsigned:
	# convert %rax to string
	call qstring_unsigned
	movq $1, %rax
	movq $1, %rdi
	leaq qstr(%rip), %rsi
	leaq qstrl(%rip), %rdx
	movq (%rdx), %rdx
	syscall
	ret
qprint_signed:
	call qstring_signed
	movq $1, %rax
	movq $1, %rdi
	leaq qstr(%rip), %rsi
	leaq qstrl(%rip), %rdx
	movq (%rdx), %rdx
	syscall
	ret
