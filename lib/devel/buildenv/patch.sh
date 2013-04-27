# buildenv add-on that provides patch() functions
# (This module automatically pulls in devel/buildenv/core)
#
# quickref:
#
# @extern void buildenv_prepare()   -- workdir, srcdir
# @extern int buildenv_make()       -- *argv
# @extern int buildenv_run()        -- *cmdv
# @extern int buildenv_run_in_src() -- *cmdv
# @extern int buildenv_prepare_do() -- workdir, srcdir, cmd, *argv
# @extern int buildenv_printrun()   -- *cmdv
# int buildenv_patch_src()          -- [patch_opts], *patch_file
# int buildenv_patch_work()         -- [patch_opts], *patch_file
#

# int buildenv_patch_src (
#    *patch_file, **BUILDENV_PATCH_DRY_RUN="default"
#    **...
# )
#
#  Applies a series of patches to the buildenv srcdir.
#  See buildenv__apply_patches for details.
#
#
buildenv_patch_src() {
   [ $# -gt 0 ] || return 0
   BUILDENV_PATCH_DRY_RUN="${BUILDENV_PATCH_DRY_RUN:-default}" \
   BUILDENV_PATCH_OPTS="${BUILDENV_PATCH_OPTS--up1}" \
   BUILDENV_PATCH_REVERSE_WARN=y \
   buildenv_run_in_src buildenv__apply_patches "$@"
}

# int buildenv_patch_work (
#    [patch_opts="-up1"], *patch_file, **BUILDENV_PATCH_DRY_RUN="default"
#    **...
# )
#
#  Like buildenv_patch_src(), but patches the workdir.
#
buildenv_patch_work() {
   [ $# -gt 0 ] || return 0
   BUILDENV_PATCH_DRY_RUN="${BUILDENV_PATCH_DRY_RUN:-default}" \
   BUILDENV_PATCH_OPTS="${BUILDENV_PATCH_OPTS--up1}" \
   BUILDENV_PATCH_REVERSE_WARN=y \
   buildenv_run buildenv__apply_patches "$@"
}

# @private int buildenv__apply_patches (
#    *patch_file, **BUILDENV_PATCH_DRY_RUN, **BUILDENV_PATCH_OPTS, **...
# )
#
#  Applies a series of patches to BUILDENV_WORKDIR (or tries to).
#
#  Depending on %BUILDENV_PATCH_DRY_RUN, this function will either
#
#  * "stepwise", "check-during":
#
#    for each path: try whether a patch and apply it, else return non-zero
#
#  * "n", "no", "never":
#
#    Apply all patches, return non-zero on first failure.
#
#  * "only", "yes", "y":
#
#    Perform a (non-stepwise) dry run only.
#
#  * "check-before":
#
#    Try "only", followed by "no"
#
#  * "auto", also: "default"
#
#    Use "ony" if "check-before" return success, else try "check-during".
#
#    This costs more time than any of the above methods, but tries to apply
#    patches as safe as possible.
#
#  * <any other value>: prints an error message and returns 103
#
#  !!! BUILDENV_PATCH_DRY_RUN must not be readonly.
#
#  Note: it will always be tested whether a patch has already been applied.
#
buildenv__apply_patches() {
   : ${BUILDENV_PATCH_OPTS?}

   local patch_file

   # the return statements at the end of the case clauses
   # are for readability only

   case "${BUILDENV_PATCH_DRY_RUN}" in

      "stepwise"|"check-during")
         for patch_file; do
            if buildenv__try_patch_reverse; then
               true
            elif buildenv__try_patch; then
               buildenv__do_patch || return
            else
               ewarn "Cannot apply patch '${patch_file##*/}'."
               return 99
            fi
         done

         return 0
      ;;

      "no"|"never"|"n")
         for patch_file; do
            buildenv__try_patch_reverse || buildenv__do_patch || return
         done

         return 0
      ;;

      "only"|"yes"|"y")
         local fail_count=0
         for patch_file; do
            if buildenv__try_patch_reverse; then
               true
            elif buildenv__try_patch; then
               veinfo "patch '${patch_file##*/}' can be applied without errors."
            else
               einfo "patch '${patch_file##*/}' cannot be applied."
               fail_count=$(( ${fail_count} + 1 ))
            fi
         done

         return ${fail_count}
      ;;

      "check-before")
         BUILDENV_PATCH_DRY_RUN="only" buildenv__apply_patches "$@" && \
         BUILDENV_PATCH_DRY_RUN="no"   buildenv__apply_patches "$@"

         return ${?}
      ;;

      "auto"|"default")
         if BUILDENV_PATCH_DRY_RUN="only" buildenv__apply_patches "$@"; then
            einfo "apply_patches: dry run succeeded, continuing with the 'never' strategy"

            BUILDENV_PATCH_REVERSE_WARN=n \
            BUILDENV_PATCH_DRY_RUN="no" \
            buildenv__apply_patches "$@"
         else
            einfo "apply_patches: dry run returned ${?}, using the'check-during' strategy"

            BUILDENV_PATCH_REVERSE_WARN=n \
            BUILDENV_PATCH_DRY_RUN="check-during" \
            buildenv__apply_patches "$@"
         fi

         return ${?}
      ;;

      *)
         eerror "buildenv__apply_patches(): BUILDENV_PATCH_DRY_RUN='${mode}' is unsupported"
         return 103
      ;;
   esac
}


# helper functions for buildenv__apply_patches

# @private int buildenv__do_patch ( **patch_file )
#
buildenv__do_patch() {
   einfo "Applying patch '${patch_file##*/}'"
   if patch ${BUILDENV_PATCH_OPTS-} -r - -i "${patch_file:?}"; then
      return 0
   else
      eerror "Failed to apply patch '${patch_file##*/}'!"
      return 20
   fi
}

# @private int buildenv__try_patch ( **patch_file )
#
buildenv__try_patch() {
   patch ${BUILDENV_PATCH_OPTS-} --quiet --dry-run -f -r - -i "${patch_file:?}"
}

# @private int buildenv__try_patch_reverse ( **patch_file )
#
buildenv__try_patch_reverse() {
   if \
      patch ${BUILDENV_PATCH_OPTS-} \
         --dry-run -f -R -r - -i "${patch_file:?}" 2>/dev/null 1>/dev/null
   then
      [ "${BUILDENV_PATCH_REVERSE_WARN:-y}" != "y" ] || \
         ewarn "Patch already applied: ${patch_file##*/}"
      return 0
   else
      return 1
   fi
}
