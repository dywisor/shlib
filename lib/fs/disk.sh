# int get_disk ( disk_identifier )
#
#  Tries to resolve the device that is identified by %disk_identifier
#  and stores its filesystem path (/dev/...) in %DISK_DEV and returns 0
#  if successful, else returns 1 (and sets %DISK_DEV to the empty string).
#
#  Valid disk identifiers are
#  * LABEL= and UUID= notation (resolved via findfs)
#  * /dev/* (resolved via "test -b")
#
#  Unknown disk identifiers lead to a return value of 2.
#
get_disk() {
   DISK_DEV=""
   local dev

   case "${1-}" in
      /dev/*)
         dev="${1}"
      ;;
      LABEL=*|UUID=*)
         dev=`${SUDO-} findfs ${1} 2>/dev/null`
      ;;
      *)
         return 2
      ;;
   esac

   if [ -n "${dev-}" ] && [ -b "${dev}" ]; then
      DISK_DEV="${dev}"
      return 0
   else
      return 1
   fi
}

# int __waitfor_disk_action ( disk_identifier, **F_WAITFOR_DISK_DEV_SCAN= )
#
#  Helper function that is periodically called during waitfor_disk().
#  Calls F_WAITFOR_DISK_DEV_SCAN() if set, and get_disk ( disk_identifier )
#  afterwards.
#
__waitfor_disk_action() {
   if [ -n "${F_WAITFOR_DISK_DEV_SCAN-}" ]; then
      ${F_WAITFOR_DISK_DEV_SCAN}
   fi
   get_disk "${1}"
}

# int waitfor_disk (
#    disk_identifier,
#    max_wait_retries=4,
#    wait_interval=1,
#    **F_WAITFOR_DISK_DEV_SCAN=
# )
#
#  Waits for a disk device until it appears in /dev by calling get_disk()
#  until successful or %max_wait_retries reached.
#
waitfor_disk() {
   local rc=0
   dolog_info "Waiting for disk '${1:?}'"
   SLEEPLOOP_RETRY="${2-4}" SLEEPLOOP_INTVL="${3-1}" \
      sleeploop __waitfor_disk_action "${1:?}" || rc=$?

   if [ ${rc} -eq 0 ]; then
      dolog_info "disk '${1}' is ${DISK_DEV}"
   else
      dolog_error "cannot find device for disk '${1}'"
   fi
   return ${rc}
}

# int do_fsck ( disk=**DISK_DEV )
#
#  Performs a filesystem check for the given disk device and
#  returns its result.
#
do_fsck() {
   fsck -p -C0 -T "${1:-${DISK_DEV:?}}"
}
