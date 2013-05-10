## symlinking is atomic (even for nfs v2/v3)

# quickref
#
# functions:
#
# int lockfile_acquire()     -- lock, retry, wait_intvl
# int lockfile_acquire_now() -- lock
# int lockfile_release()     -- lock
#
# vars:
#
# yesno LOCKFILE_RELEASE_AT_EXIT (=y) --
# yesno LOCKFILE_AUTO_DELETE     (=n) -- must set before/when retrieving a lock
#

# @private void lockfile__atexit_release ( lock )
#
#  Releases a lock. Does nothing if the pid check fails for it.
#  Always returns 0 (void).
#
lockfile__atexit_release() {
   __lockfile_release "${1?}" "y" || true
}

# @private void lockfile__atexit_main (
#    **LOCKFILE__LOCKS, **LOCKFILE_RELEASE_AT_EXIT=y
# )
#
#  Calls lockfile__atexit_release ( %lock ) foreach %lock in %LOCKFILE__LOCKS
#  if LOCKFILE_RELEASE_AT_EXIT is set to 'y'.
#
lockfile__atexit_main() {
   if \
      [ "${LOCKFILE_RELEASE_AT_EXIT:-y}" = "y" ] && \
      [ -n "${LOCKFILE__LOCKS-}" ]
   then
      local F_ITER=lockfile__atexit_release ITER_UNPACK_ITEM="n"

      line_iterator "${LOCKFILE__LOCKS}" || true
   fi
}

# @private void lockfile_atexit_register (
#    [lock],
#    **LOCKFILE__ATEXIT_REGISTERED!, **LOCKFILE__LOCKS!
# )
#
#  Enables the lockfile atexit function and appends %lock to the list of
#  locks to be released at exit.
#
lockfile__atexit_register() {
   if [ "${LOCKFILE__ATEXIT_REGISTERED:-n}" != "y" ]; then
      atexit_register_unsafe lockfile__atexit_main && \
      LOCKFILE__ATEXIT_REGISTERED=y
   fi

   if [ -n "${1-}" ]; then
      if [ -n "${LOCKFILE__LOCKS-}" ]; then

LOCKFILE__LOCKS="${LOCKFILE__LOCKS}
${1}"

      else
         LOCKFILE__LOCKS="${1}"
      fi
   fi
}

# @private int __lockfile_release ( lock, ignore_pid_mismatch=n ),
#  raises function_die()
#
#  Releases a lock. Does a pid-based check if lock points to a directory
#  and contains a "stat" file.
#  Returns 0 if the lock has been released or did not exist.
#
#  Does not release the lock if it has the "stat" file and the pid check fails.
#  Dies in that case unless ignore_pid_mismatch is set to 'y'.
#
__lockfile_release() {
   if ! [ -h "${1-}" ]; then
      return 0
   elif [ -e "${1}/stat" ]; then
      local pid
      local DONT_CARE
      read pid DONT_CARE < "${1}/stat"

      if [ "${pid}" != "$$" ]; then
         if [ "${2:-n}" = "y" ]; then
            return 0
         else
            function_die "attempted to release a foreign lock (our pid=$$, their pid=${pid}"
         fi
      fi
   fi
   rm "${1-}"
}


# @private int __lockfile_acquire_now ( lock, link_target, **LOCKFILE_AUTO_DELETE=n )
#
#  Immediately acquires a symlink lock that points to link_target.
#  Returns 0 if successful, else a non-zero value is returned.
#  Automatically registers the acquired lock for deletion at exit if
#  LOCKFILE_AUTO_DELETE is set to 'y'.
#
__lockfile_acquire_now() {
   ln -s -T -- "${2:?}" "${1:?}" 2>/dev/null || return
   [ "${LOCKFILE_AUTO_DELETE:-n}" != "y" ] || \
      lockfile__atexit_register "${1}"
}

# int lockfile_acquire_now ( lock, **LOCKFILE_AUTO_DELETE=n )
#
#  Immediately acquires a symlink lock pointing to /proc/<pid>.
#  Returns 0 if successful, else a non-zero value is returned.
#  Automatically registers the acquired lock for deletion at exit if
#  LOCKFILE_AUTO_DELETE is set to 'y'.
#
lockfile_acquire_now() {
   __lockfile_acquire_now "${1:?}" "/proc/$$"
}

# int lockfile_acquire (
#    lock,
#    max_retry=INF, wait_intvl=0.1,
#    **LOCKFILE_AUTO_DELETE=n
# )
#
#  Acquires a symlink lock pointing to /proc/<pid>.
#  Waits until successful (return value 0) or max_retry reached (with a
#  return value of 20).
#  Automatically registers the acquired lock for deletion at exit if
#  LOCKFILE_AUTO_DELETE is set to 'y'.
#
lockfile_acquire() {
   local lock="${1:?}" link_target="/proc/$$" \
      max_retry="${2-}" wait_intvl="${3:-0.1}"

   SLEEPLOOP_RETRY="${2-}" SLEEPLOOP_INTVL="${3:-0.1}" \
      sleeploop __lockfile_acquire_now "${1:?}" "/proc/$$"
}

# int lockfile_release ( lock )
#
#  Releases a lock. Returns 0 if the lock has been released, else a non-zero
#  value is returned.
#
lockfile_release() {
   [ -h "${1:?}" ] && __lockfile_release "${1}"
}
