#ifndef PROFILER_C_API_H
#define PROFILER_C_API_H

#ifdef __cplusplus
extern "C" {
#endif

void StartProfiling(const char* report_name);

void EndProfiling(void);

#ifdef __cplusplus
}
#endif

#endif // PROFILER_C_API_H