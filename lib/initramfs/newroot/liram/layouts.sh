#@section header
# This file should be included by non-liram modules in order to get
# "full" liram functionality (core + all non-experimental layouts)
#
#
## function from newroot/initramfs/liram/core
#
# @extern void liram_init(), raises *die()
#
#  This function does everything that is needed to initialize and populate
#  a rootfs in ram (NEWROOT as tmpfs).
#
#  External modules should use this function after setting variables
#  like LIRAM_DISK, LIRAM_LAYOUT etc..
#
#
# variables that are expected to be set by external modules,
# e.g. by initramfs/cmdline/:
#
# LIRAM_DISK (mandatory)
#
#  disk identifier of the liram sysdisk, e.g. "LABEL=liram_sysdisk"
#
# LIRAM_DISK_FSTYPE (=auto)
#
#  filesystem type of the liram sysdisk
#
# LIRAM_SLOT (mandatory)
#
#  The liram slot is the name of a subdirectory relative to the mountpoint
#  of the liram sysdisk that contains all (or most) files required for
#  populating the rootfs.
#
# LIRAM_ROOTFS_SIZE (mandatory)
#
#  An integer that specifies the maximum size of the rootfs, in MiB.
#
# LIRAM_LAYOUT (=default)
#
#  A string that specifies which layout will be used to create the rootfs.
#
#  A layout defines *how* newroot will be created and *what* will be used
#  to do so.
#
# NEWROOT_HOME_DIR (=/NEWROOT/home)
#
#  Absolute path to NEWROOT's home directory.
#  Used by the 'default' layout, for example.
#
