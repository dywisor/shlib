#@section functions

try_chdir() {
   cd ${CHDIR_OPTS--P} "${1}"
}

chdir() {
   cd ${CHDIR_OPTS--P} "${1}" || die "chdir ${1} failed."
}
