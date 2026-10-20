/* POSIX getline() for MinGW, which does not provide it.
   Force-included into the kmmd target only (see apply.sh); rism carries its
   own getline.c for the same reason, so this is kept out of every other
   target to avoid a duplicate definition. */
#ifndef AT_MINGW_GETLINE_H
#define AT_MINGW_GETLINE_H
#if defined(__MINGW32__)
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

static inline ssize_t at_mingw_getline(char **lineptr, size_t *n, FILE *stream)
{
    size_t pos = 0;
    int c;
    if (lineptr == NULL || n == NULL || stream == NULL) return -1;
    if (*lineptr == NULL || *n == 0) {
        *n = 128;
        *lineptr = (char *)malloc(*n);
        if (*lineptr == NULL) return -1;
    }
    while ((c = fgetc(stream)) != EOF) {
        if (pos + 1 >= *n) {
            size_t bigger = *n * 2;
            char *p = (char *)realloc(*lineptr, bigger);
            if (p == NULL) return -1;
            *lineptr = p;
            *n = bigger;
        }
        (*lineptr)[pos++] = (char)c;
        if (c == '\n') break;
    }
    if (pos == 0) return -1;
    (*lineptr)[pos] = '\0';
    return (ssize_t)pos;
}
#define getline at_mingw_getline
#endif
#endif
