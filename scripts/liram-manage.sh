# liram-manage
#
# --- LICENSE INFO ---
#
# This file is part of shlib.
# Copyright (C) 2013 André Erdmann <dywi@mailerd.de>
# Distributed under the terms of the GNU General Public License;
# either version 2 of the License, or (at your option) any later version.
#
# --- IMPORTANT ---
#
#  not compatible with busybox ash/hush + CONFIG_FEATURE_SH_STANDALONE=y
#
# --- ABOUT ---
#
# Userspace tool for managing liram.
# Currently, it is able to (re-)pack the system partially or entirely
# and update the "boot" slot afterwards.
#
# Critical sections are synchronized via filesystem locks. Note, however,
# that this requires that all liram-related actions are handled by *this*
# script (or other scripts that use the same lock(s)).
#
# --- CONFIGURATION ---
#
# This script heavily relies on file-based configuration. As an alternative,
# all configurable variables can be passed as keywords (PARAM=val <script>).
#
# Overall, two config files are used (by sourcing them, in order):
#
# * /etc/liram/config -- file created by *you* that sets most variables
# * /LIRAM_ENV        -- file created at boot-time that contains variables
#                        like LIRAM_DISK
#
#
# Important config variables:
#
# * PACK_SCRIPT (mandatory)
#    Path to the script that will actually pack your system.
#    This can also be a name if the pack script is in PATH.
#
# * LIRAM_BOOT_SLOT (defaults to "current")
#
#   Name of the boot slot. The boot slot has to be a symlink, if it exists.
#
# * LIRAM_FALLBACK_SLOT (optional)
#
#    Slot (name) that will be used to fix up the boot slot link.
#
# * LIRAM_IMAGE_ROOT
#
#    Directory that contains all slots. The path should be relative to
#    the mountpoint of the liram disk.
#
# * LIRAM_CORE_IMAGE_DIR
#
#    Directory that contains "core" images (typically host-generated files).
#    The path is interpreted as relative to LIRAM_IMAGE_ROOT if it does not
#    start with a "/", relative to the mountpoint of the liram disk if it
#    starts with a single "/", and absolute if it starts with more than one
#    "/" char. Note that the latter variant is not supported.
#
#
# --- USAGE ---
#
# Just call this script with "--help" to get a full list of command-line
# options. Note that the help message is created *after* reading and verifying
# the config file(s), so you won't get any help message if your configuration
# is incomplete.
# As mentioned before, most variables cannot be set this way.
# Currently, it is possible to set the script's mode (which has no real effect)
# and the slot's name (else the current date is used).
#
#

# @private void main__atexit()
#
#  cleanup function; releases locks etc.
#
main__atexit() {
   # cleanup first
   if [ -n "${LIRAM_DEST_SLOT-}" ]; then
      if \
         [ "${FAIL_CLEAN:-y}" = "y" ] && [ -d "${LIRAM_DEST_SLOT}/work" ]
      then
         rm -r -v -- "${LIRAM_DEST_SLOT}/work" || :
      fi

      rmdir -v --ignore-fail-on-non-empty -- "${LIRAM_DEST_SLOT-}" || :
   fi

   # recover LIRAM_BOOT_SLOT if required and possible
   #
   #  It's a good idea to unset LIRAM_FALLBACK_SLOT if the script was
   #  successful so that there's only condition to check here.
   #
   if \
      [ -n "${LIRAM_FALLBACK_SLOT-}"  ] &&  \
      [ -n "${LIRAM_BOOT_SLOT_NAME-}" ] && [ -n "${LIRAM_BOOT_SLOT-}" ] && \
      [ ! -h "${LIRAM_BOOT_SLOT}" ] &&  [ ! -e "${LIRAM_BOOT_SLOT}" ]
   then
      ln -s -f -T -- "${LIRAM_FALLBACK_SLOT##*/}" "${LIRAM_BOOT_SLOT}" || :
   fi

   # then umount
   [ -z "${LIRAM_DISK_MOUNT_RESTORE+X}"     ] || ( umount_liram_disk; ) || :
   [ -z "${LIRAM_BOOTDISK_MOUNT_RESTORE+X}" ] || ( umount_liram_bootdisk; ) || :

   # finally, release the lock
   [ "${PACK_HAVE_LOCK:-n}" != "y" ] || pack_lock_release
}

