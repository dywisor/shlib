#@section funcdef

# @funcdef shbool @intcheck [<condition>:=true] <function name> ( word )
#
#   Returns true if word is a number and condition(word) evaluates to true.
#


#@section functions

# @intcheck is_int()
is_int() {
   [ -n "${1-}" ] || return 1
   [ "${1}" -ge 0 2>/dev/null ] || [ "${1}" -lt 0 2>/dev/null ]
}

# @intcheck >=0 is_natural()
is_natural()  { [ -n "${1-}" ] && [ "${1}" -ge 0 2>/dev/null ]; }

# @intcheck >0 is_positive()
is_positive() { [ -n "${1-}" ] && [ "${1}" -gt 0 2>/dev/null ]; }

# @intcheck <0 is_negative()
is_negative() { [ -n "${1-}" ] && [ "${1}" -lt 0 2>/dev/null ]; }

# @intcheck uid is_uid()
#  where uid := { 0..(2^16 - 1) }
is_uid() { is_natural "$@" && [ ${1} -lt 65536 ]; }
