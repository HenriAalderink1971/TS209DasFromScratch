#ifndef MUSL_COMPAT_H
#define MUSL_COMPAT_H

#include <limits.h>
#include <sys/types.h>

/* BusyBox sometimes assumes glibc leaks these macros implicitly.
   musl only exposes them when the right headers are included. */

#ifndef NAME_MAX
# define NAME_MAX 255
#endif

#ifndef LONG_BIT
# define LONG_BIT (sizeof(long) * 8)
#endif

#ifndef SSIZE_MAX
# define SSIZE_MAX ((ssize_t)((size_t)-1 >> 1))
#endif

#endif

