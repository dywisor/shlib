# @noreturn initramfs_die ( [message], [code] )
#
#  initramfs die() function. May start a rescue shell (in future).
#
initramfs_die() {
   die "$@"
}

# @extern void autodie ( *argv, **AUTODIE )
# @extern void run     ( *argv, **AUTODIE )
#
#  Overridden via AUTODIE=irun.
#

# void irun ( *cmdv ), raises die()
#
#  Runs cmdv and logs the result. Treats failure as critical.
#
irun() {
   local rc=0
   "$@" || rc=$?
   if [ ${rc} -eq 0 ]; then
      dolog --level=INFO "command '$*' succeeded."
   else
      dolog -0 --level=CRITICAL "command '$*' returned ${rc}."
      die "cannot recover from failure"
   fi
}

# @function_alias iron() renames irun (...)
#
#  Handy idiom.
#
iron() { irun "$@"; }

# int|void inonfatal ( *cmdv, **NONFATAL_RETURNS_VOID=n )
#
#  Runs cmdv and logs the result. Warns about failure.
#  Returns the command's return code if NONFATAL_RETURNS_VOID is not set
#  to 'y', else returns void (always 0).
#
inonfatal() {
   local rc=0
   "$@" || rc=$?
   if [ ${rc} -eq 0 ]; then
      dolog --level=DEBUG "command '$*' succeeded."
   else
      dolog -0 --level=WARN "command '$*' returned ${rc}."
   fi
   [ "${NONFATAL_RETURNS_VOID:-n}" = "y" ] || return ${rc}
}

# @implicit void main()
#
#  Sets the AUTODIE variable.
#
AUTODIE=irun
