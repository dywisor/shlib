# @external int devfs_mount()
# @external int devfs_mdadm()
# @external int devfs_seed()

# int devfs_lvm()
#
#  Scans for lvm volume groups.
#
#  !!! only suitable for temporary /
#
devfs_lvm() {
   if [ -d /etc/lvm/cache ]; then
      inonfatal rm -r -- /etc/lvm/cache
   fi
   lvm vgchange -a -y
}


# @OVERRIDE void devfs__configure ( **DEVFS_TYPE! )
#
#  Sets DEVFS_TYPE if unset.
#
unset -f devfs__configure || true
devfs__configure() {
   if [ -z "${DEVFS_TYPE-}" ]; then
      if initramfs_use mdev; then
         DEVFS_TYPE=mdev
      else
         DEVFS_TYPE=devtmpfs
      fi
   fi
}
