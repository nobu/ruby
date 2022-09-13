#define _POSIX_C_SOURCE 200809L
#include "ruby/internal/config.h"
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "ruby-runner.h"

#ifdef MAKE_MJIT_BUILD_DIR
const char MJIT_HEADER[] = BUILDDIR "/" MJIT_MIN_HEADER;
#else

#define STRINGIZE(expr) STRINGIZE0(expr)
#define STRINGIZE0(expr) #expr

NORETURN(static void die(const char *));
static void
die(const char *message)
{
    fputs(message, stderr);
    exit(-1);
}

static void
insert_env_path(const char *envname, const char *paths, size_t size, int prepend)
{
    const char *env = getenv(envname);
    char c = 0;
    size_t n = 0;

    if (env) {
        while ((c = *env) == PATH_SEP) ++env;
        n = strlen(env);
        while (n > 0 && env[n-1] == PATH_SEP) --n;
    }
    if (c) {
        char *e = malloc(size+n+1);
        size_t pos = 0;
        if (prepend) {
            memcpy(e, paths, pos = size-1);
            e[pos++] = PATH_SEP;
        }
        memcpy(e+pos, env, n);
        pos += n;
        if (!prepend) {
            e[pos++] = PATH_SEP;
            memcpy(e+pos, paths, size-1);
            pos += size-1;
        }
        e[pos] = '\0';
        env = e;
    }
    else {
        env = paths;
    }
    setenv(envname, env, 1);
}

#define EXTOUT_DIR BUILDDIR"/"EXTOUT
int
main(int argc, char **argv)
{
    static const char builddir[] = BUILDDIR;
    static const char rubypath[] = BUILDDIR"/"STRINGIZE(RUBY_INSTALL_NAME);
    static const char rubylib[] =
        ABS_SRCDIR"/lib"
        PATH_SEPARATOR
        EXTOUT_DIR"/common"
        PATH_SEPARATOR
        EXTOUT_DIR"/"ARCH
        ;
#ifndef LOAD_RELATIVE
    static const char mjit_build_dir[] = BUILDDIR"/mjit_build_dir."SOEXT;
#endif
    static const char fake_opt[] = "-r"BUILDDIR"/"ARCH"-fake.rb";
    static const char *const fake_path = fake_opt + sizeof("-r") - 1;
    struct stat stbuf;
    const size_t dirsize = sizeof(builddir);
    const size_t namesize = sizeof(rubypath) - dirsize;
    const char *rubyname = rubypath + dirsize;
    char *arg0 = argv[0], *p;

    insert_env_path(LIBPATHENV, builddir, dirsize, 1);
    insert_env_path("RUBYLIB", rubylib, sizeof(rubylib), 0);
#ifndef LOAD_RELATIVE
    if (PRELOADENV[0] && stat(mjit_build_dir, &stbuf) == 0) {
        insert_env_path(PRELOADENV, mjit_build_dir, sizeof(mjit_build_dir), 1);
        setenv("MJIT_SEARCH_BUILD_DIR", "true", 0);
    }
#endif

    if (stat(fake_path, &stbuf)) {
        die("fake file not found.\n");
    }
    else if (argc > (int)(INT_MAX / sizeof(char *) - 2)) {
        die("cannot insert fake.rb path due to too many arguments.\n");
    }
    else {
        char **new_argv = malloc((argc + 2) * sizeof(char *));
        if (!new_argv) {
            die("cannot allocate memory for new argv.\n");
        }
        new_argv[0] = argv[0];
        new_argv[1] = (char *)fake_opt;
        memcpy(&new_argv[2], &argv[1], argc * sizeof(char *));
        argv = new_argv;
    }

    if (!(p = strrchr(arg0, '/'))) p = arg0; else p++;
    if (strlen(p) < namesize - 1) {
        argv[0] = malloc(p - arg0 + namesize);
        memcpy(argv[0], arg0, p - arg0);
        p = argv[0] + (p - arg0);
    }
    memcpy(p, rubyname, namesize);

    execv(rubypath, argv);
    perror(rubypath);
    return -1;
}

#endif  /* MAKE_MJIT_BUILD_DIR */
