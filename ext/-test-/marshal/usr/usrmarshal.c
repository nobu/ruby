#include <ruby.h>

static size_t
usr_size(const void *ptr)
{
    return sizeof(int);
}

static const rb_data_type_t usrmarshal_type = {
    "UsrMarshal",
    {0, RUBY_DEFAULT_FREE, usr_size,},
    0, 0,
    RUBY_TYPED_FREE_IMMEDIATELY|RUBY_TYPED_WB_PROTECTED,
};

static VALUE
usr_alloc(VALUE klass)
{
    int *p;
    return TypedData_Make_Struct(klass, int, &usrmarshal_type, p);
}

static VALUE
usr_init(VALUE self, VALUE val)
{
    int *ptr = Check_TypedStruct(self, &usrmarshal_type);
    *ptr = NUM2INT(val);
    return self;
}

static VALUE
usr_value(VALUE self)
{
    int *ptr = Check_TypedStruct(self, &usrmarshal_type);
    int val = *ptr;
    return INT2NUM(val);
}

static VALUE
usr_dump(int argc, VALUE *argv, VALUE self)
{
    VALUE str = rb_obj_as_string(usr_value(self));
    rb_copy_generic_ivar(str, self);
    return str;
}

static VALUE
usr_load(VALUE klass, VALUE val)
{
    return usr_init(usr_alloc(klass), rb_str_to_inum(val, 0, 1));
}

void
Init_usr(void)
{
    VALUE mMarshal = rb_define_module_under(rb_define_module("Bug"), "Marshal");
    VALUE base = rb_define_class_under(mMarshal, "Base", rb_cObject);
    VALUE usrmarshal = rb_define_class_under(mMarshal, "UsrMarshal", base);
    VALUE userdef = rb_define_class_under(mMarshal, "UserDef", base);

    rb_define_alloc_func(base, usr_alloc);
    rb_define_method(base, "initialize", usr_init, 1);
    rb_define_method(base, "value", usr_value, 0);
    rb_define_method(userdef, "_dump", usr_dump, -1);
    rb_define_singleton_method(userdef, "_load", usr_load, 1);
    rb_define_method(usrmarshal, "marshal_load", usr_init, 1);
    rb_define_method(usrmarshal, "marshal_dump", usr_value, 0);
}
