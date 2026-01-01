#ifndef CLINUX_SHIM_H
#define CLINUX_SHIM_H

#if defined(__linux__)

#define _GNU_SOURCE

// Only include headers that provide symbols missing from SwiftGlibc
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/statfs.h>
#include <sys/ioctl.h>
#include <linux/fs.h>

// O_DIRECT is not in SwiftGlibc's fcntl overlay
#ifndef O_DIRECT
#define O_DIRECT 040000
#endif

// FICLONE ioctl for reflink cloning
#ifndef FICLONE
#define FICLONE _IOW(0x94, 9, int)
#endif

// copy_file_range syscall wrapper (Linux 4.5+)
// Declared here since Glibc headers may not expose it
#include <unistd.h>
#include <sys/syscall.h>

static inline ssize_t swift_copy_file_range(
    int fd_in, off_t *off_in,
    int fd_out, off_t *off_out,
    size_t len, unsigned int flags
) {
    return syscall(__NR_copy_file_range, fd_in, off_in, fd_out, off_out, len, flags);
}

// FICLONE wrapper
static inline int swift_ficlone(int dest_fd, int src_fd) {
    return ioctl(dest_fd, FICLONE, src_fd);
}

// statfs wrapper (not exported by SwiftGlibc)
static inline int swift_statfs(const char *path, struct statfs *buf) {
    return statfs(path, buf);
}

#endif /* __linux__ */

#endif /* CLINUX_SHIM_H */