# @NOT_OVERRIDING void pack_lock_acquire (
#    **PACK_LOCK, **PACK_HAVE_LOCK!
# ), raises die()
#
#  Acquires PACK_LOCK if not already claimed by this process.
#
#  Does not return unless successful.
#
NOT_OVERRIDING pack_lock_acquire
pack_lock_acquire() {
   if [ "${PACK_HAVE_LOCK:-n}" != "y" ]; then
      autodie lockfile_acquire "${PACK_LOCK:?}" \
         "${LOCKFILE_ACQUIRE_RETRY:?}" \
         "${LOCKFILE_ACQUIRE_WAIT_INTVL:?}"
      PACK_HAVE_LOCK=y
   fi
   return 0
}

# @NOT_OVERRIDING void pack_lock_release (
#    **PACK_LOCK, **PACK_HAVE_LOCK!
# ), raises die()
#
#  Releases the lock.
#  Note that this always fails the lock has not been acquired.
#
#  Does not return unless successful.
#
NOT_OVERRIDING pack_lock_release
pack_lock_release() {
   PACK_HAVE_LOCK=n
   autodie lockfile_release "${PACK_LOCK}"
}

# @private void main__init(), raises exit()
#
#  Initial setup (vars and basic checks).
#
main__init() {
   local v0
   atexit_register main__atexit
   atexit_enable INT TERM EXIT

   readconfig_optional "${CONFFILE:=/etc/liram/config}"
   readconfig_optional "${LIRAM_ENV:=/LIRAM_ENV}"

   varcheck LIRAM_DISK DEVNULL PACK_SCRIPT
   autodie qwhich "${PACK_SCRIPT}"

   case "${SCRIPT_NAME}" in
      *-pack|*-kernup|*-fixup|*-die)
         DEFAULT_SCRIPT_MODE="${SCRIPT_NAME##*-}"
      ;;
      *)
         : ${DEFAULT_SCRIPT_MODE:=pack}
      ;;
   esac

   # DATE_NOW (YYYY-MM-DD)
   DATE_NOW=$(date +%F)

   # LOCKFILE vars
   #  main__atexit() already does this
   LOCKFILE_RELEASE_AT_EXIT=n
   : ${LOCKFILE_ACQUIRE_RETRY:=10}
   : ${LOCKFILE_ACQUIRE_WAIT_INTVL:=0.5}

   #  PACK_LOCKDIR, PACK_LOCK
   : ${PACK_LOCKDIR:=/run/lock/liram}
   PACK_LOCK="${PACK_LOCKDIR}/liram.lock"

   #  no locks have been claimed so far
   PACK_HAVE_LOCK=n

   # env must not affect these vars
   unset -v LIRAM_DISK_MOUNT_RESTORE
   unset -v LIRAM_BOOTDISK_MOUNT_RESTORE

   # LIRAM_DISK_MP, LIRAM_BOOTDISK_MP
   #  specifying relative paths for these variables in the config file
   #  is not recommended (you're on your own)
   #
   : ${LIRAM_BOOTDISK_MP:=/mnt/liram/boot}
   : ${LIRAM_DISK_MP:=/mnt/liram/sysdisk}

   # LIRAM_IMAGE_ROOT
   #  expected config value is a path relative to LIRAM_DISK_MP
   #  (runtime value is an absolute path)
   #
   if [ -n "${LIRAM_IMAGE_ROOT-}" ]; then
      LIRAM_IMAGE_ROOT="${LIRAM_IMAGE_ROOT#/}"
      if [ -n "${LIRAM_IMAGE_ROOT}" ]; then
         LIRAM_IMAGE_ROOT="${LIRAM_DISK_MP}/${LIRAM_IMAGE_ROOT}"
      else
         LIRAM_IMAGE_ROOT="${LIRAM_DISK_MP}"
      fi
   else
      LIRAM_IMAGE_ROOT="${LIRAM_DISK_MP}"
   fi

   # LIRAM_BOOT_SLOT
   #  a virtual slot that links to the slot currently configured
   #
   # !!! this has to be a symlink if it exists
   #
   : ${LIRAM_BOOT_SLOT:=current}

   # LIRAM_SLOT
   #  dest dir for newly created images
   #
   : ${LIRAM_SLOT:=${DATE_NOW}}

   # LIRAM_CORE_IMAGE_DIR
   #  Overlay directory whose content will be symlinked into the new slot
   #
   #
   #  Typically, this should contain host-generated/persistent image files
   #  like /usr and /.
   #
   case "${LIRAM_CORE_IMAGE_DIR-}" in
      /)
         # that's not supported
         die
      ;;
      'none')
         LIRAM_CORE_IMAGE_DIR=""
      ;;
      '')
         LIRAM_CORE_IMAGE_DIR="${LIRAM_IMAGE_ROOT}/core/default"
         LIRAM_CORE_IMAGE_RELPATH="../core/default"
      ;;
      //*)
         # double-slash enforces absolute path (again, you're on your own
         # when using unsafe values)
         # This is not implemented.
         die "absolute path for LIRAM_CORE_IMAGE_DIR is not supported."
         LIRAM_CORE_IMAGE_DIR="${LIRAM_CORE_IMAGE_DIR#/}"
         #LIRAM_CORE_IMAGE_RELPATH
      ;;
      /*)
         # path relative to LIRAM_DISK_MP
         if [ "${LIRAM_IMAGE_ROOT}" != "${LIRAM_DISK_MP}" ]; then
            LIRAM_CORE_IMAGE_RELPATH="../../${LIRAM_CORE_IMAGE_DIR#/}"
         else
            LIRAM_CORE_IMAGE_RELPATH="../${LIRAM_CORE_IMAGE_DIR#/}"
         fi
         LIRAM_CORE_IMAGE_DIR="${LIRAM_DISK_MP}/${LIRAM_CORE_IMAGE_DIR#/}"
      ;;
      *)
         # path relative to LIRAM_IMAGE_ROOT
         LIRAM_CORE_IMAGE_RELPATH="../${LIRAM_CORE_IMAGE_DIR#/}"
         LIRAM_CORE_IMAGE_DIR="${LIRAM_IMAGE_ROOT}/${LIRAM_CORE_IMAGE_DIR#./}"
      ;;
   esac


   # create LOCKDIR, ignore failure if it exists
   mkdir -p "${PACK_LOCKDIR}" 2>${DEVNULL} || [ -d "${PACK_LOCKDIR}" ] || die

   # locate LIRAM_DISK
   local DISK_DEV
   if [ -n "${LIRAM_DISK_DEV-}" ] && [ -b "${LIRAM_DISK_DEV}" ]; then
      true
   elif get_disk "${LIRAM_DISK}"; then
      LIRAM_DISK_DEV="${DISK_DEV:?}"
   else
      LIRAM_DISK_DEV=
      ewarn "cannot resolve device name of ${LIRAM_DISK}" "LIRAM_DISK"
   fi

   # locate LIRAM_BOOTDISK
   if [ -n "${LIRAM_BOOTDISK_DEV-}" ] && [ -b "${LIRAM_BOOTDISK_DEV}" ]; then
      true
   elif [ -n "${LIRAM_BOOTDISK-}" ]; then
      if get_disk "${LIRAM_BOOTDISK}"; then
         LIRAM_BOOTDISK_DEV="${DISK_DEV:?}"
      else
         LIRAM_BOOTDISK_DEV=
         ewarn "cannot resolve device name of ${LIRAM_BOOTDISK}" "LIRAM_BOOTDISK"
      fi
   else
      veinfo "no boot disk configured" "LIRAM_BOOTDISK"
   fi
}

# @NOT_OVERRIDING void make_disk_writable (
#    dev, mp, fstype=auto, opts="noatime,rw", v0!
# ), raises die()
#
#  Acquires a lock and (re-)mounts a device writable (at mp). Dies on error.
#  Stores the device's previous state in %v0.
#
#  Creates a %mp/.keep file when trying to remount.
#
NOT_OVERRIDING make_disk_writable
make_disk_writable() {
   : ${v0=}
   pack_lock_acquire

   if disk_mounted "${1}" "${2}"; then
      if touch "${2}/.keep"; then
         v0=keep
      else
         autodie remount_rw "${2}"
         v0=remount_ro
      fi
   elif disk_mounted "${1}"; then
      die "${1} is already mounted (but not at ${2})."
   else
      [ -z "${v0}" ] || die "cannot mount device if %v0 is already set."

      autodie dodir_minimal "${2}"
      autodie do_mount -t "${3:-auto}" -o "${4:-noatime,rw}" "${1}" "${2}"
      v0=do_umount
   fi
   # @double_tap
   [ -n "${v0}" ] || die
}


# @NOT_OVERRIDING void mount_liram_disk (
#    **LIRAM_DISK_DEV, **LIRAM_DISK_MP, **LIRAM_DISK_FSTYPE=auto,
#    **LIRAM_DISK_MOUNT_RESTORE!
# ), raises die()
#
#  "Mounts" the liram disk,
#  either by mounting its device directly or by remounting it.
#
#  Does not return unless successful.
#
NOT_OVERRIDING mount_liram_disk
mount_liram_disk() {
   varcheck LIRAM_DISK_DEV
   local v0="${LIRAM_DISK_MOUNT_RESTORE=}"
   make_disk_writable "${LIRAM_DISK_DEV}" "${LIRAM_DISK_MP}"
   [ -n "${LIRAM_DISK_MOUNT_RESTORE}" ] || LIRAM_DISK_MOUNT_RESTORE="${v0}"
}

# @NOT_OVERRIDING void mount_liram_bootdisk (
#    **LIRAM_BOOTDISK_DEV, **LIRAM_BOOTDISK_MP, **LIRAM_BOOTDISK_FSTYPE=auto,
#    **LIRAM_BOOTDISK_MOUNT_RESTORE!
# ), raises die()
#
#  "Mounts" the liram boot disk,
#  either by mounting its device directly or by remounting it.
#
#  Does not return unless successful.
#
NOT_OVERRIDING mount_liram_bootdisk
mount_liram_bootdisk() {
   varcheck LIRAM_BOOTDISK_DEV
   local v0="${LIRAM_BOOTDISK_MOUNT_RESTORE=}"
   make_disk_writable "${LIRAM_BOOTDISK_DEV}" "${LIRAM_BOOTDISK_MP}"
   [ -n "${LIRAM_BOOTDISK_MOUNT_RESTORE}" ] || \
      LIRAM_BOOTDISK_MOUNT_RESTORE="${v0}"
}

# @NOT_OVERRIDING void restore_mount_state ( mount_state, mp ), raises exit()
#
#  Restores a previous mount state.
#
#  Does not return unless successful.
#
NOT_OVERRIDING restore_mount_state
restore_mount_state() {
   case "${1-}" in
      'remount_ro'|'do_umount')
         autodie ${1} "${2?}"
      ;;
      'keep')
         true
      ;;
      *)
         die "impossible to restore previous mount state '${1}'."
      ;;
   esac
}

# @NOT_OVERRIDING void umount_liram_disk (
#    **LIRAM_BOOTDISK_MOUNT_RESTORE!, **LIRAM_DISK_MP
# ), raises die()
#
#  "Unmounts" the liram disk.
#  Whatever that means depends on the mount restore variable.
#
#  Does not return unless successful.
#
NOT_OVERRIDING umount_liram_disk
umount_liram_disk() {
   restore_mount_state "${LIRAM_DISK_MOUNT_RESTORE?}" "${LIRAM_DISK_MP}"
   unset -v LIRAM_DISK_MOUNT_RESTORE
}

# @NOT_OVERRIDING void umount_liram_bootdisk (
#    **LIRAM_BOOTDISK_MOUNT_RESTORE!, **LIRAM_BOOTDISK_MP
# ), raises die()
#
#  "Unmounts" the liram boot disk.
#  Whatever that means depends on the mount restore variable.
#
#  Does not return unless successful.
#
NOT_OVERRIDING umount_liram_bootdisk
umount_liram_bootdisk() {
   restore_mount_state "${LIRAM_BOOTDISK_MOUNT_RESTORE?}" "${LIRAM_BOOTDISK_MP}"
   unset -v LIRAM_BOOTDISK_MOUNT_RESTORE
}

# @NOT_OVERRIDING void liram_disk_init(), raises die()
#
#  Mounts the liram disk and performs basic actions (e.g., creates all dirs,
#  sets disk-related variables).
#
#  Does not unmount the disk afterwards - this is expected to be done by
#  main__atexit().
#
#  Does not return unless successful.
#
NOT_OVERRIDING liram_disk_init
liram_disk_init() {
   die lalala
   mount_liram_disk
   autodie dodir_clean "${LIRAM_IMAGE_ROOT}"
   LIRAM_BOOT_SLOT_NAME="${LIRAM_BOOT_SLOT##*/}"
   varcheck LIRAM_BOOT_SLOT_NAME
   LIRAM_BOOT_SLOT="${LIRAM_IMAGE_ROOT}/${LIRAM_BOOT_SLOT_NAME}"
}

