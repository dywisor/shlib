#@section header
# ----------------------------------------------------------------------------
#
# This module provides functions for dealing with scripts, particularly
# shell scripts. Currently implements hashbang checking and editing of
# shell variables.
#
# functions quickref:
#
# int edit_shell_var()          -- varname, new_value=, shell_file=
# int is_shell_file()           -- file
# int is_bash_file()            -- file
# int file_has_hashbang         -- file, pattern=
# int file_has_shebang          -- file, pattern=
# int edit_shell_vars_in_file() -- file, *vardef
#
# ----------------------------------------------------------------------------


#@section functions

# @private int sh_edit__check_vardefs ( *vardef )
#
#  Validates zero or more vardefs, which are <varname>=[<value>] pairs.
#  The varname itself is not checked for correctness.
#
#  Returns the number of invalid vardefs. The varname itself is not checked.
#
#  Important:
#   Due to technical limitations (return code of 256 is equivalent to 0),
#   this function returns 255 even if more vardefs are invalid.
#   Unlikely case, but should be noted.
#
sh_edit__check_vardefs() {
   local vardef
   local fail=0
   for vardef; do
      case "${vardef}" in
         ?*=*)
            true
         ;;
         *)
            if [ "${HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
               eerror "bad vardef: ${vardef}"
            else
               echo "bad vardef: ${vardef}" 1>&2
            fi
            fail=$(( ${fail} + 1 ))
         ;;
      esac
   done
   if [ ${fail} -gt 255 ]; then
      return 255
   else
      return ${fail}
   fi
}

# @private void sh_edit__get_shell_var_regex (
#    varname, new_value, add_comment, re_old_value:=".*?", **v0!,
#    **SH_EDIT_SED_SEP="@"
# )
#
# See edit_shell_var().
#
# %SH_EDIT_SED_SEP must not be set to '|'.
#
sh_edit__get_shell_var_regex() {
   v0=
   local re_old_value="${4:-.*?}"
   # COULDFIX: also edits var="...' statements (but this should
   #            be a minor issue)
   #  => use a more unambiguous regex if required
   #
   # regex groups:
   # 1: keyword    -- "readonly", "declare" or empty (whitespace preserved)
   # 2: varname    -- "varname="
   # 3: quote char -- ", ' or empty (discarded; " is used as quote char)
   # 4: old value  --
   # 5: quote char -- see 3
   # 6: remainder  -- only whitespace and end-of-line comments allowed (will be discarded)
   #
   local match_expr="^(\s*readonly\s*|\s*declare\s*|\s*)(${1:?}=)\
([\'\"])?(${re_old_value}[^\'\"])?([\'\"]|)(\s*|\s*#.+)$"

   local repl="\1\2\"${2?}\""
   [ -z "${3-}" ] || repl="${repl} # edited: was \"\4\""

   local sep="${SH_EDIT_SED_SEP:-@}"

   v0="s${sep}${match_expr}${sep}${repl}${sep}"
}

# @private int sh_edit__has_hashbang ( file, pattern=, **v0! )
#
#  Returns 0 if %file's first line is a shebang/hashbang matching %pattern,
#  1 if not (but has a hashbang), 2 if unknown (no hashbang) and
#  3 if undefined (%file not given, does not exist, is not readable).
#
#  Also stores the hashbang in %v0 for later usage.
#  %pattern should not include the starting '#!'.
#
sh_edit__has_hashbang() {
   v0=
   [ -n "${1-}" ] && [ -f "${1-}" ] || return 3
   local hashbang
   read -r hashbang < "${1?}" || return 3
   case ${hashbang} in
      '#!'*"${2-}"*)
         v0="${hashbang}"
         return 0
      ;;
      '#!'*)
         v0="${hashbang}"
         return 1
      ;;
      *)
         return 2
      ;;
   esac
}


#@section functions

# int edit_shell_var (
#    varname, new_value=, shell_file=, add_comment=, re_old_value:=<default>
# )
#
#  Edits variable declarations in shell (bash/dash) files (including
#  readonly vars), or stdin (if %shell_file is empty).
#  This function has some restrictions, most notably it expects that
#  only one variable is defined per line.
#
#  Adds "# edited: was <old_value>" to the end of each edited line if
#  %add_comment is non-zero.
#
#  Only edits appearances of %varname whose (old) values match %re_old_value.
#
#  Returns sed's exit code or %EX_USAGE (= not enough args).
#
edit_shell_var() {
   [ $# -ge 2 ] && [ -n "${1-}" ] || return ${EX_USAGE}
   local v0
   sh_edit__get_shell_var_regex "${1}" "${2-}" "${4-}" "${5-}"
   if [ -n "${3-}" ]; then
      sed -r -e "${v0}" -i "${3}"
   else
      sed -r -e "${v0}"
   fi
}

# int is_shell_file ( file )
#
#  Returns 0 if %file is a shell file, else non-zero.
#
is_shell_file() {
   local v0
   sh_edit__has_hashbang "${1-}" "sh"
}

# int is_bash_file ( file )
#
#  Returns 0 if %file is a bash file, else non-zero.
#
is_bash_file() {
   local v0
   sh_edit__has_hashbang "${1-}" "bash"
}

# int file_has_hashbang ( file, pattern= )
#
#  Returns 0 if %file has a hashbang with the given pattern
#  (or _any_ hashbang if pattern is empty), else non-zero.
#
file_has_hashbang() {
   local v0
   sh_edit__has_hashbang "$@"
}

# @function_alias file_has_shebang() copies file_has_hashbang()
#
#  I prefer to call it hashbang, others don't.
#
file_has_shebang() {
   local v0
   sh_edit__has_hashbang "$@"
}

# int edit_shell_vars_in_file (
#    file, *vardef,
#    **SHEDIT_ADD_COMMENT=, **SHEDIT_RE_OLD_VALUE=<default>,
#    **SHEDIT_CHECK_VARDEF=y
# ), raises die()
#
#  Edits zero or more shell variables in %file.
#  Variable definitions have to be given in <varname>=[<value>] form.
#
#  vardefs will be checked prior to editing if %SHEDIT_CHECK_VARDEF
#  is set to 'y', which causes the script to die if the check fails.
#
#  Returns 2 if no file given or file does not exist,
#  otherwise immediately returns the first non-zero return code
#  of edit_shell_var() (which means that editing failed).
#  A return code of zero indicates success or no vardef given.
#
#  %SHEDIT_ADD_COMMENT and %SHEDIT_RE_OLD_VALUE are passed to
#  edit_shell_var() as parameters.
#
edit_shell_vars_in_file() {
   [ -n "${1-}" ] && [ -f "${1-}" ] || return 2
   local file="${1}"
   shift

   if [ "${SHEDIT_CHECK_VARDEF:-y}" = "y" ]; then
      sh_edit__check_vardefs "$@" || \
         die \
            "edit_shell_vars_in_file( ${file}, $* ): ${?} out of ${#} vardefs are not valid." \
            "${EX_USAGE}"
   fi

   local vardef
   for vardef; do
      edit_shell_var \
         "${vardef%%=*}" "${vardef#*=}" "" \
         "${SHEDIT_ADD_COMMENT-}" "${SHEDIT_RE_OLD_VALUE-}" || return
   done
}
