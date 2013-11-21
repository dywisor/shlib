#@section functions

# void EXPORT_FUNCTIONS ( *function_name )
#
#  Marks one or more functions as installable.
#
EXPORT_FUNCTIONS() {
   __EXPORT_FUNCTIONS="${__EXPORT_FUNCTIONS-}${__EXPORT_FUNCTIONS:+ }$*"
}
