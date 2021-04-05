#include "ctx_save_trampoline_internal.hpp"

/*
 * param1(rdi): TransitionContext*
 */
.globl switch_execution_context
.type switch_execution_context,@function
.align 16
switch_execution_context:
_switch_execution_context:

        /* Stage 0: Pick regs */

        // Stores the current ctx structure
        //      - Callersave GPR not frame or stack
        //      - Cannot be a function parameter register
        //      - Cannot be a reg used by movsb
        //      - If changing, also adjust the use of "REG_PARAM specific" below
        #define REG_PARAM %r11
        // Temporary that holds computed end of stack frame after stack param copies
        //      - Callersave GPR not frame or stack
        //      - Cannot be REG_PARAM
        //      - Cannot be a reg used by movsb
        #define REG_TMP_STACK_FRAME %rax
        // Temporary for memory load operations
        //      - Callersave GPR not frame or stack
        //      - Cannot be REG_PARAM or REG_TMP_STACK_FRAME
        #define REG_TMP_LOAD %rdx

        mov     %rdi, REG_PARAM

        /* Stage 1: Save relevant context_from state */

        // Save callee save registers and stack
        movq    %rbx, TRANSITION_CONTEXT_OFFSET_RBX(REG_PARAM)
        movq    %r12, TRANSITION_CONTEXT_OFFSET_R12(REG_PARAM)
        movq    %r13, TRANSITION_CONTEXT_OFFSET_R13(REG_PARAM)
        movq    %r14, TRANSITION_CONTEXT_OFFSET_R14(REG_PARAM)
        movq    %r15, TRANSITION_CONTEXT_OFFSET_R15(REG_PARAM)
        cmpq    $0, TRANSITION_CONTEXT_OFFSET_WINDOWS_MODE_ABI(REG_PARAM)
        je      switch_execution_context_non_windows
        // Callee save registers on windows
        movsd   %xmm6 , TRANSITION_CONTEXT_OFFSET_XMM6(REG_PARAM)
        movsd   %xmm7 , TRANSITION_CONTEXT_OFFSET_XMM7(REG_PARAM)
        movsd   %xmm8 , TRANSITION_CONTEXT_OFFSET_XMM8(REG_PARAM)
        movsd   %xmm9 , TRANSITION_CONTEXT_OFFSET_XMM9(REG_PARAM)
        movsd   %xmm10, TRANSITION_CONTEXT_OFFSET_XMM10(REG_PARAM)
        movsd   %xmm11, TRANSITION_CONTEXT_OFFSET_XMM11(REG_PARAM)
        movsd   %xmm12, TRANSITION_CONTEXT_OFFSET_XMM12(REG_PARAM)
        movsd   %xmm13, TRANSITION_CONTEXT_OFFSET_XMM13(REG_PARAM)
        movsd   %xmm14, TRANSITION_CONTEXT_OFFSET_XMM14(REG_PARAM)
        movsd   %xmm15, TRANSITION_CONTEXT_OFFSET_XMM15(REG_PARAM)
switch_execution_context_non_windows:
        // Floating point control word and mxcsr are partially callee saved --- just save the whole thing
        fnstcw  TRANSITION_CONTEXT_OFFSET_SOURCE_FCW(REG_PARAM)
        stmxcsr TRANSITION_CONTEXT_OFFSET_SOURCE_MXCSR(REG_PARAM)
        // Save stack and frame ptr
        movq    %rsp, TRANSITION_CONTEXT_OFFSET_SOURCE_STACK_PTR(REG_PARAM)
        movq    %rbp, TRANSITION_CONTEXT_OFFSET_SOURCE_FRAME_PTR(REG_PARAM)

        /* Stage 2: Load relevant context_to state */

        // stack_ptr = target_stack
        // if (!stack_ptr) {
        //     // dont switch stacks
        //     stack_ptr = $rsp;
        // }
        movq    TRANSITION_CONTEXT_OFFSET_TARGET_STACK_PTR(REG_PARAM), REG_TMP_STACK_FRAME
        test    REG_TMP_STACK_FRAME, REG_TMP_STACK_FRAME
        cmovz   %rsp, REG_TMP_STACK_FRAME

        // Copy the stack parameters to the target stack frame
        // if parameters_size > 0 {
        //    stack_ptr -= parameters_size
        //    // align 16
        //    stack_ptr -= (stack_ptr % 16);
        //    memcpy(stack_ptr, parameters_buff, parameters_size)
        // }
        andq    $-16, REG_TMP_STACK_FRAME
        movq    TRANSITION_CONTEXT_OFFSET_STACK_PARAMS_SIZE(REG_PARAM), REG_TMP_LOAD
        testq   REG_TMP_LOAD, REG_TMP_LOAD
        je      switch_execution_context_only_reg_params

        // Copy the parameters
        movq    REG_TMP_LOAD, %rcx
        movq    TRANSITION_CONTEXT_OFFSET_STACK_PARAMS_BUFFER(REG_PARAM), %rsi
        subq    REG_TMP_LOAD, REG_TMP_STACK_FRAME
        andq    $-16, REG_TMP_STACK_FRAME
        movq    REG_TMP_STACK_FRAME, %rdi
        rep movsb

