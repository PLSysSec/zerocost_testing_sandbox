
#include "ctx_save_trampoline_new.hpp"

thread_local TransitionContext* saved_transition_context = nullptr;

TransitionContext* get_saved_transition_context() {
  return saved_transition_context;
}
