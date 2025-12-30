#ifndef CLINUX_SHIM_H
#define CLINUX_SHIM_H

#if defined(__linux__)

// Only include headers that provide symbols missing from SwiftGlibc
// Avoid headers that redefine types (like unistd.h which pulls in sys/select.h)

#include <sys/epoll.h>
#include <sys/eventfd.h>

// O_DIRECT is not in SwiftGlibc's fcntl overlay
#ifndef O_DIRECT
#define O_DIRECT 040000
#endif

#endif

#endif /* CLINUX_SHIM_H */
