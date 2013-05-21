# makelib_standalone ( dest_name, *module, **dest!, **dest_name! )
#
makelib_standalone() {
   print_command "MAKELIB" "$*"
   printcmd_indent
   get_libvars "$@" || shift ${?} || OUT_OF_BOUNDS
   remove_destfile

   if [ $# -eq 0 ]; then
      CC_lib "${dest_name}"
   else
      CC_lib "$@"
   fi

   destfile_done
   printcmd_outdent
}

# @build_wrapper makelib_standalone MAKELIB()
#
MAKELIB() { autodie libvars_leak makelib_standalone "$@"; }
