#@section header
## this module provides initramfs versions of mount()/umount() which
## wrap the actual call with irun().

#@section functions

# void imount ( *argv )
#
#  Alias to irun do_mount ( *argv ).
#
imount() {
   irun do_mount "$@"
}

# @domount_mp void imount_mp ( mp, *argv )
#
#  Alias to irun domount3 ( mp, *argv ).
#
imount_mp() {
   irun domount3 "$@"
}

# void iumount ( *argv )
#
#  Alias to irun do_umount ( *argv ).
#
iumount() {
   irun do_umount "$@"
}

# void imount_fs ( mp, fs, opts=, fstype=auto )
#
#  Alias to irun domount_fs (...).
#
imount_fs() {
   irun domount_fs "$@"
}

# void iremount_ro ( *mountpoints )
#
#  Alias to irun remount_ro ( *mountpoints ).
#
## @NEED_UPDATE_CORE
##
iremount_ro() {
   irun remount_ro "$@"
}

# void iremount_rw ( *mountpoints )
#
#  Alias to irun remount_rw ( *mountpoints ).
#
## @NEED_UPDATE_CORE
##
iremount_rw() {
   irun remount_rw "$@"
}

#@section module_init_vars
# @implicit void main ( **F_DOMOUNT_MP! )
#
F_DOMOUNT_MP=imount_mp
