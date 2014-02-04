#@section functions

die "main pulled in"

liram_manage_run_applet() {
   die X
   local LIRAM_MANAGE_APPLET="${1:?}"
   shift
   liram_manage_main__${LIRAM_MANAGE_APPLET} "$@"
}

liram_manage_main_init() {
   die X
   liram_manage_init_vars || return


   liram_manage_atexit_register || die
   atexit_enable TERM EXIT

}
