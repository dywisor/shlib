#@HEADER
# this file lists all liram-related variables used in liram-manage modules
#
# You can grep through this file for vars with one of the following commands:
#
#  $ grep "^#[[:blank:]]*LIRAM_" vars_def.sh
#  $ sed -nr -e 's,^#\s*(LIRAM_\S+)(\s.+)?\s*,\1,p' < vars_def.sh
#  $ grep "^#[[:blank:]]*LIRAM_.*mandatory" vars_def.sh
#
# ----------------------------------------------------------------------------
#
# LIRAM_MANAGE_MNT_ROOT (default: /mnt/liram)
#
#  Default root directory for mount points.
#
#
# LIRAM_BOOTDISK (mandatory)
#
#  identifier of the disk containing kernel images
#
# LIRAM_BOOTDISK_DEV (private)
#
#  path to the boot disk device (e.g. /dev/sda1)
#
# LIRAM_BOOTDISK_FSTYPE (default: auto)
#
#  filesystem type of the boot disk
#
# LIRAM_BOOTDISK_MOUNT_RESTORE (private)
#
#  function for restoring the previous mount state of the boot disk
#
# LIRAM_BOOTDISK_MP (default: $LIRAM_MANAGE_MNT_ROOT/boot)
#
#  mountpoint of the boot disk
#
#
# LIRAM_DISK (mandatory)
#
#  identifier of the disk containing system/liram images
#
# LIRAM_DISK_DEV           (private)
# LIRAM_DISK_FSTYPE        (default: auto)
# LIRAM_DISK_MOUNT_RESTORE (private)
# LIRAM_DISK_MP            (default: $LIRAM_MANAGE_MNT_ROOT/disk)
#
#
# LIRAM_MANAGE_FAIL_CLEAN (default: y)
#
#  yesno-value (y/n) that controls whether work slots should be cleaned
#  up on failure.
#
#
# LIRAM_MANAGE_PLEASE_DONT_DIE (private, default: n)
#
#  yesno-value that makes liram_manange_die()/liram_manage_autodie() nonfatal.
#  Should be set in error-handling code only.
#
#
# LIRAM_MANAGE_SUCCESS (private, default: n)
#
#  yesno-value (or int) that indicates whether the most recent liram
#  application succeeded or not.
#
#
# LIRAM_MANAGE_PACK_SCRIPT (mandatory) [--pack]
#
#  name of or path to the actual pack script.
#  Must be compatible with fs/packlib/packscript/main (argparse-wise).
#
# LIRAM_MANAGE_X_UPDATE_CORE (mandatory) [--update-core]
#
#  name of or path to a script that fetches the core images.
#  Has to accept one arg, the core image dir (with trailing "/"),
#  which may be edited in-place.
#  It's the script's responsibility to back up / restore the core image dir
#  if that is desired.
#  Note that existing slots don't get re-linked,
#  so hardlinked image files might still exist after --update-core.
#
#  (Usually a short script that executes "rsync <remote uri> ${1}" etc.)
#
# LIRAM_MANAGE_X_UPDATE_KERNEL (mandatory) [--kernup]
#
#  name of or path to a script that fetches and deploys kernel images.
#  Has to accept one arg, the mountpoint of the boot disk.
#  !!! This script gets full access to the boot disk, be careful.
#
#
# LIRAM_BOOT_SLOT (optional, from LIRAM_ENV or user)
#
#  in the config file or LIRAM_ENV:
#   _name_ of the slot that has been / will be booted
#
#  at runtime: path to the boot slot
#
# LIRAM_BOOT_SLOT_NAME (private)
#
#  name of the boot slot (copy of $LIRAM_BOOT_SLOT)
#
#
# LIRAM_FALLBACK_SLOT (optional)
#
#  in the config file: name of the fallback slot
#  at runtime: path to the fallback slot
#
# LIRAM_FALLBACK_SLOT_NAME (private)
#
#  name of the fallback (copy of $LIRAM_FALLBACK_SLOT)
#
#
# LIRAM_DEST_SLOT (private)
#
#  path to the slot being worked on
#
# LIRAM_DEST_SLOT_NAME (private)
#
#  name of $LIRAM_DEST_SLOT
#
# LIRAM_DEST_SLOT_SUCCESS (private)
#
#  yesno-value indicating whether $LIRAM_DEST_SLOT can be used for booting
#  or not.
#
# LIRAM_DEST_SLOT_WORKDIR (private)
#
#  temporary directory for $LIRAM_DEST_SLOT. Usually $LIRAM_DEST_SLOT/work.
#
# LIRAM_SLOT (default: $DATE_NOW (see below))
#
#  in the config file: base name for new slots
#  at runtime: unset
#
# LIRAM_SLOT_NAME (private)
#
#  copy of $LIRAM_SLOT
#
#
# LIRAM_IMAGE_ROOT__CONFIG (private)
#
#  copy of $LIRAM_IMAGE_ROOT's config value
#
#  Empty or a path _relative_ to $LIRAM_DISK_MP that is the root directory
#  of all slots.
#
# LIRAM_IMAGE_ROOT (default: $LIRAM_DISK_MP)
#
#  in the config file: see $LIRAM_IMAGE_ROOT__CONFIG
#  at runtime: absolute path to the slot root directory
#
# LIRAM_CORE_IMAGE_DIR__CONFIG (private, default: core/default)
#
#  copy of $LIRAM_CORE_IMAGE_DIR's config value
#
#  see liram/manage/vars.sh->liram_manage_set_core_image_dir()
#
# LIRAM_CORE_IMAGE_DIR (default: $LIRAM_IMAGE_ROOT/core/default)
#
#  absolute path to the directory containing host-generated images like
#  / and /usr.
#
# LIRAM_CORE_IMAGE_RELPATH
#
#  path of the core image dir relative to $LIRAM_DEST_SLOT
#
#  *** relpath is not used as its creation is not considered stable ***
#
#
# LOCKFILE_ACQUIRE_RETRY (default: 10)
#
#  Max number of trys when trying to get a lock.
#
#
# LOCKFILE_ACQUIRE_WAIT_INTVL (default: 0.5)
#
#  Time in seconds to wait between each try (when acquiring a lock).
#
#
# LIRAM_MANAGE_LOCKDIR (default: /run/lock/liram)
#
#  Default root directory for filesystem locks.
#
# LIRAM_MANAGE_PACK_LOCK (default ($LIRAM_MANAGE_LOCKDIR/pack.lock)
#
#  Absolute path to the "pack" lock.
#  Actually, this is the only lock used so far (and just used for packing).
#
# LIRAM_MANAGE_HAVE_PACK_LOCK (private)
#
#  yesno-value indicating whether the "pack" lock has been acquired or not.
#
# DATE_NOW (~private, default: $(date +%F))
#
#  today's date (YYYY-MM-DD).
#
# LIRAM_HARDLINK_CORE (~private, default: y)
#
#  yesno-value that controls whether core images should be hardlinked (y)
#  or symlinked (n).
#
#  *** symlinks are not implemented due to relpath issues ***
#
# DEFAULT_PACK_TARGETS (optional)
#
#  the default space-separated list of pack targets
#  (read from the config file or $PACK_TARGETS(env))
#
#
# PACK_TARGETS (mandatory)
#
#  a list of targets to be actually packed
