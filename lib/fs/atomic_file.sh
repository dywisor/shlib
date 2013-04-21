# This module provides atomic (exclusive) access to files/dirs.
# It's a rather naive approach to avoid the lost update problem and
# quite useful if the status of a file (value, existence, ...) depends on
# its previous one.
#

# int atomic_file (
#    file, *cmdv,
#    **ATOMIC_FILE_MAX_RETRY=600, **ATOMIC_FILE_INTVL=0.1,
#    **ATOMIC_FILE_LOCK!
# )
#
#  Acquires a lock for the given file (<file>.__lock__),
#  executes *cmdv and finally releases the lock.
#
#  Waits up to 1 minute by default.
#
atomic_file() {
   local lock="${1:?}.__lock__"

   if \
      shift && [ $# -gt 0 ] && \
      LOCKFILE_AUTO_DELETE=y lockfile_acquire "${lock}" \
         "${ATOMIC_FILE_MAX_RETRY-600}" "${ATOMIC_FILE_INTVL-0.1}"
   then
      ATOMIC_FILE_LOCK="${lock}"
      local rc=0
      "$@" || rc=$?
      lockfile_release "${lock}"
      return ${rc}
   else
      return ${?}
   fi
}

# int atomic_file_do (
#    cmdv[0], cmdv[1]==file, *cmdv[2:], **<see atomic_file()>
# )
#
#  Calls atomic_file ( file, *cmdv ).
#
atomic_file_do() {
   atomic_file "${2:?}" "$@"
}
