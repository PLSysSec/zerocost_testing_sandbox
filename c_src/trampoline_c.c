#include "ctx_save_trampoline.h"
#include <stdint.h>

struct rlbox_lucet_sandbox_thread_data
{
  void* sandbox;
  uint32_t last_callback_invoked;
  sandbox_thread_ctx* sandbox_current_thread_app_ctx;
  sandbox_thread_ctx* sandbox_current_thread_sbx_ctx;
};

struct rlbox_lucet_sandbox_thread_data* get_rlbox_lucet_sandbox_thread_data();

sandbox_thread_ctx** get_sandbox_current_thread_app_ctx() {
    struct rlbox_lucet_sandbox_thread_data* thread_data = get_rlbox_lucet_sandbox_thread_data();
    return &(thread_data->sandbox_current_thread_app_ctx);
}

sandbox_thread_ctx** get_sandbox_current_thread_sbx_ctx() {
    struct rlbox_lucet_sandbox_thread_data* thread_data = get_rlbox_lucet_sandbox_thread_data();
    return &(thread_data->sandbox_current_thread_sbx_ctx);
}
