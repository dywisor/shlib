#@section functions

# @funcdef zram_mkfs <fstype> int zram_disk_mkfs_<fstype> (
#    <args>, **ZRAM_NAME, **ZRAM_DEV, **ZRAM_BLOCK, **ZRAM_SIZE_M
# )

# @zram_mkfs ext4 zram_disk_mkfs_ext4()
#
#  <args> ignored
#
zram_disk_mkfs_ext4() {
   local features

   features="dir_index,extents,filetype,^has_journal,sparse_super,^uninit_bg"


   1>>${DEVNULL} ${AUTODIE_NONFATAL-} ${X_MKFS_EXT4:?} \
      -m 0 -E nodiscard -L "${ZRAM_NAME:?}" -O "${features}" "${ZRAM_DEV:?}"
}

# @zram_mkfs ext2 zram_disk_mkfs_ext2()
#
#  <args> ignored
#
zram_disk_mkfs_ext2() {
   local features

   features='sparse_super'


   1>>${DEVNULL} ${AUTODIE_NONFATAL-} ${X_MKFS_EXT2:?} \
      -m 0 -L "${ZRAM_NAME:?}" -O "${features}" "${ZRAM_DEV:?}"
}
