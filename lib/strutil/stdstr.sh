# @function_alias void str_trim() renames sed()
#
#  Removes whitespace at the beginning + end of a string
#  and replaces any whitespace sequence within the string
#  with a single space char.
#
str_trim() { sed -r -e 's,^\s+,,' -e 's,\s+$,,' -e 's,\s+, ,g' "$@"; }

# @function_alias void str_strip() renames sed()
#
#  Removes whitespace at the beginning + end of a string.
#
str_strip() { sed -r -e 's,^\s+,,' -e 's,\s+$,,' "$@"; }

# @function_alias void str_rstrip() renames sed()
#
#  Removes whitespace at the end of a string.
#
str_rstrip() { sed -r -e 's,\s+$,,' "$@"; }

# @function_alias void str_lstrip() renames sed()
#
#  Removes whitespace at the beginning of a string.
#
str_lstrip() { sed -r -e 's,^\s+,,' "$@"; }

# @function_alias str_field ( fieldspec, field_separator=" " ) renames cut()
str_field() {
   if [ $# -lt 3 ]; then
      cut -d "${2- }" -f "${1}"
   else
     local f="${1}" d="${2- }"
     shift 2
     cut -d "${d}" -f "${f}" "$@"
   fi
}

# ~int revrev ( *argv )
#
#  Reverse input, execute *argv, reverse again.
#
revrev() { rev | "$@" | rev; }

# ~int revcut ( *cut_argv )
#
#  Reverse input, cut and reverse again.
#
revcut() { rev | cut "$@" | rev; }

# @function_alias str_upper() renames tr()
str_upper() { tr [:lower:] [:upper:] "$@"; }

# @function_alias str_lower() renames tr()
str_lower() { tr [:upper:] [:lower:] "$@"; }


# void str_remove_trailing_chars ( str, chars, **v0! )
#
str_remove_trailing_chars() {
   : ${2:?}
   v0="${1?}"
   local a="${v0%[${2}]}"

   while [ "${a}" != "${v0}" ]; do
      v0="${a%[${2}]}"
      a="${v0%[${2}]}"
   done
}

# void str_remove_leading_chars ( str, chars, **v0! )
#
str_remove_leading_chars() {
   : ${2:?}
   v0="${1?}"
   local a="${v0#[${2}]}"

   while [ "${a}" != "${v0}" ]; do
      v0="${a#[${2}]}"
      a="${v0#[${2}]}"
   done
}
