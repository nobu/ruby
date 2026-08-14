#include "regenc.h"
/* dummy for unsupported, stateful encoding */
#define ENC_DUMMY_UNICODE(name) ENC_DUMMY(name)
ENC_DUMMY_UNICODE("UTF-16");
ENC_ALIAS("UTF16", "UTF-16");
ENC_DUMMY_UNICODE("UTF-32");
ENC_ALIAS("UTF32", "UTF-32");
