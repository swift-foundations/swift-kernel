#ifndef CLINUX_SHIM_H
#define CLINUX_SHIM_H

#if defined(__linux__)

// NOTE: Do NOT define _GNU_SOURCE here - let Glibc handle it
// NOTE: Do NOT include <unistd.h> or <sys/ioctl.h> - already in SwiftGlibc
//       Including them here causes fd_set type conflicts.

// ONLY headers NOT in SwiftGlibc:
#include <sys/epoll.h>       // epoll - NOT in SwiftGlibc
#include <sys/eventfd.h>     // eventfd - NOT in SwiftGlibc
#include <sys/statfs.h>      // statfs - NOT in SwiftGlibc
#include <linux/fs.h>        // FICLONE macro
#include <linux/io_uring.h>  // io_uring structs
#include <sys/syscall.h>     // __NR_* syscall numbers (safe - just defines)

// O_DIRECT - not in SwiftGlibc's fcntl overlay
#ifndef O_DIRECT
#define O_DIRECT 040000
#endif

// FICLONE - ioctl code for reflink cloning
// Value: _IOW(0x94, 9, int) = 0x40049409
#ifndef FICLONE
#define FICLONE 0x40049409
#endif

#endif /* __linux__ */

#endif /* CLINUX_SHIM_H */
