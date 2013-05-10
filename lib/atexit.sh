# linelist __ATEXIT_FUNCTIONS
#  a list of statements "function *args" that will be called at exit.
#
: ${__ATEXIT_FUNCTIONS=}

# void atexit_enable ( *signals=INT, TERM, EXIT )
#
# Activates atexit for the given signals.
#
atexit_enable() {
   trap __atexit__ ${*:-TERM EXIT}
   ATEXIT_ENABLED=y
}

# void atexit_disable ( *signals=INT, TERM, EXIT )
#
# Deactivates atexit for the given signals by restoring the default
# behavior.
#
atexit_disable() {
   trap - ${*:-TERM EXIT}
   ATEXIT_ENABLED=n
}

# true __atexit_run ( *argv )
#
#  Runs argv and returns 0.
#  (Helper function for __atexit__())
#
__atexit_run() {
   "$@" || return 0
}

# void __atexit_clear_pipe()
#
#  This is an iterator function that simply notifies the user that
#  an item has been ignored.
#
#  __atexit__ sets F_ITER=__atexit_clear_pipe when done in order to stop
#  any iteration.
#
__atexit_clear_pipe() {
   if [ "${HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
      eerror "atexit, clear_pipe: ignoring '$*'"
   else
      echo "atexit, clear_pipe: ignoring '$*'" 1>&2
   fi
   return 0
}

# void __atexit__()
#
# Runs all registered atexit functions.
#
__atexit__() {
   atexit_disable
   F_ITER=__atexit_run ITER_UNPACK_ITEM=y line_iterator "${__ATEXIT_FUNCTIONS}"
   # set F_ITER to stop any iteration
   F_ITER=__atexit_clear_pipe
}

# void atexit_register_unsafe ( *argv )
#
#  Registers argv for atexit execution without doing any checks.
#
atexit_register_unsafe() {
   if [ -n "${__ATEXIT_FUNCTIONS:-}" ]; then

__ATEXIT_FUNCTIONS="${__ATEXIT_FUNCTIONS}
$*"

   else
      __ATEXIT_FUNCTIONS="$*"
   fi
}

# void atexit_register ( *argv )
#
# Registers argv for atexit execution if not already registered.
#
atexit_register() {
   [ -z "$*" ] || \
      linelist_has "$*" "${__ATEXIT_FUNCTIONS}" || \
      atexit_register_unsafe "$*"
}

# implicit atexit_main ( **ATEXIT_ENABLE=y )
#
# Calls atexit_enable() if ATEXIT_ENABLE is set to 'y'.
#
if [ "${ATEXIT_ENABLE:-y}" = "y" ]; then
   atexit_enable
else
   ATEXIT_ENABLED=n
fi
