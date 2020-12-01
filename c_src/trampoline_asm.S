/* Adapted from NaCl trampolines & springboards */

#include "trampoline_asm_inc.S"
#define NOSWITCHSTACK_ASM
#include "trampoline_asm_inc.S"
#undef  NOSWITCHSTACK_ASM
#define WINDOWSMODE
#include "trampoline_asm_inc.S"
#undef  WINDOWSMODE

/*
 * param1: sandbox frame address
 * param2: return value
 *
 */
.globl set_return_target
.type set_return_target,@function
.align 16
set_return_target:
_set_return_target:
        mov %rsi, 0x8(%rdi)
        ret


/*
 * param1: sandbox stack (rsp2 = rdi)
 * param2: param_spill_size + return slot size (r_psize = rsi)

rb_old (rcx) = rbp
r_t (rdx) = rbp - rsp + r_psize
r_rsp2mint (rdi) = rsp2 - r_t
memcpy(r_rsp2mint, rsp, r_t)
rsp = r_rsp2mint (unspill to rdx)
rbp = rsp2 (rdi) - r_psize (rsi)
return rb_old (rcx)
 */
 .globl save_sbx_stack_and_switch_to_app_stack
.type save_sbx_stack_and_switch_to_app_stack,@function
.align 16
save_sbx_stack_and_switch_to_app_stack:
_save_sbx_stack_and_switch_to_app_stack:
        // Save rsp
        mov %rsp, %rcx

        /* Compute r_t */
        mov %rbp, %rdx
        sub %rsp, %rdx
        add %rsi, %rdx

        // Save params
        push %rdi
        push %rsi
        //Save old stack
        push %rcx

        /* Compute r_rsp2mint and save */
        sub %rdx, %rdi
        push %rdi

        /* Setup memcpy call */
        /* Noop: mov %r_rsp2mint, %rdi */
        mov %rcx, %rsi
        /* Noop: mov %r_t, %rdx */
        call memcpy@PLT
        /* Save the current sandbox stack return frame  */
        call    get_sandbox_current_thread_sbx_ctx@PLT
        movq    0x0(%rax), %r11
        movq    %rbp, 0xc8(%r11)
        addq    $0x10, 0xc8(%r11)

        /* rsp2mint is now in %rdx */
        pop %rdx
        /* Get val of old stack in rax return */
        pop %rax
        /* Restore func params */
        pop %rsi
        pop %rdi

        mov %rdx, %rsp

        mov %rdi, %rbp
        sub %rsi, %rbp
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
