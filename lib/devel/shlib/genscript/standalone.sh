# genscript_standalone (
#    script_name, dest_name=<script_name>,
#    **script!, **script_name!, **dest!, **dest_name!
# )
#
genscript_standalone() {
   print_command "STANDALONE" "$*"
   printcmd_indent
   get_scriptvars "$@" || shift ${?} || OUT_OF_BOUNDS
   remove_destfile
   CC_script
   destfile_done
   printcmd_outdent
}


# @build_wrapper genscript_standalone STANDALONE
STANDALONE() { autodie scriptvars_leak genscript_standalone "$@"; }
