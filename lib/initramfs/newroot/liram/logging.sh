#@section functions

# function liram_log ( level, ... )
#  IS dolog ( "-0", "--level=<level>", "--facility=liram", ... )
liram_log() {
   local v0 lvl="${1:-INFO}"
   shift && dolog -0 --level="${lvl}" --facility=liram "$@"
}

# function liram_debug (...)
#  IS dolog ( "-0", "--level=DEBUG", "--facility=liram", ... )
#
liram_debug() {
   local v0
   dolog -0 --level=DEBUG --facility=liram "$@"
}

# function liram_info (...)
#  IS dolog ( "-0", "--level=DEBUG", "--facility=liram", ... )
#
liram_info() {
   local v0
   dolog -0 --level=INFO --facility=liram "$@"
}

# void liram_log_tarball_unpacking ( name )
#
liram_log_tarball_unpacking() {
   liram_info "Unpacking the '${1}' tarball"
}

# void liram_log_tarball_unpacked ( name )
#
liram_log_tarball_unpacked() {
   liram_info "Successfully unpacked the '${1}' tarball"
}

# void liram_log_sfs_imported ( name )
#
liram_log_sfs_imported() {
   liram_info "Found and imported squashfs file for '${1}'"
}

# void liram_log_nothing_found ( name )
#
liram_log_nothing_found() {
   liram_debug "Nothing to do for '${1}'"
}
