#@section functions

# @private void exclude_list_add_items_to_v0 ( newline_list<items>, **v0! )
#
exclude_list_add_items_to_v0() {
   v0="${v0-}${v0:+${NEWLINE}}${item}"
}

# void zap_exclude_list ( **EXCLUDE_LIST! )
#
#  Clears the exclude list.
#
zap_exclude_list() { EXCLUDE_LIST=; }
