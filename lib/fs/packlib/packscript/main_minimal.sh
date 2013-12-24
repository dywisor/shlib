#@HEADER
# loads pack target definitions from files ("pack recipes") and processes
# them, i.e. runs a dopack_*() command.

#@section vars
PACKSCRIPT_DEFAULT_COMMAND="image"
PACKSCRIPT_DEFAULT_COMPRESSION_TAR=xz
PACKSCRIPT_DEFAULT_COMPRESSION_SQUASHFS=gzip

#@section functions

packscript_load_recipes() {
   local _prev_targets
   while [ ${#} -gt 0 ]; do
      _prev_targets="${PACK_TARGETS-}"
      veinfo "loading recipe file '${1}'"
      if . "${1}"; then
         if [ "${PACK_TARGETS-}" = "${_prev_targets}" ]; then
            ewarn "recipe '${1##*/}' does not declare any targets."
         fi
         veinfo "success"
         ARG_NUM_RECIPES=$(( ${ARG_NUM_RECIPES:-0} + 1 ))
      else
         die "failed to load recipe file '${1}' (rc=${?})." ${?}
      fi
      shift
   done
}

# void packscript_load_recipes_from_list ( list_name:=**ARG_RECIPES )
#
packscript_load_recipes_from_list() {
   newline_list_call packscript_load_recipes "${1:-ARG_RECIPES}"
}

packscript_parse_args() {
   local v0

   local HELP_DESCRIPTION HELP_BODY HELP_USAGE HELP_FOOTER

   local ARGPARSE_FUNCNAME_PREFIX="packscript_argparse_"

   local ARGPARSE_HELP_SPACE="        "
   local ARGPARSE_HELP_INDENT=" "
   local I="${ARGPARSE_HELP_INDENT}"

# local argparse vars
HELP_DESCRIPTION="pack target helper"
HELP_BODY="load and process pack recipes

"

HELP_USAGE="Usage:
  ${SCRIPT_FILENAME} [option...] [--list|-l]
  ${SCRIPT_FILENAME} [option...] target [target...]"


HELP_OPTIONS="
${I}--recipe <file>        (-f) -- recipe file
${I}--root <dir>           (-S) -- pack src root directory
${I}--image-dir <dir>      (-I) -- image dir [<root dir>/images]
${I}--list                 (-l) -- list targets and exit
${I}--command <command>         -- pack command (image, printenv, printcmd
${I}                               or genscript) [${PACKSCRIPT_DEFAULT_COMMAND}]
${I}--printenv                  -- set pack command to 'printenv'
${I}--printcmd,
${I}--dry-run              (-n) -- set pack command to 'printcmd'
${I}--genscript                 -- set pack command to 'genscript' (TODO: --outfile, multiple targets)
${I}--outfile              (-O) -- output file for --genscript (IGNORED)
${I}--[no-]overwrite            -- [don't] overwrite existing image files
${I}--compression <comp>   (-C) -- set compression for all backends
${I}                                (gzip, xz, lzo[p], default)
${I}--tar-compression      (-t) -- set compression for tar [${PACKSCRIPT_DEFAULT_COMPRESSION_TAR}]
${I}   <comp>                       (none, gzip, bzip2, xz, lzo[p], default)
${I}--squashfs-compression (-s) -- set compression for mksquashfs [${PACKSCRIPT_DEFAULT_COMPRESSION_SQUASHFS}]
${I}   <comp>                       (gzip, xz, lzo[p], default)

"
HELP_FOOTER="
positional args:
${I}<target>                    -- target(s) to pack (\"-\" for stdin)
"

# -- end local argparse vars

   argparse_autodetect
   autodie argparse_parse "$@"
}

packscript_argparse_need_fs_arg() {
   argparse_need_arg "$@"
   v0=
   get_fspath "${1}" || argparse_die "${arg}: ${1} is not a valid filesystem path."
}

packscript_argparse_need_file_arg() {
   v0=
   packscript_argparse_need_fs_arg "$@"
   [ -f "${v0:?}" ] || argparse_die "${arg}: ${1} (${v0}) is not a file."
}

packscript_argparse_break() {
   return 0
}

# int packscript_check_target_name_valid ( name )
#
packscript_check_target_name_valid() {
   echo "${1}" | grep -qx -- '[_]*[a-zA-Z][a-zA-Z0_]*'
}

# void packscript_argparse_add_targets ( *names, **ARG_TARGETS ), raises die()
#
packscript_argparse_add_targets() {
   local target
   # unpack $@
   for target in ${*}; do
      if [ -z "${target}" ]; then
         true
      elif packscript_check_target_name_valid "${target}"; then
         ARG_TARGETS="${ARG_TARGETS-}${ARG_TARGETS:+ }${target}"
      else
         argparse_die "invalid target name '${target}'"
      fi
   done
}

packscript_argparse_arg() {
   case "${arg-}" in
      '')
         true
      ;;
      '-')
         local line=

         if tty -s; then
            ewarn "waiting for input from stdin (close with ^D or \"EOF\")"
         fi

         while read -r line && [ "${line}" != "EOF" ]; do
            packscript_argparse_add_targets ${line}
         done
      ;;
      *)
         packscript_argparse_add_targets ${arg}
      ;;
   esac
}

packscript_argparse_shortopt() {
   case "${shortopt}" in
      'f')
         packscript_argparse_need_file_arg "$@"
         newline_list_append ARG_RECIPES "${v0}"
      ;;
      'S')
         packscript_argparse_need_fs_arg "$@"
         ARG_ROOT_DIR="${v0}"
      ;;
      'I')
         packscript_argparse_need_fs_arg "$@"
         ARG_IMAGE_DIR="${v0}"
      ;;
      'l')
         ARG_COMMAND=list
      ;;
      'n')
         ARG_COMMAND=printcmd
      ;;
      '0')
         packscript_argparse_need_fs_arg "$@"
         if [ -e "${v0}" ] && [ ! -f "${v0}" ]; then
            argparse_die "${arg}: ${1} exists, but is not a file."
         fi
         ARG_OUTFILE="${v0}"
      ;;
      't')
         argparse_need_arg "$@"
         ARG_COMPRESSION_TAR="${1}"
      ;;
      's')
         argparse_need_arg "$@"
         ARG_COMPRESSION_SQUASHFS="${1}"
      ;;
      'C')
         argparse_need_arg "$@"
         ARG_COMPRESSION_TAR="${1}"
         ARG_COMPRESSION_SQUASHFS="${1}"
      ;;
      *)
         argparse_unknown
      ;;
   esac
}

