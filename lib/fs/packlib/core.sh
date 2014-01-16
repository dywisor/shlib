#@section module_vars

## EXCLUDE_LIST should be the last entry in PACK_VARS_TARGET
## as it could contain many newlines
PACK_VARS_TARGET="\
PACK_TARGET PACK_NAME PACK_SRC PACK_TYPE PACK_DESTFILE \
PACK_GENSCRIPT_DEST \
F_PACK_EXCLUDE F_CREATE_EXCLUDE_ITEM F_PACK_EXCLUDE_CREATE_ITEM \
EX_FUNC \
EXCLUDE_LIST"

PACK_VARS_GLOBAL="\
PACK_SRC_ROOT \
PACK_IMAGE_DIR
PACK_COMPRESS_TARBALL PACK_COMPRESS_SQUASHFS \
PACK_COMPRESS__MKSFS_OPT PACK_COMPRESS__TAR_OPT \
PACK_TARGETS PACK_OVERWRITE \
PACK_EXCLUDE_PREFIX \
PACK_TAR_OPTS PACK_TAR_OPTS_APPEND \
PACK_MKSFS_OPTS PACK_MKSFS_OPTS_APPEND \
DOPACK_COMMAND"

PACK_VARS="${PACK_VARS_TARGET} ${PACK_VARS_GLOBAL}"

PACK__DEFAULT_COMMAND="printcmd"

#@section functions

# void pack_printenv ( **$PACK_VARS )
#
pack_printenv() {
   printvar ${PACK_VARS?}
}

# @private int pack__construct_argv_and_run ( *excludes, **F__ACTUALLY_PACK )
#
#  Creates the pack command (including the given %excludes)
#  and calls %F__ACTUALLY_PACK(<pack_command>) afterwards.
#
#  Expects to be called in exclude_list_call() context.
#
pack__construct_argv_and_run() {
   #@VARCHECK F__ACTUALLY_PACK PACK_SRC PACK_DESTFILE PACK_TYPE
   local opts

   case "${PACK_TYPE}" in
      tar)
         opts="${PACK_TAR_OPTS-}${PACK_TAR_OPTS:+ }${PACK_TAR_OPTS_APPEND-}"
         if [ -n "${PACK_COMPRESS__TAR_OPT-}" ]; then
            opts="${opts}${opts:+ }${PACK_COMPRESS__TAR_OPT}"
         fi
         set -- \
            tar c -C "${PACK_SRC%/}/" ./ ${opts} -f "${PACK_DESTFILE}" "$@"
      ;;
      squashfs)
         opts="${PACK_MKSFS_OPTS-}${PACK_MKSFS_OPTS:+ }${PACK_MKSFS_OPTS_APPEND-}"
         if [ -n "${PACK_COMPRESS__MKSFS_OPT-}" ]; then
            opts="${opts}${opts:+ }${PACK_COMPRESS__MKSFS_OPT}"
         fi
         set -- \
            mksquashfs "${PACK_SRC%/}/" "${PACK_DESTFILE}" ${opts} "$@"
      ;;
      *)
         eerror "unsupported pack type '${PACK_TYPE}'" "BUG/FIXME"
         function_die "BUG! unsupported pack type" "dopack"
      ;;
   esac

   ${F__ACTUALLY_PACK} "$@"
}

# @private int dopack__save_retcode ( *cmdv, **dopack_rc! )
#
#  Runs *cmdv and copies its return code to %dopack_rc.
#
dopack__save_retcode() {
   dopack_rc=-1
   "$@"
   dopack_rc=${?}
   return ${dopack_rc}
}

# @private int dopack__common (
#    pack_func, **PACK_SRC, **PACK_DESTFILE, **dopack_rc!
# )
#
#  Wrapper for pack__construct_argv_and_run().
#
dopack__common() {
   #@VARCHECK PACK_SRC PACK_DESTFILE
   dopack_rc=-1
   local F__ACTUALLY_PACK="${1:?}"

   dopack__save_retcode \
      without_globbing_do exclude_list_call pack__construct_argv_and_run
}

# @private int dopack__verify_pack_src ( **PACK_SRC )
#
#  Verifies that the pack src dir exists.
#
dopack__verify_pack_src() {
   #@VARCHECK PACK_SRC
   if [ -d "${PACK_SRC}" ]; then
      return 0
   else
      eerror "dopack: pack src '${PACK_SRC}' does not exist."
      return 2
   fi
}

