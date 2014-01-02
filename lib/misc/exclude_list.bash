#@section functions

# @private void exclude_list_add_items_to_v0 ( newline_list<items>, **v0! )
#
exclude_list_add_items_to_v0() {
   local OLDIFS="${IFS}"
   local IFS="${IFS_NEWLINE?}"
   set -- ${1}
   IFS="${OLDIFS}"
   v0+=( "$@" )
}

# void zap_exclude_list ( **EXCLUDE_LIST! )
#
#  Clears the exclude list.
#
zap_exclude_list() { EXCLUDE_LIST=(); }
