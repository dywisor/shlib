# this script simulates aufs_tmpfs_backed() calls
# and prints all commands to stdout

# @nop dodir_clean ( dir )
unset -f dodir_clean
dodir_clean() {
   [ -d "${1}" ] || echo "mkdir -p $1"
}

# @nop domount_fs ( mp, fs, opts, type )
unset -f domount_fs
domount_fs() {
   dodir_clean "$1"
   echo "mount -t $4 -o $3 $2 $1"
}

# @nop __aufs_check_support()
unset -f __aufs_check_support
__aufs_check_support() {
   fstype_supported aufs || ewarn "kernel does not support the aufs filesystem"
}

aufs_tmpfs_backed "$@"
