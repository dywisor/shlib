# TODO: --machine(-M), --read-only options; systemd_nspawn_boot()

#@section functions

# int systemd_nspawn_prepare_cmd (
#    list_names, *args, **X_SYSTEMD_NSPAWN!, **v0!
# )
#
#  Ensures that %X_SYSTEMD_NSPAWN is set and an absolute path and
#  constructs the systemd-nspawn args (stored in %v0),
#  which can later be used with systemd_nspawn_call_forged(<func>).
#
systemd_nspawn_prepare_cmd() {
   v0=
   get_systemd_nspawn_exe || return 99
   systemd_nspawn_forge_call_args "${@}"
}

# @private int systemd_nspawn__run (
#    *args, **X_SYSTEMD_NSPAWN?, **SYSTEMD_NSPAWN_ROOT?
# )
#
#  Actually runs systemd-nspawn with the given args
#  in %SYSTEMD_NSPAWN_ROOT_DIR or %SYSTEMD_NSPAWN_ROOT_IMAGE.
#
#  Do not run this function directly unless absolutely sure,
#  use systemd_nspawn() instead, which adds bind-mount/network/... args
#  to the systemd-nspawn call.
#
systemd_nspawn__run() {
   local root_opt root_val
   systemd_nspawn_get_root_opt && \
   echo CMD ${X_SYSTEMD_NSPAWN:?} ${root_opt:?} "${root_val:?}" "${@}"
}

# int systemd_nspawn_call ( func, list_names:="all", *args )
#
#  Ensures that %X_SYSTEMD_NSPAWN is set and
#  calls %func ( *<forged list args>, *args ) afterwards.
#
#  Returns 99 if %X_SYSTEMD_NSPAWN could not be found, else passes
#  the function's return value.
#
systemd_nspawn_call() {
   local v0 __func
   __func="${1:?}"; shift

   systemd_nspawn_prepare_cmd "${@}" && \
   systemd_nspawn_call_forged "${__func:?}"
}

# int systemd_nspawn ( list_names:="all", *args )
#
#  Constructs a systemd-nspawn command and runs it.
#
systemd_nspawn() {
   systemd_nspawn_call systemd_nspawn__run "${@}"
}


# int systemd_nspawn_generate_service_unit (
#    outfile, list_names:="all", *args,
#    **SYSTEMD_NSPAWN_ROOT??, **SYSTEMD_NSPAWN_ROOT_IMAGE??
# )
#
systemd_nspawn_generate_service_unit() {
   local systemd_nspawn_unit_file

   systemd_nspawn_unit_file="${1:?}"; shift
   systemd_nspawn_call systemd_nspawn__generate_service_unit "${@}"
}

# @stdout @private int systemd_nspawn__generate_print_service_unit ( ... )
#
#  Prints a .service unit file to stdout.
#
systemd_nspawn__generate_print_service_unit() {
   local root_opt root_val
   systemd_nspawn_get_root_opt || return
   : ${root_opt:?} ${root_val:?}

   # FIXME: make this configurable

cat << END_OF_UNIT
[Unit]
Description=${root_val##*/} container
After=local-fs.target
After=network.target

[Service]
ExecStart=${X_SYSTEMD_NSPAWN:?} ${root_opt} ${root_val}${*:+ ${*}}
KillMode=process

[Install]
WantedBy=multi-user.target
END_OF_UNIT
}

# @private int systemd_nspawn__generate_service_unit()
#
#  Writes a .service unit file to %systemd_nspawn_unit_file.
#
systemd_nspawn__generate_service_unit() {
   case "${systemd_nspawn_unit_file:?}" in
      '-')
         systemd_nspawn__generate_print_service_unit "${@}"
      ;;
      *)
         systemd_nspawn__generate_print_service_unit "${@}" \
            > "${systemd_nspawn_unit_file}"
      ;;
   esac
}
