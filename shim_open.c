/**
 * https://unix.stackexchange.com/questions/237636/is-it-possible-to-fake-a-specific-path-for-a-process
 * capture calls to a routine and replace with your code
 * gcc -Wall -O2 -fpic -shared -ldl -o shim_open.so shim_open.c
 * LD_PRELOAD=/.../shim_open.so cat /tmp/adb.log
 */
#define _FCNTL_H 1 /* hack for open() prototype */
#define _GNU_SOURCE /* needed to get RTLD_NEXT defined in dlfcn.h */
#define __USE_GNU 1
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>
#include <asm-generic/fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

int open(const char *pathname, int flags, mode_t mode) {
    static int (*real_open)(const char *pathname, int flags, mode_t mode) = NULL;

    if (!real_open) {
        real_open = dlsym(RTLD_NEXT, "open");
        char *error = dlerror();
        if (error != NULL) {
            fprintf(stderr, "shim_open(): %s\n", error);
            exit(1);
        }
    }
    // fprintf(stderr, "shim_open(): opening %s\n", pathname);
    return real_open(pathname, flags|O_DIRECT, mode);
}


