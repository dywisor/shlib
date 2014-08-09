#@section functions

# @funcdef zram_mkfs <fstype> int zram_disk_mkfs_<fstype> (
#    <args>,
#    **ZRAM_FS_NAME, **ZRAM_NAME, **ZRAM_DEV, **ZRAM_BLOCK, **ZRAM_SIZE_M
# )

# @no-stdout @private int zram_disk__run_command ( *cmdv )
#
zram_disk__run_command() {
   1>>${DEVNULL} "${@}"
}


# @private int zram_disk__run_mkfs ( *cmdv, **ZRAM_FS_NAME, **ZRAM_DEV )
#
zram_disk__run_mkfs() {
   ${AUTODIE_NONFATAL-} zram_disk__run_command \
      "${@}" -L "${ZRAM_FS_NAME:?}" "${ZRAM_DEV:?}"
}


# @zram_mkfs ext4 zram_disk_mkfs_ext4()
#
#  <args> ignored
#
zram_disk_mkfs_ext4() {
   zram_disk__run_mkfs "${X_MKFS_EXT4:?}" \
      -O "dir_index,extents,filetype,^has_journal,sparse_super,^uninit_bg" \
      -E "nodiscard"
}

# @zram_mkfs ext2 zram_disk_mkfs_ext2()
#
#  <args> ignored
#
zram_disk_mkfs_ext2() {
   zram_disk__run_mkfs "${X_MKFS_EXT2:?}" -O "sparse_super"
}

# @zram_mkfs btrfs zram_disk_mkfs_btrfs()
#
#  <args> ignored
#
zram_disk_mkfs_btrfs() {
   zram_disk__run_mkfs "${X_MKFS_BTRFS:?}"
}