packscript_argparse_longopt() {
   case "${longopt}" in
      'recipe')
         packscript_argparse_need_file_arg "$@"
         newline_list_append ARG_RECIPES "${v0}"
      ;;
      'root')
         packscript_argparse_need_fs_arg "$@"
         ARG_ROOT_DIR="${v0}"
      ;;
      'image-dir')
         packscript_argparse_need_fs_arg "$@"
         ARG_IMAGE_DIR="${v0}"
      ;;
      'command')
         argparse_need_arg "$@"
         if list_has "${1}" list image printenv printcmd genscript; then
            ARG_COMMAND="${1}"
         else
            argparse_die "${arg}: unknown command '${1}'."
         fi
      ;;
      'list'|'printenv'|'genscript')
         ARG_COMMAND="${longopt}"
      ;;
      'dry-run'|'printcmd')
         ARG_COMMAND=printcmd
      ;;
      'outfile')
         packscript_argparse_need_fs_arg "$@"
         if [ -e "${v0}" ] && [ ! -f "${v0}" ]; then
            argparse_die "${arg}: ${1} exists, but is not a file."
         fi
         ARG_OUTFILE="${v0}"
      ;;
      'overwrite')
         ARG_OVERWRITE=y
      ;;
      'no-overwrite')
         ARG_OVERWRITE=n
      ;;
      'compression')
         argparse_need_arg "$@"
         ARG_COMPRESSION_TAR="${1}"
         ARG_COMPRESSION_SQUASHFS="${1}"
      ;;
      'tarball-compression')
         argparse_need_arg "$@"
         ARG_COMPRESSION_TAR="${1}"
      ;;
      'squashfs-compression')
         argparse_need_arg "$@"
         ARG_COMPRESSION_SQUASHFS="${1}"
      ;;
      *)
         argparse_unknown
      ;;
   esac
}

# int packscript_check_targets ( **ARG_TARGETS, **PACK_TARGETS )
#
packscript_check_targets() {
   local tmiss=0
   local target
   for target in ${ARG_TARGETS-}; do
      if list_has "${target}" ${PACK_TARGETS-}; then
         true
      elif function_defined "pack_target_${target}"; then
         veinfo "hidden target requested: '${target}'"
      else
         ewarn "unknown target requested: '${target}'"
         tmiss=$(( ${tmiss} + 1 ))
      fi
   done
   [ ${tmiss} -lt 256 ] || return 255
   return ${tmiss}
}

