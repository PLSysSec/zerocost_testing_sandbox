#define RLBOX_USE_EXCEPTIONS
#define RLBOX_ENABLE_DEBUG_ASSERTIONS
#define RLBOX_SINGLE_THREADED_INVOCATIONS
#define RLBOX_ZEROCOST_WINDOWSMODE
#include "rlbox_lucet_sandbox.hpp"
RLBOX_LUCET_SANDBOX_STATIC_VARIABLES();

// NOLINTNEXTLINE
#define TestName "rlbox_lucet_sandbox windows mode"
// NOLINTNEXTLINE
#define TestType rlbox::rlbox_lucet_sandbox

#ifndef GLUE_LIB_LUCET_PATH
#  error "Missing definition for GLUE_LIB_LUCET_PATH"
#endif

// NOLINTNEXTLINE
#define CreateSandbox(sandbox) sandbox.create_sandbox(GLUE_LIB_LUCET_PATH)
#include "test_sandbox_glue.inc.cpp"