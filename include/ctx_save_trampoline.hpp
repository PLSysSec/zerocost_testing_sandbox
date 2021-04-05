#pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <type_traits>
#include <utility>

#include "ctx_save_trampoline_internal.hpp"

namespace switch_execution_detail {

template<typename T>
constexpr bool false_v = false;

}

extern "C"
{
  void switch_execution_context(TransitionContext* transition);
}

class heavy_trampoline
{

private:

  template<typename T_Arg>
  static inline uint64_t serialize_to_uint64(T_Arg arg)
  {
    uint64_t val = 0;
    // memcpy will be removed by any decent compiler
    if constexpr (sizeof(T_Arg) == 8) {
      memcpy(&val, &arg, sizeof(T_Arg));
    } else if constexpr (sizeof(T_Arg) == 4) {
      uint32_t tmp = 0;
      memcpy(&tmp, &arg, sizeof(T_Arg));
      val = tmp;
    } else {
      static_assert(switch_execution_detail::false_v<T_Arg>,
                    "Unknown serialization size");
    }
    return val;
  }

  template<size_t T_IntegerNum, size_t T_FloatNum, typename T_Ret>
  static inline size_t push_parameters(TransitionContext* ctx,
                                     char* target_buffer,
                                     size_t target_buffer_used_size,
                                     T_Ret (*)())
  {
    return target_buffer_used_size;
  }

  template<size_t T_IntegerNum,
           size_t T_FloatNum,
           typename T_Ret,
           typename T_FormalArg,
           typename... T_FormalArgs,
           typename T_ActualArg,
           typename... T_ActualArgs>
  static inline size_t push_parameters(TransitionContext* ctx,
                                     char* target_buffer,
                                     size_t target_buffer_used_size,
                                     T_Ret (*)(T_FormalArg, T_FormalArgs...),
                                     T_ActualArg&& arg,
                                     T_ActualArgs&&... args)
  {
    T_FormalArg arg_conv = arg;
    uint64_t val = serialize_to_uint64(arg_conv);

    if constexpr (std::is_integral_v<T_FormalArg> ||
                  std::is_pointer_v<T_FormalArg> ||
                  std::is_reference_v<T_FormalArg> ||
                  std::is_enum_v<T_FormalArg>) {

      if constexpr (T_IntegerNum == 0) {
        ctx->rdi = val;
      } else if constexpr (T_IntegerNum == 1) {
        ctx->rsi = val;
      } else if constexpr (T_IntegerNum == 2) {
        ctx->rdx = val;
      } else if constexpr (T_IntegerNum == 3) {
        ctx->rcx = val;
      } else if constexpr (T_IntegerNum == 4) {
        ctx->r8 = val;
      } else if constexpr (T_IntegerNum == 5) {
        ctx->r9 = val;
      } else {
        memcpy(target_buffer, &val, sizeof(val));
        target_buffer += sizeof(val);
        target_buffer_used_size += sizeof(val);
      }

      return push_parameters<T_IntegerNum + 1, T_FloatNum>(
        ctx,
        target_buffer,
        target_buffer_used_size,
        reinterpret_cast<T_Ret (*)(T_FormalArgs...)>(0),
        std::forward<T_ActualArgs>(args)...);

    } else if constexpr (std::is_same_v<T_FormalArg, float> ||
                         std::is_same_v<T_FormalArg, double>) {

      if constexpr (T_FloatNum == 0) {
        ctx->xmm0 = val;
      } else if constexpr (T_FloatNum == 1) {
        ctx->xmm1 = val;
      } else if constexpr (T_FloatNum == 2) {
        ctx->xmm2 = val;
      } else if constexpr (T_FloatNum == 3) {
        ctx->xmm3 = val;
      } else if constexpr (T_FloatNum == 4) {
        ctx->xmm4 = val;
      } else if constexpr (T_FloatNum == 5) {
        ctx->xmm5 = val;
      } else if constexpr (T_FloatNum == 6) {
        ctx->xmm6 = val;
      } else if constexpr (T_FloatNum == 7) {
        ctx->xmm7 = val;
      } else {
        memcpy(target_buffer, &val, sizeof(val));
        target_buffer += sizeof(val);
        target_buffer_used_size += sizeof(val);
      }

      return push_parameters<T_IntegerNum, T_FloatNum + 1>(
        ctx,
        target_buffer,
        target_buffer_used_size,
        reinterpret_cast<T_Ret (*)(T_FormalArgs...)>(0),
        std::forward<T_ActualArgs>(args)...);
    } else {
      static_assert(switch_execution_detail::false_v<T_Ret>, "Unknown case");
    }
  }

