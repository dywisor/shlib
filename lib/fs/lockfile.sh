## symlinking is atomic (even for nfs v2/v3)

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
      local pid DONT_CARE
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
      atexit_register __lockfile_release "${1}" "y"
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

