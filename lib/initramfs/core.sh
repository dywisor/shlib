## this is a virtual module that pulls in the initramfs base modules
## (nearly all initramfs/ top-level modules are direct dependencies)
##
##  the following functionality is guaranteed to be provided:

## functions from die, function_die

# @extern @noreturn die()
# @extern @noreturn function_die()


## functions from logging

# @extern int dolog()
# @extern int dolog_debug()
# @extern int dolog_info()
# @extern int dolog_warn()
# @extern int dolog_error()
# @extern int dolog_critical()
# @extern int dolog_timestamp()
#
#  Logger function(s).
#

## functions from fs/dodir

# @extern int dodir()
# @extern int dodir_clean()
# @extern int keepdir()


## functions from fs/dofile

# @extern int dofile()


## functions from initramfs/basemounts

# @extern void initramfs_baselayout()
#
#  Initializes the baselayout of the initramfs,
#  creates some directories and mounts /proc, /sys, /dev and /dev/pts.
#

# @extern void basemounts_stop()
#
#  "Stops" the basemounts by unmounting them or moving them into NEWROOT,
#  depending on what has been configured (INITRAMFS_MOVE_BASEMOUNTS).
#


## functions from initramfs/disk

# @extern void initramfs_waitfor_disk()
#
#  Resolves a disk identifier and stores the associated device node in the
#  DISK_DEV variable. Does all necessary calls like "mdev -s" and software
#  raid assembly.
#

# @extern void initramfs_mount_disk(), raises initramfs_die()
# @extern void imount_disk(), raises initramfs_die()
# @extern int  initramfs_mount_disk_nonfatal()
#
#  Tries to find the device identified by disk_identifier and mounts it.
#


## functions from initramfs/misc

# @extern int  initramfs_sleep()
# @extern int  initramfs_debug_sleep()
# @extern int  initramfs_rootdelay()
# @extern int  initramfs_kmsg_redirect()
# @extern void initramfs_suppress_printk()
# @extern void initramfs_switch_root(), raises initramfs_die()


## functions from initramfs/mount

# @extern void imount(),    raises initramfs_die()
# @extern void imount_fs(), raises initramfs_die()
# @extern void iumount(),   raises initramfs_die()
#
#  Wrapper functions that call irun ( do_mount()/domount_fs()/do_umount() ).
#


## functions from initramfs/run

# @extern @noreturn initramfs_die()

# @extern void irun()
# @extern void iron()
# @extern void run()
# @extern void autodie()
#
#  Runs a command and logs the result. Treats failure as critical.
#

# @extern int inonfatal()
#
#  Runs a command and logs the result. Returns the command's return value.
#


## functions from initramfs/use

# @extern int  initramfs_use         ( *flag )
# @extern int  initramfs_use_call    ( flag, *cmdv )
# @extern void initramfs_enable_use  ( *flag )
# @extern void initramfs_disable_use ( *flag )


## functions from initramfs/vars

# @extern void initramfs_vars()
#
#  Initializes some initramfs variables. Does not need to be called manually.
#
