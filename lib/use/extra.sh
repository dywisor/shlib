#@section functions_export

# @extern int use          ( *flag, **USE_PREFIX= )
# @extern int use_any      ( *flag, **USE_PREFIX= )
# @extern int use_call     ( flag, *cmdv, **USE_PREFIX= )
# @extern void disable_use ( *flag, **USE_PREFIX= )
# @extern void enable_use  ( *flag, **USE_PREFIX= )
# @extern void eval_use_functions (...)

# @extern void usex (...)
# @extern void use_with   ( flag, configure_option=<flag>, [configure_value] )
# @extern void use_enable ( flag, configure_option=<flag>, [configure_value] )

#@section functions

# void use_option ( flag, option_name=<flag>, [option_value] )
#
#  Same as use_with(), but passes --<option>[=<value>] / --no-<option>.
#
use_option() {
   usex "${1}" "--" "--no-" "${2:-${1}}${3+=}${3-}" "${2:-${1}}"
}


#@section module_init_vars
__USE_FUNCTIONS="${__USE_FUNCTIONS-} use_option"
