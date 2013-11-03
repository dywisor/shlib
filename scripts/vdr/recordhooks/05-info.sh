info() {
   local v0
   get_all_vdr_script_vars
   printvar ${v0:?}
}

any_phase() {
   if __debug__; then
      info
   fi
}
