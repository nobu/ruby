#include "ruby.h"

#define init(n) {void Init_signal_##n(VALUE klass); Init_signal_##n(klass);}

void
Init_signal(void)
{
    VALUE mBug = rb_define_module("Bug");
    VALUE klass = rb_define_module_under(mBug, "Signal");
    TEST_INIT_FUNCS(init);
}
