#ifndef CLINUX_SHIM_H
#define CLINUX_SHIM_H

#if defined(__linux__)

#define _GNU_SOURCE
#include <sys/epoll.h>
#include <sys/vfs.h>
#include <sys/statfs.h>
#include <sys/eventfd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <linux/fs.h>
#include <time.h>
#include <unistd.h>

// O_DIRECT may not be defined on all systems
#ifndef O_DIRECT
#define O_DIRECT 040000
#endif

#endif

#endif /* CLINUX_SHIM_H */