switch_execution_context_only_reg_params:

        // Load the stack pointer of the context_to
        movq    REG_TMP_STACK_FRAME, %rsp
        // Set the frame pointer also to make sure previous frame pointer val does not leak
        movq    REG_TMP_STACK_FRAME, %rbp

        // Clear non parameter gpr registers to prevents leaks
        // xor also leaves eflags in a fixed known state, so no leaks through this
        xor     %rax, %rax
        xor     %rbx, %rbx
        // REG_PARAM specific: Disable r11 clear as it is being used for REG_PARAM
        // xor     %r11, %r11
        xor     %r12, %r12
        xor     %r13, %r13
        xor     %r14, %r14
        xor     %r15, %r15
        // Clear direction flag before call or return
        cld
        // Clear the x87, MMX, and SSE state.
        fxrstor fxrstor_default_state(%rip)
        // Clear the AVX state that the "fxrstor" instruction doesn't cover.
        vzeroupper

        // Load float state, integer param and float parameter registers
        fldcw   TRANSITION_CONTEXT_OFFSET_TARGET_FCW(REG_PARAM)
        ldmxcsr TRANSITION_CONTEXT_OFFSET_TARGET_MXCSR(REG_PARAM)
        movq    TRANSITION_CONTEXT_OFFSET_RDI(REG_PARAM) , %rdi
        movq    TRANSITION_CONTEXT_OFFSET_RSI(REG_PARAM) , %rsi
        movq    TRANSITION_CONTEXT_OFFSET_RDX(REG_PARAM) , %rdx
        movq    TRANSITION_CONTEXT_OFFSET_RCX(REG_PARAM) , %rcx
        movq    TRANSITION_CONTEXT_OFFSET_R8(REG_PARAM)  , %r8
        movq    TRANSITION_CONTEXT_OFFSET_R9(REG_PARAM)  , %r9
        movq    TRANSITION_CONTEXT_OFFSET_R10(REG_PARAM) , %r10
        movsd   TRANSITION_CONTEXT_OFFSET_XMM0(REG_PARAM), %xmm0
        movsd   TRANSITION_CONTEXT_OFFSET_XMM1(REG_PARAM), %xmm1
        movsd   TRANSITION_CONTEXT_OFFSET_XMM2(REG_PARAM), %xmm2
        movsd   TRANSITION_CONTEXT_OFFSET_XMM3(REG_PARAM), %xmm3
        movsd   TRANSITION_CONTEXT_OFFSET_XMM4(REG_PARAM), %xmm4
        movsd   TRANSITION_CONTEXT_OFFSET_XMM5(REG_PARAM), %xmm5
        movsd   TRANSITION_CONTEXT_OFFSET_XMM6(REG_PARAM), %xmm6
        movsd   TRANSITION_CONTEXT_OFFSET_XMM7(REG_PARAM), %xmm7

        // Load the target function ptr
        movq    TRANSITION_CONTEXT_OFFSET_TARGET_PROG_CTR(REG_PARAM), REG_PARAM
        callq   *REG_PARAM

        #undef REG_PARAM
        #undef REG_TMP_STACK_FRAME
        #undef REG_TMP_LOAD

        // Fall-through

