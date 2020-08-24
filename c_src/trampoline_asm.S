/* Adapted from NaCl trampolines & springboards */

.text
.globl context_switch_to_sbx_func
.type context_switch_to_sbx_func,@function
.align 16
context_switch_to_sbx_func:
_context_switch_to_sbx_func:
        movq    sandbox_current_thread_app_ctx@GOTTPOFF(%rip), %r11
        movq    %fs:(%r11), %r11

        // Save the return address of the app and set the return of the trampoline
        movq    0x0(%rsp), %rax
        movq    %rax, 0xb8(%r11)
        leaq    post_call(%rip), %rax
        movq    %rax, 0x0(%rsp)

        /* Callee save registers */
        movq    %rbx, 0x00(%r11)
        movq    %rbp, 0x08(%r11)
        movq    %r12, 0x10(%r11)
        movq    %r13, 0x18(%r11)
        movq    %r14, 0x20(%r11)
        movq    %r15, 0x28(%r11)

        /* fp control word is callee save */
        fnstcw  0x68(%r11)
        /* mxcsr is caller save, but we need to clear it to prevent leaking app
         * state to sbx. But we don't have an easy way to return it to default
         * so just treat it as calee save
         */
        stmxcsr 0x70(%r11)

        // Clear scratch gpr registers to prevents leaks */
        xor    %rax, %rax
        xor    %rbx, %rbx
        xor    %r12, %r12
        xor    %r13, %r13
        xor    %r14, %r14
        xor    %r15, %r15

        // Clear the x87, MMX, and SSE state.
        fxrstor fxrstor_default_state(%rip)
        /* Clear the AVX state that the "fxrstor" instruction doesn't cover. */
        vzeroupper

        movq    sandbox_current_thread_sbx_ctx@GOTTPOFF(%rip), %r11
        movq    %fs:(%r11), %r11

        // Restore the untrusted code's x87 and SSE control words.
        fldcw   0x68(%r11)
        ldmxcsr 0x70(%r11)

        /* Load integer parameter registers */
        movq    0x30(%r11), %rdi
        movq    0x38(%r11), %rsi
        movq    0x40(%r11), %rdx
        movq    0x48(%r11), %rcx
        movq    0x50(%r11), %r8
        movq    0x58(%r11), %r9
        movq    0x60(%r11), %r10

        /* Load fp register parameters */
        movsd   0x78(%r11), %xmm0
        movsd   0x80(%r11), %xmm1
        movsd   0x88(%r11), %xmm2
        movsd   0x90(%r11), %xmm3
        movsd   0x98(%r11), %xmm4
        movsd   0xa0(%r11), %xmm5
        movsd   0xa8(%r11), %xmm6
        movsd   0xb0(%r11), %xmm7

        // Move the target into r11
        movq    0xb8(%r11), %r11
        jmp     *%r11

post_call:
        // retrieve the contexts as we can't trust the current state of registers
        movq    sandbox_current_thread_app_ctx@GOTTPOFF(%rip), %r11
        movq    %fs:(%r11), %r11

        /* Callee save registers */
        movq    0x00(%r11), %rbx
        movq    0x08(%r11), %rbp
        movq    0x10(%r11), %r12
        movq    0x18(%r11), %r13
        movq    0x20(%r11), %r14
        movq    0x28(%r11), %r15
        fldcw   0x68(%r11)
        ldmxcsr 0x70(%r11)

        // restore the return address
        movq    0xb8(%r11), %r11
        jmp     *%r11

.globl context_switch_to_sbx_callback
.type context_switch_to_sbx_callback,@function
.align 16
context_switch_to_sbx_callback:
_context_switch_to_sbx_callback:
        movq    sandbox_current_thread_app_ctx@GOTTPOFF(%rip), %r11
        movq    %fs:(%r11), %r11

        // Clear param & scratch gpr registers to prevents leaks */
        /* Load integer parameter registers */
        xor    %rdi, %rdi
        xor    %rsi, %rsi
        // xor    %rdx, %rdx
        xor    %rcx, %rcx
        xor    %r8 , %r8
        xor    %r9 , %r9
        xor    %r10, %r10
        xor    %rbx, %rbx
        xor    %r12, %r12
        xor    %r13, %r13
        xor    %r14, %r14
        xor    %r15, %r15

        // Clear the x87, MMX, and SSE state.
        fxrstor fxrstor_default_state(%rip)
        /* Clear the AVX state that the "fxrstor" instruction doesn't cover. */
        vzeroupper

        movq    sandbox_current_thread_sbx_ctx@GOTTPOFF(%rip), %r11
        movq    %fs:(%r11), %r11

        // Restore the untrusted code's x87 and SSE control words.
        fldcw   0x68(%r11)
        ldmxcsr 0x70(%r11)

        /* Load return registers */
        movq    0xc0(%r11), %rax
        movq    0x40(%r11), %rdx
        movsd   0x78(%r11), %xmm0

        // Move the target into r11
        movq    0xb8(%r11), %r11
        // we don't have to clear r11 as this only contains a pointer to the sandbox function, this is not a data leak
        jmp    *%r11
        // no return
        ud2

.globl get_return_target
.type get_return_target,@function
.align 16
get_return_target:
        // Assumes frame-pointer exists
        mov 0x8(%rbp), %rax
        ret

.globl set_return_target
.type set_return_target,@function
.align 16
set_return_target:
        // Assumes frame-pointer exists
        mov %rdi, 0x8(%rbp)
        ret

.section .rodata, "a"
        /*
         * This is the memory block for "fxrstor" to read.  The only
         * contents that matter are the fcw and mxcsr words, which we
         * store separately.  The mxcsr_mask word is ignored by the
         * hardware, so there is no need to get the hardware-supplied
         * value for that.  The hardware requires that this address be
         * aligned to 16 bytes.  Align it further to 64 bytes because
         * that is the usual size of a cache line; this might help
         * performance and is very unlikely to hurt it.
         */
        .balign 64
fxrstor_default_state:
        .space 512