# @private int dopack__check_destfile_overwrite (
#    **PACK_DESTFILE, **PACK_OVERWRITE=n
# )
#
#  Handles destfile overwriting (prior to creating the image file).
#
dopack__check_destfile_overwrite() {
   #@VARCHECK PACK_DESTFILE
   if [ -e "${PACK_DESTFILE}" ]; then
      if [ ! -f "${PACK_DESTFILE}" ]; then
         eerror "dopack: '${PACK_DESTFILE}' exists, but is not a file."
         return 21
      elif [ "${PACK_OVERWRITE:-n}" != "y" ]; then
         eerror "dopack: '${PACK_DESTFILE}' exists."
         return 22
      else
         einfo "dopack: '${PACK_DESTFILE}' will be overwritten."
         # TODO: remove the bak file when done
         #  (or simply delete PACK_DESTFILE here instead of moving it)
         mv -vf -- "${PACK_DESTFILE}" "${PACK_DESTFILE}.bak" || return 23
      fi

   elif [ -h "${PACK_DESTFILE}" ]; then
      # broken symlink

      if [ "${PACK_OVERWRITE:-n}" != "y" ]; then
         eerror "dopack: '${PACK_DESTFILE}' is a broken symlink."
         return 24
      else
         ewarn "dopack: removing broken symlink '${PACK_DESTFILE}'"
         rm -v -- "${PACK_DESTFILE}" || return 25
      fi
   fi

   return 0
}

# @private int dopack__create_destfile_dir ( **PACK_DESTFILE )
#
#  Creates the destfile directory and ensures that it is writable.
#
dopack__create_destfile_dir() {
   #@VARCHECK PACK_DESTFILE
   local pack_destdir="${PACK_DESTFILE%/*}"
   : ${pack_destdir:=/}

   if ! dodir_minimal "${pack_destdir}"; then
      eerror "dopack: failed to create destfile dir '${pack_destdir}'."
      return 26
   elif ! touch -- "${pack_destdir}/.keep" 2>/dev/null; then
      eerror "dopack: destfile dir '${pack_destdir}' is not writable."
      return 27
   else
      return 0
   fi
}

# int dopack_image ( **dopack_rc! )
#
#  Packs the current target (to a file).
#
dopack_image() {
   dopack__save_retcode dopack__verify_pack_src && \
   dopack__save_retcode dopack__check_destfile_overwrite && \
   dopack__save_retcode dopack__create_destfile_dir && \
   dopack__common __run__
}

# int dopack_printcmd ( **dopack_rc! )
#
#  Prints the command that would be used to pack the current target.
#
dopack_printcmd() {
   dopack__common quote_cmdv
   echo
   return ${dopack_rc}
}

# int dopack_printenv ( **dopack_rc! )
#
dopack_printenv() {
   dopack__common pack_printenv
}

# int dopack_genscript ( **PACK_GENSCRIPT_DEST=<stdout>, **dopack_rc! )
#
#  Creates a script that can be used to pack the current target later
#  (and not necessarily on the machine creating the script).
#
#  Note / TODO: PACK_GENSCRIPT_DEST is ignored for now.
#               Scripts will be written to stdout.
#
#
#  Another note: The generated script has some limitations.
#                For instance, no_sub_mounts/--xdev excludes are evaluated
#                at script generation time.
#
dopack_genscript() {
   dopack__common pack__genscript
}

# int dopack ( *args, **DOPACK_COMMAND, **dopack_rc! )
#
#  Calls dopack_image(), dopack_printcmd(), dopack_printenv() or
#  dopack_genscript(), depending on %DOPACK_COMMAND.
#
#  This is equivalent to calling dopack_%DOPACK_COMMAND(*args) directly
#  (if %DOPACK_COMMAND is set and not empty).
#
dopack() {
   dopack_rc=-2
   if [ -z "${DOPACK_COMMAND}" ]; then
      function_die "\$DOPACK_COMMAND is not set." "dopack"
   fi
   dopack_${DOPACK_COMMAND} "$@"
}

