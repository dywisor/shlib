#@section functions

# @noreturn initramfs_die (
#    [message], [code], **F_INITRAMFS_DIE=, **INITRAMFS_SHELL_ON_DIE=y
# )
#
#  initramfs die() function.
#
initramfs_die() {
   if [ -n "${F_INITRAMFS_DIE-}" ]; then
      ${F_INITRAMFS_DIE} "$@"

   elif [ "${INITRAMFS_SHELL_ON_DIE:-y}" = "y" ]; then
      initramfs_launch_rescue_shell "$@"

   else
      initramfs_telinit
      die "$@"
   fi
   return 150
}

# int initramfs_assert ( *test_condition ), raises initramfs_die()
#
#  Calls test ( *test_condition ) and raises initramfs_die() if the result
#  is not 0.
#
initramfs_assert() {
   if test "$@"; then
      return 0
   else
      initramfs_die "an assertion failed: test $*"
      ## initramfs_die could return
      return 1
   fi
}

# @extern void autodie ( *argv, **F_AUTODIE )
# @extern void run     ( *argv, **F_AUTODIE )
#
#  Overridden via F_AUTODIE=irun.
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
      initramfs_die "cannot recover from failure"
   fi
}

# @function_alias iron() renames irun (...)
#
#  Handy idiom.
#
iron() { irun "$@"; }

# int inonfatal ( *cmdv )
#
#  Runs cmdv and logs the result. Warns about failure.
#
#  Returns the command's return code.
#
inonfatal() {
   local rc=0
   "$@" || rc=$?
   if [ ${rc} -eq 0 ]; then
      dolog --level=DEBUG "command '$*' succeeded."
   else
      dolog -0 --level=WARN "command '$*' returned ${rc}."
   fi
   return ${rc}
}


#@section vars
# @implicit void main()
#
#  Sets the F_AUTODIE, AUTODIE and AUTODIE_NONFATAL variables.
#
#  Note: Usually, initramfs modules should use irun()/inonfatal() directly.
#
F_AUTODIE=irun
AUTODIE=irun
AUTODIE_NONFATAL=inonfatal
