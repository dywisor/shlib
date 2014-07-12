#@HEADER
# int liram_populate_layout_stage3()
#
# ----------------------------------------------------------------------------
#
#  Populates %NEWROOT with a stage3/4 tarball:
#
# / (mandatory)
# * As tmpfs using the "stage3" tarball
#
# / (optional)
# * overwrites / with the contents of the "stage3-overlay" tarball
#
# /etc (optional)
# * Replaces the /etc directory from the rootfs tarball with the contents of
#   the 'etc' tarball if LIRAM_ETC_INCREMENTAL is not set to 'y', else
#   simply extracts the tarball into /etc/.
#
# /lib/modules (optional)
# * using the "kmod" tarball
#
# /sh (optional)
# * Extracts the 'scripts' tarball to /sh
#
# Calls liram_setup_subtrees() after unpacking the rootfs and
# newroot_setup_all() after populating newroot.
# Also exports boot-time variables such as LIRAM_DISK to NEWROOT as file.
#
# Runs the "liram-post-populate" hook just before returning.
#
#

#@section functions
# int liram_populate_layout_stage3()
#
liram_populate_layout_stage3() {
   local v0

   liram_info "stage3 layout"
   local TARBALL_SCAN_NAMES="stage3 stage3-overlay etc kmod scripts"
   local SFS_SCAN_NAMES=

   # scan files
   irun liram_scan_files

   # unpack stage3, stage3-overlay
   irun liram_unpack_name stage3 /
   liram_unpack_optional stage3-overlay "" /

   # early setup (liram subtrees)
   inonfatal liram_setup_subtrees

   # unpack remaining tarballs
   liram_unpack_etc || true
   liram_unpack_optional kmod    "" /lib/modules
   liram_unpack_optional scripts "" /sh

   # final setup (dirs and mounts)
   inonfatal newroot_setup_all

   # write liram env
   inonfatal liram_write_env

   # run post-populate hook
   newroot_setup_run_hook liram-post-populate

   # don't pass the last inonfatal return value
   return 0
}
