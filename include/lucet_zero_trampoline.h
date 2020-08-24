#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t rbx;
    uint64_t rbp;
    uint64_t r12;
    uint64_t r13;
    uint64_t r14;
    uint64_t r15;

    uint64_t rdi;
    uint64_t rsi;
    uint64_t rdx;
    uint64_t rcx;
    uint64_t r8;
    uint64_t r9;
    uint64_t r10;

    uint64_t float_cw;
    uint64_t mxcsr;

    uint64_t xmm0;
    uint64_t xmm1;
    uint64_t xmm2;
    uint64_t xmm3;
    uint64_t xmm4;
    uint64_t xmm5;
    uint64_t xmm6;
    uint64_t xmm7;

    uint64_t rip;
    uint64_t rax;
} sandbox_thread_ctx;

// extern __thread sandbox_thread_ctx* sandbox_current_thread_app_ctx;
// extern __thread sandbox_thread_ctx* sandbox_current_thread_sbx_ctx;

void context_switch_to_sbx_func();
void context_switch_to_sbx_callback();
uint64_t get_return_target();
void set_return_target(uint64_t val);

#ifdef __cplusplus
}
#endif