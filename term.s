.bss
	.lcomm termios 60
	.lcomm winsize 8
	.comm width 8
	.comm height 8
.text
	c_show: .ascii "\033[?25h"
	c_hide: .ascii "\033[?25l"
	c_save: .ascii "\0337"
	c_restore: .ascii "\0338"
	alt_enter: .ascii "\033[?47h"
	alt_leave: .ascii "\033[?47l"
	s_clear: .ascii "\033[2J]"
	csi: .ascii "\033["
	smcln: .ascii ";"
	H: .ascii "H"

.globl width
.globl height

.globl set_raw
.globl unset_raw
.globl get_size
.globl enter_alt
.globl leave_alt
.globl clear_screen
.globl set_cursor
.globl hide_cursor
.globl show_cursor
# move cursor to row %rax, and col %rdx
set_cursor:
	# the escape sequence we're using is 1 indexed
	incq %rax
	incq %rdx
	pushq %rax
	pushq %rdx
	movq $1, %rax
	movq $1, %rdi
	leaq csi(%rip), %rsi
	movq $2, %rdx
	syscall
	popq %rax
	call qprint_unsigned
	movq $1, %rax
	movq $1, %rdi
	leaq smcln(%rip), %rsi
	movq $1, %rdx
	syscall
	popq %rax
	call qprint_unsigned
	movq $1, %rax
	movq $1, %rdi
	leaq H(%rip), %rsi
	movq $1, %rdx
	syscall

	ret
get_size:
	movq $16, %rax
	movq $1, %rdi
	movq $0x5413, %rsi
	leaq winsize(%rip), %rdx
	syscall

	leaq height(%rip), %rax
	leaq width(%rip), %rdi
	movw (%rdx), %si
	movw %si, (%rax)
	movw 2(%rdx), %si
	movw %si, (%rdi)
	ret
clear_screen:
	movq $1, %rax
	movq $1, %rdi
	leaq s_clear(%rip), %rsi
	movq $4, %rdx
	syscall
	ret
save_cursor:
	movq $1, %rax
	movq $1, %rdi
	leaq c_save(%rip), %rsi
	movq $2, %rdx
	syscall
	ret
restore_cursor:
	movq $1, %rax
	movq $1, %rdi
	leaq c_restore(%rip), %rsi
	movq $2, %rdx
	syscall
	ret
enter_alt:
	call save_cursor

	movq $1, %rax
	movq $1, %rdi
	leaq alt_enter(%rip), %rsi
	movq $6, %rdx
	syscall

	call clear_screen
	ret
leave_alt:
	call clear_screen

	movq $1, %rax
	movq $1, %rdi
	leaq alt_leave(%rip), %rsi
	movq $6, %rdx
	syscall

	call restore_cursor

	ret
hide_cursor:
	movq $1, %rax
	movq $1, %rdi
	leaq c_hide(%rip), %rsi
	movq $6, %rdx
	syscall
	ret
show_cursor:
	movq $1, %rax
	movq $1, %rdi
	leaq c_show(%rip), %rsi
	movq $6, %rdx
	syscall
	ret
get_termios:
	movq $16, %rax
	movq $0, %rdi
	movq $0x5401, %rsi
	leaq termios(%rip), %rdx
	syscall
	ret
set_termios:
	movq $16, %rax
	movq $0, %rdi
	movq $0x5402, %rsi
	leaq termios(%rip), %rdx
	syscall
	ret
set_raw:
	call get_termios
	leaq termios(%rip), %r8
	andl $0xFFFFFFF5, 12(%r8)
	call set_termios
	ret
unset_raw:
	call get_termios
	leaq termios(%rip), %r8
	orl $0x00000000A, 12(%r8)
	call set_termios
	ret
