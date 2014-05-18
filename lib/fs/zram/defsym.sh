#@section const
readonly ZRAM_BYTES_TO_MBYTES_FACTOR=$(( 1024 * 1024 ))

#@section vars

: ${ZRAM_SWAP_DEFAULT_SIZE:=20}
: ${ZRAM_SWAP_BASE_PRIORITY=2000}

: ${X_SWAPON:=swapon}
: ${X_SWAPOFF:=swapoff}
: ${X_MKSWAP:=mkswap}

: ${X_MKFS_EXT2:=mkfs.ext2}
: ${X_MKFS_EXT3:=mkfs.ext3}
: ${X_MKFS_EXT4:=mkfs.ext4}
