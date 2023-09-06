#include <ruby.h>
#include <ruby/thread.h>
#include <signal.h>

#ifdef SIGTERM
typedef struct { int dummy; } BugTestcase;

static void *
test_nogvl(void *unused)
{
    printf("GVL released!\n");
    fflush(stdout);
    return NULL;
}

static void
bug_testcase_free(void* ptr)
{
    printf("Sending signal\n");
    fflush(stdout);
    kill(getpid(), SIGTERM);
    printf("Trying to release GVL\n");
    fflush(stdout);
    rb_thread_call_without_gvl(test_nogvl, NULL, NULL, NULL);
    printf("After releasing GVL\n");
    fflush(stdout);
    free(ptr);
}

static const rb_data_type_t bug_testcase_data_type = {
    .wrap_struct_name = "SignalBugTestcase",
    .function = { NULL, bug_testcase_free, NULL },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

static VALUE
bug_testcase_alloc(VALUE klass)
{
    BugTestcase *obj;
    return TypedData_Make_Struct(klass, BugTestcase, &bug_testcase_data_type, obj);
}
#endif

void
Init_signal_at_cleanup(VALUE m)
{
#ifdef SIGTERM
    VALUE cAtCleanup = rb_define_class_under(m, "AtCleanup", rb_cObject);

    rb_define_alloc_func(cAtCleanup, bug_testcase_alloc);
#endif
}