// switch_execution_context_out:

        /* Stage 0: Pick regs. Need temporary working regs which are caller
        saved by the invoker of switch_execution_context
        */

        // Temporary that holds part 1 of the GPR return
        //      - Calleesave GPR not frame or stack
        //      - Cannot be a return GPR
        #define REG_TMP_RET1 %rbx
        // Temporary that holds part 2 of the GPR return
        //      - Calleesave GPR not frame or stack
        //      - Cannot be REG_TMP_RET1
        //      - Cannot be a return GPR
        #define REG_TMP_RET2 %r12
        // Stores the current ctx structure
        //      - Callersave GPR not frame or stack
        //      - Cannot be REG_TMP_RET1 or REG_TMP_RET2
        #define REG_PARAM %r11

        // Save return values that could get overwritten by this function call
        movq    %rax, REG_TMP_RET1
        movq    %rdx, REG_TMP_RET2

        // TODO: retrieve the param again
        callq   get_saved_transition_context@PLT
        movq    %rax, REG_PARAM

        /* Stage 1: Save relevant context_to state */

        // Save returned values
        movq    REG_TMP_RET1, TRANSITION_CONTEXT_OFFSET_RAX(REG_PARAM)
        movq    REG_TMP_RET2, TRANSITION_CONTEXT_OFFSET_RDX(REG_PARAM)
        movsd   %xmm0, TRANSITION_CONTEXT_OFFSET_XMM0(REG_PARAM)

        /* Stage 2: Load relevant context_from state */

        // Clear regs that are caller save and not return registers
        // Needed when returning into the sandbox from app --- caller is sandbox, callee is app
        // xor also leaves eflags in a fixed known state, so no leaks through this
        xorq    %rcx, %rcx
        xorq    %rdi, %rdi
        xorq    %rsi, %rsi
        xorq    %r8 , %r8
        xorq    %r9 , %r9
        xorq    %r10, %r10
        // REG_PARAM specific: Delay r11 clear as it is being used for REG_PARAM
        // xorq    %r11, %r11
        // Clear direction flag before call or return
        cld
        // Clear the x87, MMX, and SSE state.
        fxrstor fxrstor_default_state(%rip)
        // Clear the AVX state that the "fxrstor" instruction doesn't cover.
        vzeroupper

        // Restore callee save registers
        movq    TRANSITION_CONTEXT_OFFSET_RBX(REG_PARAM), %rbx
        movq    TRANSITION_CONTEXT_OFFSET_R12(REG_PARAM), %r12
        movq    TRANSITION_CONTEXT_OFFSET_R13(REG_PARAM), %r13
        movq    TRANSITION_CONTEXT_OFFSET_R14(REG_PARAM), %r14
        movq    TRANSITION_CONTEXT_OFFSET_R15(REG_PARAM), %r15
        cmpq    $0, TRANSITION_CONTEXT_OFFSET_WINDOWS_MODE_ABI(REG_PARAM)
        je      switch_execution_context_out_non_windows
        // Callee save registers on windows
        movsd   TRANSITION_CONTEXT_OFFSET_XMM6(REG_PARAM) , %xmm6
        movsd   TRANSITION_CONTEXT_OFFSET_XMM7(REG_PARAM) , %xmm7
        movsd   TRANSITION_CONTEXT_OFFSET_XMM8(REG_PARAM) , %xmm8
        movsd   TRANSITION_CONTEXT_OFFSET_XMM9(REG_PARAM) , %xmm9
        movsd   TRANSITION_CONTEXT_OFFSET_XMM10(REG_PARAM), %xmm10
        movsd   TRANSITION_CONTEXT_OFFSET_XMM11(REG_PARAM), %xmm11
        movsd   TRANSITION_CONTEXT_OFFSET_XMM12(REG_PARAM), %xmm12
        movsd   TRANSITION_CONTEXT_OFFSET_XMM13(REG_PARAM), %xmm13
        movsd   TRANSITION_CONTEXT_OFFSET_XMM14(REG_PARAM), %xmm14
        movsd   TRANSITION_CONTEXT_OFFSET_XMM15(REG_PARAM), %xmm15
switch_execution_context_out_non_windows:
        // Restore fp control word which is callee save
        fldcw   TRANSITION_CONTEXT_OFFSET_SOURCE_FCW(REG_PARAM)
        ldmxcsr TRANSITION_CONTEXT_OFFSET_SOURCE_MXCSR(REG_PARAM)
        // Restore stack
        movq    TRANSITION_CONTEXT_OFFSET_SOURCE_STACK_PTR(REG_PARAM), %rsp
        movq    TRANSITION_CONTEXT_OFFSET_SOURCE_FRAME_PTR(REG_PARAM), %rbp

        // Restore return values in registers
        movq    TRANSITION_CONTEXT_OFFSET_RAX(REG_PARAM), %rax
        movq    TRANSITION_CONTEXT_OFFSET_RDX(REG_PARAM), %rdx
        movsd   TRANSITION_CONTEXT_OFFSET_XMM0(REG_PARAM), %xmm0

        // REG_PARAM specific: Delayed r11 now
        xorq    %r11, %r11

        ret

        #undef REG_TMP_RET1
        #undef REG_TMP_RET2
        #undef REG_PARAM

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
