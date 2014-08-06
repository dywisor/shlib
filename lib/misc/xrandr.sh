#@section vars
XRANDR_OUTPUT_TYPES="VGA|DP|HDMI|LVDS|TV|TMDS"
XRANDR_ROTATION_MODES="normal|left|inverted|right"

XRANDR_QUERY_COMMAND="--current"


#@section functions

# @private int xrandr__build_parse_regex (
#    **XRANDR_OUTPUT_TYPES, **XRANDR_ROTATION_MODES, **v0!
# )
#
#  Creates the sed regex for parsing xrandr output and stores it in %v0.
#
xrandr__build_parse_regex() {
   v0=
   [ -n "${XRANDR_OUTPUT_TYPES-}"   ] || return 1
   [ -n "${XRANDR_ROTATION_MODES-}" ] || return 2

   # regex groups
   #  1 output name
   #  2 output type
   #  3 resolution
   #  4 offset
   #  5 rotation w/ leading whitespace
   #  6 rotation w/o ^

   local re_match=

   # 1,2: name/type
   re_match="((${XRANDR_OUTPUT_TYPES})[-]?[0-9]+)"

   # restrict regex to connected outputs
   # 3: primary _suffixed_ with whitespace (optional)
   re_match="${re_match}\s+connected\s+(primary\s+)?"

   # 4: resolution
   re_match="${re_match}([0-9]+[x][0-9]+)"

   # 5: offset
   re_match="${re_match}([+-][0-9]+[+-][0-9]+)"

   # 6, 7: rotation [optional]
   re_match="${re_match}(\s+(${XRANDR_ROTATION_MODES}))?\s+"

   # remainder and ^/$
   re_match="^${re_match}.*\$"

   v0="${re_match}"
}

# int xrandr_get_parse_regex ( **__XRANDR_PARSE_REGEX=!, **v0! )
#
#  Stores the xrandr parse regex in %v0.
#  Uses __XRANDR_PARSE_REGEX for caching the regex so it doesn't need to
#  be created more than once.
#
xrandr_get_parse_regex() {
   v0="${__XRANDR_PARSE_REGEX-}"
   if [ -z "${v0}" ]; then
      xrandr__build_parse_regex || return
      __XRANDR_PARSE_REGEX="${v0:?}"
   fi
   return 0
}

# void xrandr_clear_parse_regex ( **__XRANDR_PARSE_REGEX! )
#
#  Unsets the cached parse regex (by setting it to "").
#
xrandr_clear_parse_regex() {
   __XRANDR_PARSE_REGEX=
}

# @stdout int xrandr_parse_stdout (
#    **XRANDR="xrandr", **XRANDR_QUERY_COMMAND="--current"
# )
#
#   Runs xrandr --query|--current (%XRANDR %XRANDR_QUERY_COMMAND)
#   and parses the output.
#   Writes the resulting text lines to stdout (one per output).
#
#   format:
#    <output type> <output name> <resolution> <offset> [<rotation>][<primary>]
#
xrandr_parse_stdout() {
   local v0
   xrandr_get_parse_regex || return
   # <type> <name> <res> <offset>[ <rotation>] [<primary> ]
   [ -n "$*" ] || set -- "\2 \1 \4 \5\6 \3"
   ${X_XRANDR:-xrandr} ${XRANDR_QUERY_COMMAND:---current} | \
      sed -nr "s@${v0}@${*}@p"
}

# @stdout void xrandr_dump_parsed ( **output_ )
#
#  Prints the parsed output variables (%output_*).
#
xrandr_dump_parsed() {
   local iter
   for iter in \
      "output_name=${output_name?}" \
      "output_type=${output_type?}" \
      "output_resolution=${output_resolution?}" \
      "output_offset=${output_offset?}" \
      "output_rotation=${output_rotation?}" \
      "output_primary=${output_primary?}"
   do
      echo "${iter}"
   done
}

# ~int xrandr_parse_restrict_to_primary (
#    func, *args, **output_primary
# )
#
#  Runs %func(*args) if %output_primary is "y", else returns 0.
#
xrandr_parse_restrict_to_primary() {
   [ "${output_primary:?}" = "y" ] || return 0
   "${@}"
}

# @private int xrandr_parse__dispatch (
#    *data, **F_XRANDR_PARSE_DISPATCH_FUNC
# )
#
#  Splits %data into %output_ variables(1) and calls
#    %F_XRANDR_PARSE_DISPATCH_FUNC[0] (
#       *%F_XRANDR_PARSE_DISPATCH_FUNC[1:], %output_name
#    )
#
#  Returns non-zero if data splitting failed, else passes the function's
#  return value.
#
#  (1) output variables
#  * output_name       - mandatory - <name> ("HDMI3")
#  * output_type       - mandatory - see %XRANDR_OUTPUT_TYPES ("HDMI")
#  * output_resolution - optional  - <width>x<height> ("1680x1050")
#  * output_offset     - optional  - [+-]<width>[+-]<height> ("+1200+0")
#  * output_rotation   - optional  - see %XRANDR_ROTATION_MODES ("")
#  * output_primary    - optional  - "y"|"n"
#
xrandr_parse__dispatch() {
   local \
      output_name= \
      output_type= \
      output_resolution= \
      output_offset= \
      output_rotation= \
      output_primary=n

   output_name="${1}"
   output_type="${2}"
   shift 2 || return



   if [ -n "${1+SET}" ]; then
      output_resolution="${1}"; shift
   fi

   if [ -n "${1+SET}" ]; then
      output_offset="${1}"; shift
   fi

   if [ -n "${2+SET}" ]; then
      output_rotation="${1}"
      output_primary="${2}"
      shift 2

   elif [ -n "${1+SET}" ]; then
      case "${1}" in
         'primary')
            output_primary=y
            xrandr_have_primary=y
         ;;
         *)
            output_rotation="${1}"
         ;;
      esac
      shift
   fi

   ${F_XRANDR_PARSE_DISPATCH_FUNC:?} "${output_name}"
}

# xrandr_parse ( func, *args, **xrandr_have_primary! )
#
#  Parses xrandr's output and calls %func ( *args, %output_name ) for
#  each output (display/monitor/...).
#
#  Returns on first failure of a %func() call.
#
#  Returns 3 if xrandr_parse_stdout() failed and 4 if no outputs were detected.
#
#  Sets to xrandr_have_primary to "y" or "n", depending on whether a
#  primary output was found.
#
#  Note:
#     %xrandr_have_primary=="n" after successfully calling this function
#     (i.e. return value == 0) is most likely a BUG.
#
#
xrandr_parse() {
   xrandr_have_primary=n

   local F_XRANDR_PARSE_DISPATCH_FUNC="${*?}"
   : ${F_XRANDR_PARSE_DISPATCH_FUNC:-:}
   local data
   set --


   data="$(xrandr_parse_stdout)"
   [ ${?} -eq 0 ] || return 3

   local IFS="${IFS_NEWLINE?}"
   set -- ${data}
   IFS="${IFS_DEFAULT?}"

   [ ${#} -gt 0 ] || return 4

   while [ ${#} -gt 0 ]; do
      xrandr_parse__dispatch ${1} || return
      shift
   done
}
