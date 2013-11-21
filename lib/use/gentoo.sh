#@section header
## The functions provided by this module are "more or less" compatible with
## the ones listed in Gentoo's Package Manager Specification (EAPI 5),
## which can be found at http://www.gentoo.org/proj/en/qa/pms.xml

#@section functions_export
# @extern int use ( *flag, **USE_PREFIX= )


#@section functions

# void usex (
#    flag,
#    yes_value="yes", no_value="no",
#    yes_value_append="", no_value_append=""
# )
#
# Echoes <yes_value><yes_value_append> if the the given USE flag is enabled,
# else echoes <no_value><no_value_append>.
#
usex() {
   if use "${1:?}"; then
      echo "${2-yes}${4-}"
   else
      echo "${3-no}${5-}"
   fi
}

# void use_with ( flag, configure_option=<flag>, [configure_value] )
#
#  Echoes
#  * "--with-<configure_option>=<configure_value>"
#    if flag is enabled and configure_value is set
#  * "--with-<configure_option>"
#    if flag is enabled and configure_value is unset
#  * "--without-<configure_option>"
#    if flag is disabled
#
use_with() {
   usex "${1}" "--with-" "--without-" "${2:-${1}}${3+=}${3-}" "${2:-${1}}"
}

# void use_enable ( flag, configure_option=<flag>, [configure_value] )
#
#  Same as use_with(...), but passes enable/disable instead of with/without.
#
use_enable() {
   usex "${1}" "--enable-" "--disable-" "${2:-${1}}${3+=}${3-}" "${2:-${1}}"
}

#@section module_init_vars
# @implicit void main ( **__USE_FUNCTIONS )
#
#  Adds the functions provided by this module to the __USE_FUNCTIONS variable.
#
__USE_FUNCTIONS="${__USE_FUNCTIONS-} usex use_with use_enable"