# @NOT_OVERRIDING void liram_get_slot(
#    **LIRAM_IMAGE_ROOT, **LIRAM_SLOT_NAME, **LIRAM_DEST_SLOT!
# ), raises die()
#
NOT_OVERRIDING liram_get_slot
liram_get_slot() {
   local s="${LIRAM_IMAGE_ROOT}/${LIRAM_SLOT_NAME}"

   if [ -e "${s}" ] || [ -h "${s}" ]; then
      # resolve conflict
      local i=0
      s="${LIRAM_IMAGE_ROOT}/${LIRAM_SLOT_NAME}-r${i}"

      while [ -e "${s}" ] || [ -h "${s}" ]; do
         i=$(( ${i} + 1 ))
         s="${LIRAM_IMAGE_ROOT}/${LIRAM_SLOT_NAME}-r${i}"
      done
   fi

   autodie mkdir -- "${s}"
   LIRAM_DEST_SLOT="${s}"
   autodie mkdir -- "${s}/work"
   LIRAM_WORK_SLOT="${s}/work"
}

# @NOT_OVERRIDING void liram_update_boot_slot ( name|dir, **LIRAM_BOOT_SLOT )
#
#  Updates the boot slot symlink.
#
NOT_OVERRIDING liram_update_boot_slot
liram_update_boot_slot() {
   [ -n "${1-}" ] || die
   local name="${1##*/}"
   [ -d "${LIRAM_IMAGE_ROOT}/${name}" ] || die
   # %name seems to be a slot, continue

   varcheck LIRAM_BOOT_SLOT LIRAM_BOOT_SLOT_NAME
   # boot slot variables are set
   if [ -h "${LIRAM_BOOT_SLOT}" ] || [ ! -e "${LIRAM_BOOT_SLOT}" ]; then
      autodie symlink_replace "${LIRAM_BOOT_SLOT}" "${name}"
   else
      die "cannot update boot slot: ${LIRAM_BOOT_SLOT} exists, but is not a symlink."
   fi
}

