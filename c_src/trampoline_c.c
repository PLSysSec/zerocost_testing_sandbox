#include "lucet_zero_trampoline.h"

__thread sandbox_thread_ctx* sandbox_current_thread_app_ctx = 0;
__thread sandbox_thread_ctx* sandbox_current_thread_sbx_ctx = 0;