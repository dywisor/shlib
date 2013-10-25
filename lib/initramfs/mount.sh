## this module provides initramfs versions of mount()/umount() which
## wrap the actual call with irun().

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


# @implcit void main ( **F_DOMOUNT_MP! )
#
F_DOMOUNT_MP=imount_mp
