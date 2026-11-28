/* Rune calls a libc entry point added in glibc 2.27. Neojac targets glibc
 * 2.17; invoke the Linux syscall directly while preserving its errno result.
 * This library is linked once by the native adapter, not copied per widget.
 */
#define _GNU_SOURCE
#include <sys/syscall.h>
#include <unistd.h>

int memfd_create(const char *name, unsigned int flags) {
    return (int)syscall(SYS_memfd_create, name, flags);
}
