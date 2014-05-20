#@section functions_export

## "high-level" functions from zram modules

# ZRAM_LOAD_MODULE (default: "")
#
#  Controls whether (and how) the zram module gets autoloaded.
#
#  An empty value or any-of 'n', 'false', ':' disable autoloading.
#  A value of 'y', 'true' or 'modprobe' enables autoloading using the default
#  function. Any other value is interpreted as int-returning function
#  that handles autoloading on its own.
#

# ZRAM_NUM_STATIC_DEVICES (default: 0)
#
#  Offset for the num_devices parameter when loading the zram module.
#  Useful if you want to have a _known_ number of "static" tmpfs-replacing
#  zram devices, and a dynamic number of zram swaps.
#


# int zram_autoload_module (
#    num_devices, **ZRAM_NUM_STATIC_DEVICES, **ZRAM_LOAD_MODULE
# )
#
#  Autoloads the zram module (depending on %ZRAM_LOAD_MODULE).
#

# int zram_destruct ( [ident] )
#
#  Unmounts/Deactivates a zram devices and resets it.
#
#  The ident parameter is optional and defaults to last created zram device.
#

# int zram_swap ( num_swaps=1, size_m=**ZRAM_SWAP_DEFAULT_SIZE, swapon="y" )
#
#  Creates the requested number of swap devices, each with the given size.
#  Also activates them depending on %swapon.
#

# int zram_autoswap (
#    max_swap_space_spec := "/2",
#    min_swapdev_size    := **ZRAM_SWAP_DEFAULT_SIZE,
#    max_num_swaps       := <cpu core count>,
#    max_sys_mem         := <sys mem>,
#    **ZRAM_LOAD_MODULE
# )
#
#  A wrapper around zram_swap() that partitions a fraction of the system's
#  memory into up to %max_num_swaps swap devices (and activates them).
#
#  By default, half of the system's memory is partitioned into up to
#  <phyical cpu core count> swap devices (not logical count).
#  (TODO note: maybe use logical core count)
#
#  Note:
#   For convenience, this function autoloads the zram module.
#

# int zram_disk (
#    size_m, mountpoint, mount_opts="rw,noatime", fstype:="auto",
#    mode=, owner=, *mkfs_args
# )
#
#  Initializes a zram device of the given size (in megabytes),
#  creates a filesytem for it and mounts it.
#
#  Adjusts the mountpoint's permissions/ownership depending on mode/owner.
#

# int zram_dotmpfs (
#    mountpoint, name=<default>, opts:="rw,mode=1777,noatime", fstype:="auto"
# )
#
#  Creates & mounts a tmpfs-like zram_disk with name as filesystem label.
#  The %opts parameter should be empty or a comma-separated list of
#  tmpfs mount options.
#
#  This function is similar to zram_disk(), with the difference that
#  (a) the filesystem name (label) is an explicit parameter and
#  (b) size_m/mode/owner are part of %opts and behave differently.
#
#  %opts parsing has some limitations (for example, the size= option is
#  mandatory and must be in megabytes). See the respective module for details.
#  Apart from that, this function is mostly interchangeable with dotmpfs()
#  from fs/mount/dotmpfs.
#

# int zram_tmpfs ( mountpoint, opts:=<default>, fstype:=<default> )
#
#  Same as zram_dotmpfs(), but doesn't accept a %name.
#