  bool m_switch_stacks;
  bool m_windows_mode;
  char* sandbox_stack_pointer = 0;
  char* curr_sandbox_stack_pointer = 0;
  char* parameter_buffer = 0;

public:
  void init(bool switch_stacks, bool windows_mode)
  {
    m_switch_stacks = switch_stacks;
    m_windows_mode = windows_mode;

    if (m_switch_stacks) {
      // allocate a 16M sandbox stack by default
      const uint64_t stack_size = 16 * 1024 * 1024;
      sandbox_stack_pointer = new char[stack_size];
      if (sandbox_stack_pointer == nullptr) {
        printf("Could not allocate sandbox stack\n");
        abort();
      }
      curr_sandbox_stack_pointer = sandbox_stack_pointer + stack_size;
      // keep stack 16 byte aligned
      curr_sandbox_stack_pointer -=
        (reinterpret_cast<uintptr_t>(curr_sandbox_stack_pointer) % 16);
    }
    // picking a parameter buffer of 4k arbitrarily. This should be sufficiently large for most things
    const uint64_t parameter_buffer_size = 16 * 1024 * 1024;
    parameter_buffer = new char[parameter_buffer_size];
    if (parameter_buffer == nullptr) {
      printf("Could not allocate parameter_buffer\n");
      abort();
    }
  }

  void destroy()
  {
    if (sandbox_stack_pointer != nullptr) {
      delete[] sandbox_stack_pointer;
    }
    if (parameter_buffer != nullptr) {
      delete[] parameter_buffer;
    }
  }

  template<typename T_Ret, typename... T_FormalArgs, typename... T_ActualArgs>
  inline T_Ret func_call(T_Ret (*fn_ptr)(T_FormalArgs...), T_ActualArgs&&... args)
  {
    char* stack_pointer = nullptr;
    TransitionContext transition_in = {};

    TransitionContext* prev_transition_context = saved_transition_context;
    saved_transition_context = &transition_in;

    if (m_switch_stacks) {
      if (prev_transition_context != nullptr) {
          stack_pointer = (char*) prev_transition_context->source_stack_ptr;
          // keep stack 16 byte aligned
          stack_pointer -= (reinterpret_cast<uintptr_t>(stack_pointer) % 16);
      } else {
          stack_pointer = curr_sandbox_stack_pointer;
      }
    }

    if (m_windows_mode) {
      transition_in.windows_mode_abi = 1;
    }

    auto stack_param_size = push_parameters<0, 0>(
      &transition_in, parameter_buffer, /* init_stack_param_size */ 0, fn_ptr, std::forward<T_ActualArgs>(args)...);

    transition_in.target_stack_ptr = (uintptr_t)stack_pointer;
    transition_in.stack_params_buffer = parameter_buffer;
    transition_in.stack_params_size = stack_param_size;
    transition_in.target_prog_ctr = (uintptr_t)fn_ptr;

    switch_execution_context(&transition_in);
    saved_transition_context = prev_transition_context;

    if constexpr (std::is_same_v<T_Ret, float> ||
                  std::is_same_v<T_Ret, double>) {
      T_Ret ret = 0;
      memcpy(&ret, &transition_in.xmm0, sizeof(ret));
      return ret;
    } else if constexpr (std::is_same_v<T_Ret, void>) {
      return;
    } else if constexpr (sizeof(T_Ret) > 16) {
      // This doesn't handle struct returns that are not 8 or 16 bytes, but
      // looks like we don't need that
      abort();
    } else if constexpr (sizeof(T_Ret) > 8 && sizeof(T_Ret) <= 16) {
      uint64_t result[] = { transition_in.rax, transition_in.rdx };
      T_Ret ret;
      memcpy(&ret, result, sizeof(result));
      return ret;
    } else {
      static_assert(sizeof(T_Ret) <= 8);
      return (T_Ret)transition_in.rax;
    }
  }
};