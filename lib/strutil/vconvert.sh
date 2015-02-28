#@section functions

upstr() {
   v0_strfeed_cmd "${1?}" str_upper
}

lowstr() {
   v0_strfeed_cmd "${1?}" str_lower
}
