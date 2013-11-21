#@section user_vars

# Names of the tarballs that will be searched if tarball_scan_names() is
# called without any name arg
: ${TARBALL_SCAN_NAMES:="rootfs var usr etc home scripts log"}

# Tarball file extensions - order *does* matter
: ${TARBALL_SCAN_EXTENSIONS:="tar tar.gz tgz tar.bz2 tbz2 tar.lzo tar.xz txz"}


#@section functions

# void liram_scan_tarball (
#    sync_dir,
#    *tarball_name=**TARBALL_SCAN_NAMES=,
#    **TARBALL_SCAN_DIR="",
#    **TARBALL_SCAN_EXTENSIONS,
#    **TARBALL_SYNC_DIR!,
# )
#
#  Scans for (named) tarballs in TARBALL_SCAN_DIR (or $PWD) and creates
#  symlinks to them (first hit per name) in sync_dir.
#
#
liram_scan_tarball() {
   TARBALL_SYNC_DIR="${1:?}"
   shift
   local \
      FILE_SCAN_EXTENSIONS="${TARBALL_SCAN_EXTENSIONS-}" \
      FILE_SCAN_SYNC_DIR="${TARBALL_SYNC_DIR}" \
      FILE_SCAN_DIR="${TARBALL_SCAN_DIR-}"

   if [ $# -gt 0 ]; then
      liram_filescan "$@"
   else
      liram_filescan ${TARBALL_SCAN_NAMES-}
   fi
}

# int liram_get_tarball ( name, sync_dir=**TARBALL_SYNC_DIR )
#
#  Resolves the symlink of a (previously found) tarball and stores the
#  result in %v0.
#
#  Returns 0 if the tarball file exists, else != 0.
#
liram_get_tarball() {
   liram_filescan_get "${1:?}" "${2-${TARBALL_SYNC_DIR-}}"
}
