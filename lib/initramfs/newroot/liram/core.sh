## This module must not depend on any file from ./layout/

# You probably want to include ./layouts and not this module (./core).

## functions from fs/filesize

# @extern int get_filesize ( fs_item )
#
#  Determines the size of fs_item (in MiB) and stores the result in %FILESIZE.
#


## functions from initramfs/newroot/base

# @extern void newroot_doprefix ( fspath, **NEWROOT )
# @extern void newroot_detect_home_dir ( force=n, **NEWROOT_HOME_DIR! )


## functions from initramfs/newroot/liram/base

# @extern void liram_init(), raises *die()
#
#  This function does everything that is needed to initialize and populate
#  a rootfs in ram (NEWROOT as tmpfs).
#
#  External modules should use this function after setting variables
#  like LIRAM_DISK, LIRAM_LAYOUT etc..
#
#  In fact, this is the only function that non-liram modules should care
#  about.
#

# @extern ~int liram_die          (...) wraps initramfs_die (...)
# @extern ~int liram_populate_die (...) wraps liram_die (...)

# @extern int liram_populate ( **LIRAM_LAYOUT=default ), raises liram_die()
#
#  Populate NEWROOT using the configured layout (or the default one).
#
#  Also sets variables required for population,
#  e.g. TARBALL_SCAN_DIR and SLOT.
#


## functions from initramfs/newroot/liram/setup

# @extern int  newroot_setup_dirs        ( *file=<default> )
# @extern int  newroot_setup_mountpoints ( fstab_file=<default> )
# @extern int  newroot_setup_premount    ( file=<default> )
# @extern int newroot_setup_tmpdir       ( file=<default> )
# @extern void newroot_setup_all()
# @extern int liram_setup_subtrees       ( file=<default> )


## functions from initramfs/newroot/liram/subtree

# @extern void liram_mount_subtree ( mp, size_m, name, opts )


## functions from initramfs/newroot/liram/util

# @extern void liram_scan_files()
#
#  Searches for files that can be used to populate NEWROOT.
#

# @extern int liram_get_tarball  ( name )
# @extern int liram_get_squashfs ( name )
# @extern int liram_get_sfs      ( name )
#
#  Get files by name. The (absolute) filepath will be stored in %v0.
#

# @extern int liram_unpack_name ( name, dest="" )
#
#  Unpacks a tarball referenced by name into NEWROOT/dest.
#

# @extern int liram_unpack_replace_name (
#    name, dest="", backup="", delete_backup=""
# )
#
#  Like liram_unpack_name(), but replaces NEWROOT/dest instead of
#  overwriting it.
#

# @extern int liram_unpack_default ( name, tarball_file=<detect> ),
#  raises initramfs_die()
#
#  Unpacks a tarball into its default directory (depending on name).
#  Optionally searches for the tarball if no second arg supplied.
#
#  Returns 0 on success.
#

# @extern int liram_unpack_name_default ( *name ), raises initramfs_die()
#
#  Unpacks zero or more tarballs referenced by name into their default
#  destition (e.g. "rootfs" => "/", "usr" => "/usr").
#
#  Returns on first failure.
#

# @extern int liram_unpack_all_default(), raises initramfs_die()
#
#  Unpacks whatever available to its default location.
#
#  !!! This will fail if you add unknown entries to the TARBALL_SCAN_NAMES
#      variable.
#

# @extern int liram_unpack_optional (
#    name, tarball_file=<detect>, dest=<detect>, **v0!
# )
#
#  Unpacks an optional tarball using whatever function that fits,
#  either newroot_unpack_tarball() or liram_unpack_default().
#
#  Returns 0 if a tarball has been extracted, else 1 (no such tarball).
#
#  Note: While existence of the file is optional, unpacking is not.
#        This function will die if the tarball exists but cannot be extracted.
#

# @extern int liram_unpack_etc (
#    tarball_file=<detect>, **LIRAM_ETC_INCREMENTAL=n
# )
#
#  Unpacks the etc tarball into newroot, either in incremental mode or
#  by replacing etc, depending on LIRAM_ETC_INCREMENTAL.
#

# @extern int liram_sfs_container_import()

# @extern int newroot_sfs_container_mount()          -- sfs_name, mp
# @extern void newroot_sfs_container_init()          -- mp, size_m
# @extern int newroot_sfs_container_import()         -- sfs_file, sfs_name
# @extern int newroot_sfs_container_lock()
# @extern int newroot_sfs_container_unlock()
# @extern int newroot_sfs_container_downsize()
# @extern int newroot_sfs_container_finalize()
# @extern int newroot_sfs_container_avail()
# @extern int newroot_sfs_container_mount_writable() -- sfs_name, mp, size, aufs_root