# @private int packscript__run_pack_command(), raises die()
#
packscript__run_pack_command() {
   local v0=

   if [ "${PACKSCRIPT_PROTECT_VARS:-n}" = "y" ]; then
      for v0 in ${PACK_VARS} \
         PACK_TARGET_IN_SUBSHELL \
         PACKSCRIPT_PROTECT_VARS PACKSCRIPT_AS_LIB
      do
         case "${v0}" in
            PACK_TARGETS)
               true
            ;;
            *)
               eval "local ${v0}=\"\${${v0}-}\"" || die "failed to copy var"
            ;;
         esac
      done
      v0=
   fi

   veinfo "running additional checks for command='${ARG_COMMAND}'"

   if [ -z "${ARG_ROOT_DIR-}" ]; then
      eerror "${SCRIPT_NAME}: missing --root <dir> arg"
      return ${EX_USAGE}
   elif [ -z "${ARG_TARGETS-}" ]; then
      ewarn "no pack targets given"
      return ${EX_USAGE}
   fi

   veinfo "setting up packlib"
   # pack_setup ( root_dir, compression, image_dir, pack_command )
   autodie pack_setup "${ARG_ROOT_DIR}" \
      "${ARG_COMPRESSION_TAR} ${ARG_COMPRESSION_SQUASHFS}" \
      "${ARG_IMAGE_DIR-}" "${ARG_COMMAND}"
   PACK_OVERWRITE="${ARG_OVERWRITE:?}"

   veinfo "loading recipes"
   PACKSCRIPT_PRETEND=n
   packscript_load_recipes_from_list
   autodie packscript_check_targets

   if __debug__; then
      einfo "global pack env:"
      message_indent
      pack_printenv
      message_outdent
      echo
   fi

   pack_run_targets ${ARG_TARGETS}
}

# @pragma pack_pretend
#
#  Returns 0 if not actually packing (e.g. just listing targets),
#  else 1.
#
#  %PACKSCRIPT_PRETEND must be set prior to calling this function.
#
# Note: recipes should check for '! __pack_pretend__', which returns
#       true even if __pack_pretend__ is not defined (so that recipes do
#       depend on packlib and not this script).
#
__pack_pretend__() {
   [ "${PACKSCRIPT_PRETEND:?}" = "y" ]
}


# int packscript_main ( *args ), raises die()
#
packscript_main() {
   local __MESSAGE_INDENT="${__MESSAGE_INDENT-}"
   [ -n "${AUTODIE-}" ] || local AUTODIE=autodie
   local k

   local ARG_NUM_RECIPES=0
   local ARG_RECIPES=
   local ARG_TARGETS=
   local ARG_ROOT_DIR=
   local ARG_IMAGE_DIR=
   local ARG_COMMAND=
   local ARG_OUTFILE=
   local ARG_OVERWRITE=
   local ARG_COMPRESSION_TAR=
   local ARG_COMPRESSION_SQUASHFS=
   local PACKSCRIPT_PRETEND

## "protecting" PACK_TARGETS doesn't make much sense as the pack_target_*()
## functions exist anyway -- use a subshell for that (if desired)
##   if [ "${PACKSCRIPT_PROTECT_VARS:-n}" = "y" ]; then
##      local PACK_TARGETS="${PACK_TARGETS-}"
##   fi


   # parse args
   packscript_parse_args "$@"

   : ${ARG_COMMAND:=${PACKSCRIPT_DEFAULT_COMMAND:-image}}

   : ${ARG_COMPRESSION_TAR:=${PACKSCRIPT_DEFAULT_COMPRESSION_TAR:-default}}
   : ${ARG_COMPRESSION_SQUASHFS:=${PACKSCRIPT_DEFAULT_COMPRESSION_SQUASHFS:-default}}

   : ${ARG_OVERWRITE:=${PACK_OVERWRITE:-n}}


   # run command
   case "${ARG_COMMAND:?}" in
      'list')
         PACKSCRIPT_PRETEND=y
         packscript_load_recipes_from_list
         if [ -n "${PACK_TARGETS-}" ]; then
            einfo "pack targets:"
            message_indent
            for k in ${PACK_TARGETS}; do
               einfo "${k}" "-"
            done
            message_outdent
            return 0
         else
            ewarn "no pack targets available!"
            return 1
         fi
      ;;
      *)
         packscript__run_pack_command
      ;;
   esac
}
