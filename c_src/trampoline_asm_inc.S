.text

#ifndef NOSWITCHSTACK_ASM

.globl context_switch_to_sbx_func
.type context_switch_to_sbx_func,@function
.align 16
context_switch_to_sbx_func:
_context_switch_to_sbx_func:

#else

.globl context_switch_to_sbx_func_noswitchstack
.type context_switch_to_sbx_func_noswitchstack,@function
.align 16
context_switch_to_sbx_func_noswitchstack:
_context_switch_to_sbx_func_noswitchstack:

#endif

        /* Stage 0: Copy all app stack parameters to sandbox stack
        expected to be completed before invocation */

        /* Stage 1: Save application register state */
        movq    0x10(%rdi), %r11

        #ifndef NOSWITCHSTACK_ASM
        /* save the rsp of the application */
        movq    %rsp, 0xc8(%r11)
        #endif

        /* Save the return address of the app */
        movq    0x0(%rsp), %rax
        movq    %rax, 0xb8(%r11)

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

        /* Stage 2: Load sandbox register state */
        movq    0x18(%rdi), %r11

        /* Clear scratch gpr registers to prevents leaks */
        xor    %rax, %rax
        xor    %rbx, %rbx
        xor    %r12, %r12
        xor    %r13, %r13
        xor    %r14, %r14
        xor    %r15, %r15

        /* Clear the x87, MMX, and SSE state. */
        fxrstor fxrstor_default_state(%rip)
        /* Clear the AVX state that the "fxrstor" instruction doesn't cover. */
        vzeroupper

        /* Restore the untrusted code's x87 and SSE control words. */
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

        /* load the rsp of the sandbox and set the return address to the trampoline done label */
        #ifndef NOSWITCHSTACK_ASM
        movq    0xc8(%r11), %rsp
        #endif

        #ifndef NOSWITCHSTACK_ASM
        leaq    context_switch_to_sbx_func_done(%rip), %rax
        #else
        leaq    context_switch_to_sbx_func_done_noswitchstack(%rip), %rax
        #endif

        movq    %rax, 0x0(%rsp)

        /* Stage 3: Perform the call */
        /* Move the target into r11*/
        movq    0xb8(%r11), %r11
        jmp     *%r11

#ifndef NOSWITCHSTACK_ASM
context_switch_to_sbx_func_done:
#else
context_switch_to_sbx_func_done_noswitchstack:
#endif

        /* Stage 4: Restore application register state */
        /* save the return value*/
        movq    %rax, %r15
        /* retrieve the contexts as we can't trust the current state of registers*/
        call    get_sandbox_current_thread_app_ctx@PLT
        movq    0x0(%rax), %r11
        /* restore old return*/
        movq    %r15, %rax

        /* Callee save registers */
        movq    0x00(%r11), %rbx
        movq    0x08(%r11), %rbp
        movq    0x10(%r11), %r12
        movq    0x18(%r11), %r13
        movq    0x20(%r11), %r14
        movq    0x28(%r11), %r15
        fldcw   0x68(%r11)
        ldmxcsr 0x70(%r11)

        /* load the rsp of the app -- offset by 8 as the return address has already been consumed */
        #ifndef NOSWITCHSTACK_ASM
        movq    0xc8(%r11), %rsp
        addq    $0x8, %rsp
        #endif

        /* restore the return address*/
        movq    0xb8(%r11), %r11
        jmp     *%r11
        ud2

#ifndef NOSWITCHSTACK_ASM

.globl context_switch_to_sbx_callback
.type context_switch_to_sbx_callback,@function
.align 16
context_switch_to_sbx_callback:
_context_switch_to_sbx_callback:

#else

.globl context_switch_to_sbx_callback_noswitchstack
.type context_switch_to_sbx_callback_noswitchstack,@function
.align 16
context_switch_to_sbx_callback_noswitchstack:
_context_switch_to_sbx_callback_noswitchstack:

#endif

        call    get_sandbox_current_thread_sbx_ctx@PLT
        movq    0x0(%rax), %r11

        /* Clear param & scratch gpr registers to prevents leaks */
        xor    %rdi, %rdi
        xor    %rsi, %rsi
        /* Dont need to clear rdx as it is replaced with return value */
        xor    %rcx, %rcx
        xor    %r8 , %r8
        xor    %r9 , %r9
        xor    %r10, %r10

        /* Clear the x87, MMX, and SSE state.*/
        fxrstor fxrstor_default_state(%rip)
        /* Clear the AVX state that the "fxrstor" instruction doesn't cover. */
        vzeroupper

        /* Restore the untrusted code's x87 and SSE control words.*/
        fldcw   0x68(%r11)
        ldmxcsr 0x70(%r11)

        /* Load return registers */
        movq    0xc0(%r11), %rax
        movq    0x40(%r11), %rdx
        movsd   0x78(%r11), %xmm0

        #ifndef NOSWITCHSTACK_ASM
        /* Restore the stack of the sandbox */
        movq    0xc8(%r11), %rsp
        #endif

        /* Move the target into r11*/
        movq    0xb8(%r11), %r11
        /* we don't have to clear r11 as this only contains a pointer to the sandbox function, this is not a data leak*/
        jmp    *%r11
        /* no return*/
        ud2