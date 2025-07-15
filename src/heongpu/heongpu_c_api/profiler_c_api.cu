#include "profiler_c_api.h"
#include "profiler.h"
// extern "C" prevents C++ name mangling, so Python can find the functions.
extern "C" {
    void StartProfiling(const char* report_name) {
        start_profiling(report_name);
    }

    void EndProfiling() {
        end_profiling();
    }
}