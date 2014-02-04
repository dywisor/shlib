#@section funcdef

# @funcdef liram_manage_lock <name> liram_manage_lock_<name> (
#    **LIRAM_MANAGE_HAVE_<NAME>_LOCK!, **LIRAM_MANAGE_<NAME>_LOCK
# )
#
#  Acquires a reentrant filesystem lock.
#

# @funcdef liram_manage_unlock <name> liram_manage_unlock_<name> (
#    **LIRAM_MANAGE_HAVE_<NAME>_LOCK!, **LIRAM_MANAGE_<NAME>_LOCK
# )
#
#  Releases a filesystem lock.
#

# @funcdef liram_manage_check_lock liram_manage_have_<name>_lock (
#    **LIRAM_MANAGE_HAVE_<NAME>_LOCK="n"
# )
#
#  Returns 0 if the lock has been acquired, else 1.
#


#@section functions

# void liram_manage_create_lockdir ( **LIRAM_MANAGE_LOCKDIR )
liram_manage_create_lockdir() {
   liram_manage_autodie dodir_minimal "${LIRAM_MANAGE_LOCKDIR}"
}

# @private void liram_manage__lock_acquire (
#    have_lock=n, lockfile,
#    **LOCKFILE_ACQUIRE_RETRY=10, **LOCKFILE_ACQUIRE_WAIT_INTVL=0.5
# )
#
liram_manage__lock_acquire() {
   [ "${1:-n}" != "y" ] || return 0
   local LOCKFILE_AUTO_DELETE=n

   liram_manage_log_debug +lock "acquire ${2}"
   liram_manage_autodie lockfile_acquire "${2:?}" \
      "${LOCKFILE_ACQUIRE_RETRY:-10}" "${LOCKFILE_ACQUIRE_WAIT_INTVL:-0.5}"
}

# @private void liram_manage__lock_release ( lockfile )
#
liram_manage__lock_release() {
   liram_manage_log_debug +lock "release ${1}"
   liram_manage_autodie lockfile_release "${1:?}"
}

# @liram_manage_lock pack liram_manage_lock_pack()
#
liram_manage_lock_pack() {
   liram_manage__lock_acquire "${LIRAM_MANAGE_HAVE_PACK_LOCK:-n}" \
      "${LIRAM_MANAGE_PACK_LOCK}" && \
   LIRAM_MANAGE_HAVE_PACK_LOCK=y
}

# @liram_manage_unlock pack liram_manage_unlock_pack()
#
liram_manage_unlock_pack() {
   LIRAM_MANAGE_HAVE_PACK_LOCK=n
   liram_manage__lock_release "${LIRAM_MANAGE_PACK_LOCK}"
}

# @liram_manage_check_lock liram_manage_have_pack_lock()
#
liram_manage_have_pack_lock() {
   [ "${LIRAM_MANAGE_HAVE_PACK_LOCK:-n}" = "y" ]
}
