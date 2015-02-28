#@section functions

upstr() {
   : ${1:?}; v0="${1^^}"
}

lowstr() {
   : ${1:?}; v0="${1,,}"
}