# void main__call_pack ( *pack_target )
#
main__call_pack() {
   varcheck LIRAM_WORK_SLOT PACK_SCRIPT
   (
      PACK_ROOT=/
      export PACK_ROOT
      IMAGE_DIR="${LIRAM_WORK_SLOT}"
      export IMAGE_DIR
      ${PACK_SCRIPT} "$@"
   ) || die
}

# void main__do_kernup()
#
main__do_kernup() { die "--kernup is TODO"; }

# void main__do_fixup()
#
main__do_fixup() { die "--fixup is TODO"; }


# @private @noreturn void main__do_die ( [message], [code] )
#
#  Very important function.
#
main__do_die() {
   local __F_DIE="${__F_DIE_ORIGINAL:?}"
   if [ -n "${1-}" ]; then
      die "${1}" "${2-}"
   else
      # messages straight from c-intercal
      local msg=
      ## max(RANDOM) < 2**15 (or <= 2**15?)
      case "${RANDOM:-X}" in
         1*) msg="A SOURCE IS A SOURCE, OF COURSE, OF COURSE" ;;
         2*) msg="PROGRAM HAS DISAPPEARED INTO THE BLACK LAGOON" ;;
         3*) msg="PROGRAM FELL OFF THE EDGE" ;;
         4*) msg="SAYING 'ABRACADABRA' WITHOUT A MAGIC WAND WON'T DO YOU ANY GOOD" ;;
         5*) msg="I WASN'T PLANNING TO GO THERE ANYWAY" ;;
         6*) msg="PROGRAMMER IS INSUFFICIENTLY POLITE" ;;
         7*) msg="NOTHING VENTURED, NOTHING GAINED" ;;
         8*) msg="BUMMER, DUDE!" ;;
         *)  msg="DO YOU REALLY EXPECT ME TO HAVE IMPLEMENTED THAT?" ;;
      esac
      die "${msg}" "${2-}"
   fi
}

