#ifndef CLINUX_SHIM_H
#define CLINUX_SHIM_H

#if defined(__linux__)

#define _GNU_SOURCE

// ONLY include headers NOT in SwiftGlibc
#include <sys/epoll.h>       // epoll - NOT in SwiftGlibc
#include <sys/eventfd.h>     // eventfd - NOT in SwiftGlibc
#include <sys/statfs.h>      // statfs - NOT in SwiftGlibc
#include <sys/ioctl.h>       // ioctl - for FICLONE
#include <linux/fs.h>        // FICLONE macro
#include <linux/io_uring.h>  // io_uring structs
#include <sys/syscall.h>     // __NR_* syscall numbers
#include <unistd.h>          // syscall() function

// REMOVED: <signal.h> - causes fd_set conflict with SwiftGlibc
// REMOVED: <sys/mman.h> - already in SwiftGlibc

// O_DIRECT - not in SwiftGlibc's fcntl overlay
#ifndef O_DIRECT
#define O_DIRECT 040000
#endif

// FICLONE ioctl for reflink cloning
#ifndef FICLONE
#define FICLONE _IOW(0x94, 9, int)
#endif

// copy_file_range syscall wrapper (Linux 4.5+)
// Uses void* for offset pointers to avoid off_t type conflicts
static inline long swift_copy_file_range(
    int fd_in, void *off_in,
    int fd_out, void *off_out,
    size_t len, unsigned int flags
) {
    return syscall(__NR_copy_file_range, fd_in, off_in, fd_out, off_out, len, flags);
}

// FICLONE wrapper
static inline int swift_ficlone(int dest_fd, int src_fd) {
    return ioctl(dest_fd, FICLONE, src_fd);
}

// io_uring syscall wrappers (kernel 5.1+)
static inline int swift_io_uring_setup(unsigned entries, struct io_uring_params *p) {
    return syscall(__NR_io_uring_setup, entries, p);
}

// Uses void* for sigset to avoid sigset_t type conflicts
static inline int swift_io_uring_enter(
    int fd, unsigned to_submit, unsigned min_complete,
    unsigned flags, void *sig, size_t sigsz
) {
    return syscall(__NR_io_uring_enter, fd, to_submit, min_complete, flags, sig, sigsz);
}

static inline int swift_io_uring_register(
    int fd, unsigned opcode, void *arg, unsigned nr_args
) {
    return syscall(__NR_io_uring_register, fd, opcode, arg, nr_args);
}

#endif /* __linux__ */

#endif /* CLINUX_SHIM_H */
