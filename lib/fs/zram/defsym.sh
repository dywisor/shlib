#@section const
readonly ZRAM_BYTES_TO_MBYTES_FACTOR=$(( 1024 * 1024 ))

#@section vars

: ${ZRAM_SWAP_DEFAULT_SIZE:=20}
: ${ZRAM_SWAP_BASE_PRIORITY=2000}

# the number of "static" devices which is added to num_devices
# when loading the zram module
# Can be empty or any integer (even < 0 -- not recommended)
#
: ${ZRAM_NUM_STATIC_DEVICES:=0}

# whether to autoload the zram module (y, true, modprobe or a function name)
# or not (n, false, : or <empty>)
#
: ${ZRAM_LOAD_MODULE=}

: ${X_MODPROBE:=modprobe}
: ${X_SWAPON:=swapon}
: ${X_SWAPOFF:=swapoff}
: ${X_MKSWAP:=mkswap}

: ${X_MKFS_EXT2:=mkfs.ext2}
: ${X_MKFS_EXT3:=mkfs.ext3}
: ${X_MKFS_EXT4:=mkfs.ext4}
