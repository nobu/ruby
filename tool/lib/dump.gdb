set height 0
set width 0
set confirm off
set unwind-on-signal on

echo \n>>> Threads\n\n
info threads

echo \n>>> Machine level backtrace\n\n
thread apply all info stack full

echo \n>>> Dump Ruby level backtrace (if possible)\n\n
call (void)rb_vmdebug_stack_dump_all_threads()
call (int)fflush(stderr)

echo ">>> Finish\n"
detach
quit
