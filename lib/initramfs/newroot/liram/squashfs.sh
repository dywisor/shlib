: ${SFS_SCAN_NAMES="usr"}
: ${SFS_SCAN_EXTENSIONS="sfs squashfs"}

# void liram_scan_squashfs (
#    sync_dir,
#    *sfs_name=**SFS_SCAN_NAMES=,
#    **SFS_SCAN_DIR="",
#    **SFS_SCAN_EXTENSIONS,
#    **SFS_SYNC_DIR!,
# )
#
liram_scan_squashfs() {
   SFS_SYNC_DIR="${1:?}"
   shift
   local \
      FILE_SCAN_EXTENSIONS="${SFS_SCAN_EXTENSIONS-}" \
      FILE_SCAN_SYNC_DIR="${SFS_SYNC_DIR}" \
      FILE_SCAN_DIR="${SFS_SCAN_DIR-}"

   if [ $# -gt 0 ]; then
      liram_filescan "$@"
   else
      liram_filescan ${SFS_SCAN_NAMES-}
   fi
}

# @function_alias liram_scan_sfs() renames liram_scan_squashfs()
liram_scan_sfs() { liram_scan_squashfs "$@"; }

# int liram_get_squashfs ( name, sync_dir=**TARBALL_SYNC_DIR )
#
#  Resolves the symlink of a (previously found) squashfs file and stores the
#  result in %v0.
#
#  Returns 0 if the tarball file exists, else != 0.
#
liram_get_squashfs() {
   liram_filescan_get "${1:?}" "${2-${SFS_SYNC_DIR-}}"
}

# @function_alias liram_get_sfs() renames liram_get_squashfs()
liram_get_sfs() { liram_get_squashfs "$@"; }