# void pack_setup (
#    root_dir=**PWD, compression_format="default",
#    image_dir=**root_dir/images, pack_command=**PACK__DEFAULT_COMMAND
# )
#
pack_setup() {
   : ${PACK_TARGETS=}
   pack_zap_target_vars

   # --one-file-system is a sane default
   #  (not supported by busybox)
   : ${PACK_TAR_OPTS=--one-file-system}
   : ${PACK_MKSFS_OPTS=-noI -noappend}

   ${AUTODIE-} pack_set_src_root    "${1:-${PWD}}"
   ${AUTODIE-} pack_set_compression ${2:-default}
   ${AUTODIE-} pack_set_image_dir   "${3:-${PACK_SRC_ROOT}/images}"
   if [ -n "${4-}" ]; then
      DOPACK_COMMAND="${4}" || function_die #readonly
   elif [ -z "${DOPACK_COMMAND-}" ]; then
      DOPACK_COMMAND="${PACK__DEFAULT_COMMAND}" || function_die #readonly
   fi
}

# @private int pack__run_target (
#    pack_target, **DOPACK_COMMAND, **dopack_rc!
# ), raises die()
#
#  Actual pack target function. See pack_run_target() for details.
#
pack__run_target() {
   local v0

   # target vars controlled by pack_init_target() or pack_target_<target>()
   for v0 in ${PACK_VARS_TARGET:?}; do eval "local ${v0}"; done
   v0=

   # pack target name, might be used in pack_target_<target>()
   local PACK_TARGET="${1}"
   local PACK_TARGET_IS_VIRTUAL=

   if ! "pack_target_${1}"; then
      eerror "pack_run_target: failed to set up ${PACK_TARGET_IS_VIRTUAL:+virtual }pack target '${1}'"
      return 3
   elif [ -n "${PACK_TARGET_IS_VIRTUAL-}" ]; then
      [ ${dopack_rc} -ge 0 ] || return 4
      return ${dopack_rc}
   elif \
      [ -z "${PACK_NAME-}" ] || [ -z "${PACK_SRC-}" ] || \
      [ -z "${PACK_DESTFILE-}" ]
   then
      eerror "pack_run_target: target ${1} is missing essential variables (did it call pack_init_target()?)."
      return 5
   fi

   dopack_${DOPACK_COMMAND:?}
}

# int pack_run_target (
#    pack_target, **DOPACK_COMMAND, **PACK_TARGET_IN_SUBSHELL=n, **dopack_rc!
# ), raises die()
#
#  Packs a single target using the given pack command (DOPACK_COMMAND)
#  after configuring it (by calling pack_target_<%pack_target>()).
#
pack_run_target() {
   local __MESSAGE_INDENT="${__MESSAGE_INDENT-}"
   local my_rc
   dopack_rc=-3

   if [ -z "${1-}" ] || [ ${#} -gt 1 ]; then
      function_die \
         "expected exactly one non-empty arg, but got argv=\"${*}\", argc=${#}" \
         "pack_run_target"
   fi

   if ! __quiet__; then
      einfo "Packing target '${1}'..."
      message_indent
   fi

   if [ "${PACK_TARGET_IN_SUBSHELL:-n}" = "y" ]; then
      (
         readonly \
            PACK_SRC_ROOT PACK_IMAGE_DIR PACK_TARGETS DOPACK_COMMAND \
            PACK_VARS_TARGET PACK_VARS_GLOBAL PACK_VARS PACK__DEFAULT_COMMAND

         #readonly PACK_TARGET_IN_SUBSHELL

         pack__run_target "$@"
      )
   else
      pack__run_target "$@"
   fi
   my_rc=${?}

   if ! __quiet__; then
      message_outdent
      if [ ${my_rc} -eq 0 ]; then
         echo
      else
         eerror "failed to pack target '${1}' (rc=${my_rc})"
      fi
   fi
   return ${my_rc}
}

# @function_alias pack_target() renames pack_run_target()
#
pack_target() { pack_run_target "$@"; }

# int pack_run_targets ( *targets, **DOPACK_COMMAND )
#
#  Packs several targets.
#
#  Returns the number of targets that could not be packed or 255, whichever
#  is lower.
#
#  Does not "leak" dopack_rc.
#
pack_run_targets() {
   #@VARCHECK DOPACK_COMMAND
   local fail=0
   local dopack_rc

   while [ ${#} -gt 0 ]; do
      pack_run_target "${1}" || fail=$(( ${fail} + 1 ))
      shift
   done

   [ ${fail} -lt 256 ] || return 255
   return ${fail}
}

# int pack_all_targets ( **PACK_TARGETS, **DOPACK_COMMAND )
#
pack_all_targets() { pack_run_targets ${PACK_TARGETS-}; }

# @function_alias pack_targets() renames pack_run_targets()
#
pack_targets() { pack_run_targets "$@"; }
