#ifndef CDARWIN_SHIM_H
#define CDARWIN_SHIM_H

#if defined(__APPLE__)

#include <sys/mman.h>
#include <sys/types.h>
#include <fcntl.h>

// shm_open is declared as variadic in Darwin's sys/mman.h:
//   int shm_open(const char *, int, ...);
// This makes it unavailable to Swift.
// We provide a non-variadic wrapper.

static inline int swift_shm_open(const char *name, int oflag, mode_t mode) {
    return shm_open(name, oflag, mode);
}

#endif /* __APPLE__ */

#endif /* CDARWIN_SHIM_H */
