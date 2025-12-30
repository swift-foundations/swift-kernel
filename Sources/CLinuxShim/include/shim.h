#ifndef CLINUX_SHIM_H
#define CLINUX_SHIM_H

#if defined(__linux__)

#include <sys/epoll.h>
#include <sys/vfs.h>
#include <sys/statfs.h>
#include <sys/eventfd.h>
#include <fcntl.h>

#endif

#endif /* CLINUX_SHIM_H */
