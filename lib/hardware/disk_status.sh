#@section functions

# @stdout int print_disk_status ( dev, **DEVNULL )
#
#  Runs a hdparm command that prints dev's status to stdout.
#
print_disk_status() {
   LC_ALL=C LANG=C hdparm -C "${1:?}" 2>${DEVNULL?} | \
      str_trim | grep ^'drive state is: ' | str_field 4
}

# shbool get_disk_status ( dev, **v0! )
#
#  Stores dev's status in v0. Returns true if the status is neither empty
#  nor "unknown".
#
get_disk_status() {
   v0=$(print_disk_status "${1}")
   [ -n "${v0}" ] && [ "${v0}" != "unknown" ]
}

# shbool disk_is_active ( dev, **v0! )
#
#  Returns true if dev is "active/idle", else false. (Also sets v0.)
#
disk_is_active() {
   get_disk_status "$@" && [ "${v0}" = "active/idle" ]
}
