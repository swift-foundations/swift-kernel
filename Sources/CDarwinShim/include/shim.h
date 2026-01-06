#ifndef CDARWIN_SHIM_H
#define CDARWIN_SHIM_H

#if defined(__APPLE__)

#include <sys/mman.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>

// shm_open is declared as variadic in Darwin's sys/mman.h:
//   int shm_open(const char *, int, ...);
// This makes it unavailable to Swift.
// We provide a non-variadic wrapper.

static inline int swift_shm_open(const char *name, int oflag, mode_t mode) {
    return shm_open(name, oflag, mode);
}

// POSIX wait status macros - Swift cannot import C macros directly.
// These wrapper functions expose the macros to Swift.

static inline int swift_WIFEXITED(int status) {
    return WIFEXITED(status);
}

static inline int swift_WEXITSTATUS(int status) {
    return WEXITSTATUS(status);
}

static inline int swift_WIFSIGNALED(int status) {
    return WIFSIGNALED(status);
}

static inline int swift_WTERMSIG(int status) {
    return WTERMSIG(status);
}

static inline int swift_WIFSTOPPED(int status) {
    return WIFSTOPPED(status);
}

static inline int swift_WSTOPSIG(int status) {
    return WSTOPSIG(status);
}

static inline int swift_WIFCONTINUED(int status) {
    return WIFCONTINUED(status);
}

static inline int swift_WCOREDUMP(int status) {
    return WCOREDUMP(status);
}

// Process management wrappers - fork() is marked unavailable in Swift's Darwin overlay
// but is still needed for primitives. We provide a wrapper to bypass the Swift annotation.

static inline pid_t swift_fork(void) {
    return fork();
}

static inline int swift_execve(
    const char *path,
    const char *const argv[],
    const char *const envp[]
) {
    // Cast away const-ness for execve's legacy signature.
    // execve does NOT modify the strings, this is safe.
    return execve(path, (char *const *)argv, (char *const *)envp);
}

#endif /* __APPLE__ */

#endif /* CDARWIN_SHIM_H */
