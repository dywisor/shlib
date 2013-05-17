## this module provides initramfs versions of mount()/umount() which
## wrap the actual call with irun().

# void imount ( *argv )
#
#  Alias to irun do_mount ( *argv ).
#
imount() {
   irun do_mount "$@"
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