# @pragma double_tap
#
#  Returns true if non-essential actions (mostly checks) are desired.
#
__double_tap__() {
   if [ "${DOUBLE_TAP:-y}" = "y" ]; then
      if [ -n "${1-}" ]; then
         ewarn "${1}" "DOUBLE TAP"
      else
         ewarn "" "DOUBLE TAP!"
      fi
      return 0
   else
      return 1
   fi
}

# void main__do_pack()
#
main__do_pack() {
   [ ${UID} -eq 0 ] || die

   # mount disk + initial fixup
   liram_disk_init

   # get dest and work slot
   liram_get_slot

   # pack %PACK_TARGETS
   main__call_pack ${PACK_TARGET:=update}

   # transfer files from work slot to dest slot
   #  assumption: work slot has files
   #
   if __quiet__; then
      autodie mv -t "${LIRAM_DEST_SLOT}" "${LIRAM_WORK_SLOT}"/?*
   else
      autodie mv -v -t "${LIRAM_DEST_SLOT}" "${LIRAM_WORK_SLOT}"/?*
   fi

   # another assumption: work slot is empty after moving files
   autodie rmdir "${LIRAM_WORK_SLOT}"

   # import LIRAM_CORE_IMAGE_DIR (if set)
   if [ -z "${LIRAM_CORE_IMAGE_DIR-}" ]; then
      true
   elif [ -d "${LIRAM_CORE_IMAGE_DIR-}" ]; then
      if [ -d "${LIRAM_SLOT}/${LIRAM_CORE_IMAGE_RELPATH}/" ]; then
         # ^unsafe: existence of these dirs does not imply
         #   LIRAM_CORE_IMAGE_DIR == LIRAM_CORE_IMAGE_RELPATH
         #
         # Add further checks if required.
         #

         # globbing is essential here
         set +f

         local cimage cfile cname
         for cimage in ${LIRAM_CORE_IMAGE_DIR}/*.*; do
            if [ -f "${cimage}" ]; then
               cfile="${cimage##*/}"; cname="${cfile%.*}"
               set -- "${LIRAM_SLOT}/${cname}".*

               # [ -n "$1" ] should always be true here
               if \
                  [ -n "${1-}" ] && [ "${1}" = "${LIRAM_SLOT}/${cname}.*" ]
               then
                  # add link
                  einfo "Adding core image ${cfile}"
                  autodie ln -s -T -- \
                     "${LIRAM_CORE_IMAGE_RELPATH}/${cfile}" "${LIRAM_SLOT}/${cfile}"

                  if __double_tap__; then
                     [ -h "${LIRAM_SLOT}/${cfile}" ] || \
                        die "${LIRAM_SLOT}/${cfile} is not a symlink."
                     [ -e "${LIRAM_SLOT}/${cfile}" ] || \
                        die "${LIRAM_SLOT}/${cfile} is a broken symlink."
                  fi
               fi
            fi
         done
      else
         # broken RELPATH
         die "core image relpath is not valid (${LIRAM_CORE_IMAGE_RELPATH})."
      fi
   else
      # this is an error
      die "core image dir ${LIRAM_CORE_IMAGE_DIR} does not exist."
   fi

   # update boot slot
   liram_update_boot_slot "${LIRAM_DEST_SLOT##*/}"

   # successfully done!
   unset -v LIRAM_FALLBACK_SLOT
}

