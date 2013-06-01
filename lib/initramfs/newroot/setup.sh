## functions from initramfs/newroot/tmpdir

# @extern int newroot_tmpdir_users ( *user_spec )
# @extern void newroot_tmpdir_init()
# @extern int newroot_tmpdir_dodir ( dir, f_dodir_existed, ... )
# @extern int newroot_tmpdir_avail()


## BEGIN module

: ${NEWROOT_CONFIG_DIR=/initramfs-config}

# @private void newroot_setup__dodir ( dirpath, **NEWROOT, **fail! )
#
#  Creates dirpath in NEWROOT.
#  Always returns 0. Increases the fail counter if the dir does not exist
#  after calling this function.
#
newroot_setup__dodir() {
   KEEPDIR=y dodir_minimal "${NEWROOT}/${1#/}" || fail=$(( ${fail?} + 1 ))
}

# @private void newroot_setup__failcount ( **failcount! )
#
#  Increments the failcount variable.
#
newroot_setup__failcount() { failcount=$(( ${failcount:?} + 1 )); }

# @private void newroot_setup__make_mountpoint ( **mp, **NEWROOT, **fail! )
#
#  Creates mp in NEWROOT.
#
newroot_setup__make_mountpoint() { newroot_setup__dodir "${mp?}"; }

# int newroot_setup_dirs ( *file=**NEWROOT/**NEWROOT_CONFIG_DIR/makedirs )
#
# Reads directory paths from the given files and creates them in NEWROOT.
#
# Returns 0 if all dirs have been created,
# else returns the number of directories that could not be created.
# Also returns 0 if no file was specified and the default one did not exist.
# Returns 40 if a file could not be read.
#
newroot_setup_dirs() {
   if [ -z "${1-}" ]; then
      set -- "${NEWROOT}/${NEWROOT_CONFIG_DIR#/}/makedirs"
      [ -f "${1}" ] || return 0
   fi

   local fail=0
   F_ITER_ON_ERROR=return \
   file_list_iterator newroot_setup__dodir "$@" && return ${fail}
}

# int newroot_setup_mountpoints ( fstab_file=**NEWROOT/etc/fstab )
#
#  Reads all mountpoints from fstab_file and
#  creates the necessary directories in NEWROOT.
#
newroot_setup_mountpoints() {
   if [ -n "${1-}" ]; then
      [ -f "${1}" ] || return 41
   else
      set -- "${NEWROOT}/etc/fstab"
      [ -f "${1}" ] || return 0
   fi

   local fail=0
   F_FSTAB_ITER=newroot_setup__make_mountpoint \
   fstab_iterator "${1}" && return ${fail}
}

# int newroot_setup_premount (
#    file=**NEWROOT/**NEWROOT_CONFIG_DIR/premount,
#     **CMDLINE_FSCK,
# ), raises die()
#
#  Premounts all mountpoints listed in %file.
#
#  Returns 0 on success, else != 0. Also returns 0 if file was not specified
#  and the default one did not exist.
#
newroot_setup_premount() {
   if [ -n "${1-}" ]; then
      [ -f "${1}" ] || return 1
   else
      set -- "${NEWROOT}/${NEWROOT_CONFIG_DIR#/}/premount"
      [ -f "${1}" ] || return 0
   fi

   F_ITER_ON_ERROR=return \
   file_list_iterator newroot_premount_essential "${1}"
}

# int newroot_setup_tmpdir (
#    file=**NEWROOT/**NEWROOT_CONFIG_DIR/tmpdir
# )
#
#  Creates private per-user directories /tmp/users in NEWROOT.
##
## from initramfs/newroot/tmpdir:
## user_spec ::= <name>:<uid>[:[<gid>]]
#
newroot_setup_tmpdir() {
   if [ -n "${1-}" ]; then
      [ -f "${1}" ] || return 1
   else
      set -- "${NEWROOT}/${NEWROOT_CONFIG_DIR#/}/tmpdir"
      [ -f "${1}" ] || return 0
   fi

   newroot_tmpdir_init && newroot_tmpdir_users || return

   local failcount=0
   F_ITER_ON_ERROR=newroot_setup__failcount \
   file_list_iterator newroot_tmpdir_users "${1}"
   return ${failcount}
}

# void newroot_setup_all(), raises die()
#
#  Calls all/most of the newroot_setup functions (without args,
#  thus triggering their "default" behavior).
#
newroot_setup_all() {
   irun newroot_setup_dirs
   irun newroot_setup_mountpoints
   irun newroot_setup_premount
   irun newroot_setup_tmpdir
}