main__exit_with_help() {
   [ -z "${1-}" ] || eerror "${1}"

cat << END_HELP
${SCRIPT_NAME} -- basic liram maintenance

Provides the following tools:
* pack the current system into a new slot (--pack)
* try to automatically fix issues (--fixup) [TODO]
* deploy new kernel images (--kernup) [TODO, low priority]

Usage: liram-manage [--help,-h,--usage] [--version,-V]
                    [--pack|--fixup|--kernup]
                    [--slot,-s <name>] [arg [arg...]]


The meaning of the positional args depends on the mode:
* --pack   : pack targets (defaults to 'update')
* --fixup  : @undef
* --kernup : image file

The default mode is --${DEFAULT_SCRIPT_MODE#--}.
END_HELP

   exit ${2:-${EX_USAGE}}
}



# int main (???)
#
#
main() {
   local __F_DIE_ORIGINAL="${__F_DIE:-die__minimal}"
   local __F_DIE=main__do_die

   main__init || die

   : ${SCRIPT_MODE:=${DEFAULT_SCRIPT_MODE:?}}
   : ${PACK_TARGETS=}

   while [ $# -gt 0 ]; do
      local doshift=1
      case "${1}" in
         '--slot'|'-s')
            [ -n "${2-}" ] && [ "x${2#-}" = "x${2}" ] || die "--slot needs an arg"
            LIRAM_SLOT="${2}"
            doshift=2
         ;;
         '--pack'|'--kernup'|'--fixup'|'--die')
            SCRIPT_MODE="${1#--}"
         ;;
         '--help'|'--usage'|'-h')
            main__exit_with_help "" ${EX_OK}
            die
         ;;
         '--version'|'-V')
            echo "0.0.1"
            exit 0
         ;;
         *)
            PACK_TARGETS="${PACK_TARGETS-}${PACK_TARGETS:+ }${1}"
         ;;
      esac

      [ ${doshift} -eq 0 ] || shift ${doshift} || die
   done
   LIRAM_SLOT_NAME="${LIRAM_SLOT##*/}"
   unset -v LIRAM_SLOT

   main__do_${SCRIPT_MODE} || die
}


# @implicit int main (...)
#
main "$@"
