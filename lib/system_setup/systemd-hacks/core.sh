#@HEADER
#  module for setting up systemd in %TARGET_ROOT (usually not "/")
#
# list of functions:
#  grep -hEo -- '^systemd_hacks_[a-zA-Z_0-9]+' systemd-hacks-functions.sh | sort
systemd_hacks_print_function_help() {
cat << EOF
# systemd_hacks_declare_function_alias(...)
#
#  Internal helper function for function alias creation.
#
#
# systemd_hacks_disable_all_units()
#
#  Removes all units from all targets (%SYSTEMD_LIBDIR/system/*.target.*/.)
#
#
# systemd_hacks_disable_unit ( unit, [target:=<default>] )
#
#  Removes a unit from the given target or the default one.
#  (%SYSTEMD_HACKS_DEFAULT_TARGET)
#
#
# systemd_hacks_disable_units ( *unit )
#
#  Removes several units from the default target.
#
#
# systemd_hacks_disable_units_linking_to ( link_dest_patterns, [target:=<any>] )
#
#  Disables units matching any of %link_dest_patterns in the given target
#  or all targets, if unspecified.
#
#  Example:
#    Disable units whose name starts with avahi or mdns (in all targets):
#      systemd_hacks_disable_units_linking_to "avahi*.* mdns*.*"
#
#    Disable all units linked to %SYSTEMD_CONFDIR
#      systemd_hacks_disable_units_linking_to "\${SYSTEMD_CONFDIR%/}/system/*.*"
#
#
# systemd_hacks_enable_matching_units ( unit_patterns, [target:=<default>] )
#
#  Adds matching units from %SYSTEMD_CONFDIR and %SYSTEMD_LIBDIR to
#  the given target (or the default one).
#
#  Example:
#    Enable avahi services/sockets:
#      systemd_hacks_enable_matching_units "avahi*.service avahi*.socket"
#
#
# systemd_hacks_enable_single_unit ( unit, [target:=<default>] )
#
#  Adds the given unit (name) to a target.
#  The unit file has to exist!
#
#  Example:
#    Enable systemd-networkd.service:
#      systemd_hacks_enable_single_unit systemd-networkd.service
#
#
# systemd_hacks_enable_unit ( var_arg, [target:=<default>] )
#
#  Wrapper function that calls systemd_hacks_enable_matching_units()
#  if the var_arg contains wildcard characters ("?*"),
#  and systemd_hacks_enable_single_unit() otherwise.
#
#
# systemd_hacks_enable_units ( *var_arg )
#
#  Calls systemd_hacks_enable_unit ( arg, <default target> )
#  for each arg in the given list.
#
#
# systemd_hacks_install_unit ( unit_src, [unit_dst] )
#
#  Installs a unit file.
#  The installation path depends on the unit_dst arg (which defaults to
#  the basename of unit_src), but in most cases it is
#  %SYSTEMD_LIBDIR/system/%unit_dst.
#
#  Removes the unit file from both %SYSTEMD_LIBDIR and %SYSTEMD_CONFDIR
#  before installation.
#  COULDFIX: add %SYSTEMD_HACKS_INSTALL_REMOVES_CONFDIR_FILE
#
#  Example:
#    Install rc-local.service file to %SYSTEMD_LIBDIR:
#      systemd_hacks_install_unit /path/to/rc-local.service rc-local.service
#
#    Install rc-local.service file to %SYSTEMD_LIBDIR (full path)
#      systemd_hacks_install_unit \\
#         /path/to/rc-local.service \\
#         /usr/lib/systemd/system/rc-local.service
#
#    This works even if %SYSTEMD_LIBDIR is set to /lib/systemd (and vice versa).
#    The function will print a warning ("path fixup") and chage the path
#    accordingly.
#
#
# systemd_hacks_mask_matching_units ( unit_patterns )
#
#  Masks units from %SYSTEMD_LIBDIR that match any of the given patterns.
#  (mask := create symlink to /dev/null in %SYSTEMD_CONFDIR/system/)
#
#
# systemd_hacks_mask_units ( *unit )
#
#  Masks all listed units.
#  Set SYSTEMD_HACKS_MASK_PHANTOMS=y if want to mask non-existent services.
#
#
# systemd_hacks_move_units_to_libdir ( [unit_patterns:=<match all>] )
#
#   If called without args, moves all unit files from %SYSTEMD_CONFDIR
#   to %SYSTEMD_LIBDIR and fixes up symlinks to the units.
#
#   If called with %unit_patterns, moves all unit files matching any of the
#   given patterns and fixes up symlinks to these units.
#
#
# systemd_hacks_print_function_help()
#
#  This function.
#
#
# systemd_hacks_remove_unit ( unit_patterns )
#
#  Removes unit files matching any of the given patterns from both
#  %SYSTEMD_CONFDIR and %SYSTEMD_LIBDIR.
#
#  Does not removes links to the removed file,
#  use systemd_hacks_uninstall_unit() instead.
#
#
# systemd_hacks_replace_unit ( unit_src, [unit_dst] )
#
#  Similar to systemd_hacks_install_unit(), but fixes up symlinks.
#
#
# systemd_hacks_search_config_units ( unit_patterns, function, *args )
#
#  Calls function ( *args, <unit file relpath> ) for each unit file
#  in %SYSTEMD_CONFDIR that matches any of the given patterns.
#
#
# systemd_hacks_search_system_units ( unit_patterns, function, *args )
#
#  Calls function ( *args, <unit file relpath> ) for each unit file
#  in %SYSTEMD_CONFDIR that matches any of the given patterns.
#
#
# systemd_hacks_search_target_dirs (
#    unit_patterns, target_dir_pattern:=<default>, function, *args
# )
#
#  Calls function ( *args, unit_file_relpath ) for each unit symlink
#  in %SYSTEMD_CONFDIR that matches both the target dir pattern and
#  any of the unit patterns.
#
#  Mainly a helper function, used by the disable() functions, for example.
#
#  Example:
#    Call function("dumps",unit_file_relpath) for all unit files in
#    %SYSTEMD_CONFDIR/system/multi-user.target.??* that begin with an "a":
#      systemd_hacks_search_target_dirs "a*" "multi-user" dumps
#
#    Same as the above, but match "*.target.wants":
#      systemd_hacks_search_target_dirs "a*" "*.target.wants" dumps
#
#
# systemd_hacks_search_target_dirs_all (
#    target_dir_pattern:=<default>, function, *args
# )
#
#  Calls function ( *args, unit_file_relpath ) for each unit symlink
#  in %SYSTEMD_CONFDIR that matches the target dir pattern.
#
#  Base function for systemd_hacks_search_target_dirs(),
#  systemd_hacks_search_target_dirs_linking_to().
#
#
# systemd_hacks_search_target_dirs_linking_to (
#    link_dest_patterns, target_dir_pattern:=<default>,
#    function, *args
# )
#
#  Calls function ( *args, unit_file_relpath ) for each unit symlink
#  in %SYSTEMD_CONFDIR that matches the target dir pattern and links
#  to any of the given link destinations (wildcard-matched).
#
#  Example:
#    Call function("dumps",unit_file_relpath) for all unit files in
#    %SYSTEMD_CONFDIR/system/"*.target.??*" that link to anything starting
#    with an "a" or to %SYSTEMD_CONFDIR/system:
#      systemd_hacks_search_target_dirs_linking_to \\
#         "a* \${SYSTEMD_CONFDIR%/}/system/*" '*' dumps
#
#
# systemd_hacks_uninstall_unit ( unit_patterns )
#
#  Removes all unit files matching any of the given patterns and
#  deletes symlinks from target dirs it.
#
#  This is what you should call for removing files, e.g.:
#    systemd_hacks_uninstall_unit avahi-daemon
#  or:
#    systemd_hacks_uninstall_unit 'avahi*'
#
#
#
# A few cmdline helper functions exist:
#
# filters ( unit_name_to_match, function, *args )
#
#  Calls function(*args) IFF the unit name matches %unit_name_to_match.
#
#
# dumps ( [function, *args], unit_relpath )
#
#  A pass-through filter function.
#  Dumps all unit-file related variables to stdout and calls
#  function(*args,unit_relpath) afterwards if a function was given.
#
#
EOF
}

#@section vars

# this module takes over the mainscript namespace
case "${MAINSCRIPT_NAMESPACE-}" in
   ''|'mainscript')
      MAINSCRIPT_NAMESPACE=systemd_hacks
   ;;
esac

#@section functions


systemd_hacks_declare_function_alias() {
   mainscript_declare_function_alias "$@"
}

# shorthands for cmdline usage
dumps() {
   dump_unit_vars

   if [ $# -gt 1 ]; then
      "$@" || return ${?}
   fi

   return 0
}

filters() {
   if_fnmatch_unit_do "$@"
}

__systemd_hacks_print_action_info() {
   einfo "${*}"
}

__systemd_hacks_print_action_warn() {
   ewarn "${*}"
}

__systemd_hacks_print_action_err() {
   eerror "${*}"
}


__systemd_hacks_disable_unit() {
   __systemd_hacks_print_action_info \
      "removing ${unit_suffix#.} ${unit_basename}" \
      "from target ${target} [.${target_dir##*/*.target.}]"

   remove_file "${unit_link:?}"
}

__systemd_hacks_default_enable_unit_intercept() {
   local patterns p

   patterns=
   for p in sleep sysinit shutdown; do
      [ "${target}" = "${p}" ] || patterns="${patterns} *-${p}"
   done
   patterns="${patterns# }"


   if fnmatch_in_any "${unit_basename}" "${patterns}"; then
      __systemd_hacks_print_action_warn \
         "name of ${unit_suffix#.} ${unit_basename} indicates" \
         "that it belongs to a specific target != ${target}"
      return 25
   fi
}

__systemd_hacks_filter_unit_linking_to() {
   if fnmatch_in_any "${unit_file_name:?}" \
      "${__unit_linking_to_name_patterns?}"
   then
      return 0

   elif fnmatch_in_any "${unit_file_relpath:?}" \
      "${__unit_linking_to_path_patterns?}"
   then
      return 0
   fi


   return 5
}

__systemd_hacks_replace_unit_symlink() {
   autodie remove_file "${unit_file}"
   autodie create_symlink "${1:?}" "${unit_file}"
}

__systemd_hacks_remove_unit_file() {
   if test_fs_exists "${unit_file}"; then
      __systemd_hacks_print_action_info \
         "removing ${unit_suffix#.} file ${unit_file_relpath}"

      autodie remove_file "${unit_file}"
   fi
}

__systemd_hacks_filter_unit_linking_to_do() {
   __systemd_hacks_filter_unit_linking_to || return 0
   "$@"
}

__systemd_hacks_enable_unit() {
   if test_fs_exists "${unit_file}"; then
      autodie remove_file "${unit_file}"
   fi

   autodie create_symlink \
      "${unit_file_relpath}" "${target_dir}/${unit_name}"
}

__systemd_hacks_enable_matching_unit() {
   target_dir="${__unit_enable_target_dir:?}"
   target="${__unit_enable_target_dir##*/}"
   target="${target%.target.*}"

   if [ -n "${unit_template_name}" ]; then
      __systemd_hacks_print_action_info \
         "not activating ${unit_suffix#.} template ${unit_basename}"

      return 0
   fi

   if __systemd_hacks_default_enable_unit_intercept; then
      __systemd_hacks_enable_unit "${1:?}"
   else
      __systemd_hacks_print_action_warn \
         "refusing to add ${unit_suffix#.} ${unit_basename} to ${target}"
   fi
}

__systemd_hacks_enable_matching_confdir_unit() {
   __systemd_hacks_enable_matching_unit confdir
}

__systemd_hacks_enable_matching_libdir_unit() {
   local confdir confdir_root
   get_systemd_confdir "system/${unit_name}"

   if test_fs_exists "${confdir}"; then
      __systemd_hacks_print_action_info \
         "skipping activation of ${unit_suffix#.} ${unit_basename}:" \
         "will use confdir file later on"

      return 0
   fi

   __systemd_hacks_enable_matching_unit libdir
}



__systemd_hacks_resolve_unit_destfile_path() {
   zap_unit_vars

   local confdir_root confdir libdir_root libdir confdir_rel libdir_rel
   get_systemd_confdir system
   get_systemd_libdir  system
   confdir_rel="${confdir#${TARGET_DIR%/}}"
   libdir_rel="${libdir#${TARGET_DIR%/}}"


   case "${1-}" in
      '')
         die "cannot resolve unit destfile path: empty arg."
      ;;

      "${confdir}/"*/*|"${libdir}/"*/*|\
      "${confdir_rel}/"*/*|"${libdir_rel}/"*/*|\
      "/lib/systemd/system/"*/*|"/usr/lib/systemd/system/"*/*)
         die "invalid unit destfile path: ${1} (subdir in system/)"
      ;;

      "${confdir}/"?*)
         unit_file="${1}"
      ;;

      "${libdir}/"?*)
         unit_file="${1}"
      ;;

      "${confdir_rel}/"?*)
         unit_file_relpath="${1}"
      ;;

      "${libdir_rel}/"?*)
         unit_file_relpath="${1}"
      ;;

      "/lib/systemd/"?*|"/usr/lib/systemd/"?*)
         __systemd_hacks_print_action_warn \
            "path fixup ${1%%/systemd/*}/systemd -> ${SYSTEMD_LIBDIR%/}"

         unit_file_relpath="${SYSTEMD_LIBDIR%/}/system/${1##*/}"
      ;;

      */*)
         die "invalid unit destfile path: ${1} (not in system/)"
      ;;

      *.*)
         unit_file="${libdir}/${1}"
      ;;

      *)
         if [ -n "${2-}" ]; then
            local suffix
            suffix="${2##*/}"; suffix="${suffix##*.}"

            case "${suffix}" in
               '')
                  die "invalid unit destfile name: ${1} (arg 2 did not provide any file extension)"
               ;;

               service|socket|device|mount|automount|swap|target|\
               path|timer|snapshot|slice|scope)
                  unit_file="${libdir}/${1}.${suffix}"
               ;;

               *)
                  die "invalid unit destfile name: ${1} (arg 2 did not provide a valid file extension)"
               ;;
            esac

         else
            die "invalid unit destfile name: ${1} (missing file extension)"
         fi
      ;;
   esac

   __extend_unit_file_vars
}


# now the useful functions.

# ~int systemd_hacks_search_target_dirs_all (
#    target_dir_pattern:=**SYSTEMD_HACKS_DEFAULT_TARGET,
#    func, *args
# )
#
systemd_hacks_search_target_dirs_all() {
   : ${1?} ${2:?}
   __systemd_hacks_set_default_target

   local target_dir_pattern
   case "${1}" in
      '')
         target_dir_pattern="${SYSTEMD_HACKS_DEFAULT_TARGET}.target.??*"
      ;;
      '@all'|'@any'|'_')
         target_dir_pattern="?*.target.??*"
      ;;
      *.target.*)
         target_dir_pattern="${1}"
      ;;
      *)
         target_dir_pattern="${1%.target}.target.??*"
      ;;
   esac

   shift || die

   system_confdir__walk \
      "${target_dir_pattern}" test_is_file_or_symlink "$@"
}

# ~int systemd_hacks_search_target_dirs (
#    unit_patterns, target_dir_pattern:=**SYSTEMD_HACKS_DEFAULT_TARGET,
#    func, *args
# )
#
systemd_hacks_search_target_dirs() {
   if [ -z "${1-}" ]; then
      die "expected a non-empty arg for unit_patterns."
   fi

   local unit_patterns
   get_fnmatch_unit_patterns "${1}"
   shift || die

   local __target_arg
   __target_arg="${1-}"
   [ $# -eq 0 ] || shift || die

   systemd_hacks_search_target_dirs_all "${__target_arg}" \
      if_fnmatch_unit_do "${unit_patterns}" "$@"
}

# ~int systemd_hacks_search_target_dirs_linking_to (
#    link_dest_patterns,
#    target_dir_pattern:=**SYSTEMD_HACKS_DEFAULT_TARGET,
#    func, *args
# )
#
systemd_hacks_search_target_dirs_linking_to() {
   if [ -z "${1-}" ]; then
      die "expected a non-empty arg for link_dest_patterns."
   fi

   local unit_patterns
   get_fnmatch_unit_patterns "${1}"
   shift || die

   local __target_arg
   __target_arg="${1-}"
   [ $# -eq 0 ] || shift || die

   # create __unit_linking_to_<>_patterns
   local iter __unit_linking_to_name_patterns __unit_linking_to_path_patterns

   __unit_linking_to_name_patterns=
   __unit_linking_to_path_patterns=

   local must_unset_noglob
   if check_globbing_enabled; then
      set -f
      must_unset_noglob=true
   else
      must_unset_noglob=false
   fi

   for iter in ${unit_patterns}; do
      case "${iter}" in

         "${TARGET_DIR%/}"|"${TARGET_DIR%/}/")
            die "bad link_dest pattern: ${iter}"
         ;;

         "${TARGET_DIR%/}/"*)
            __unit_linking_to_path_patterns="\
${__unit_linking_to_path_patterns} ${iter#${TARGET_DIR%/}}"
         ;;

         /*)
            __unit_linking_to_path_patterns="\
${__unit_linking_to_path_patterns} ${iter}"
         ;;

         *)
            __unit_linking_to_name_patterns="\
${__unit_linking_to_name_patterns} ${iter}"
         ;;

      esac
   done
   __unit_linking_to_name_patterns="${__unit_linking_to_name_patterns# }"
   __unit_linking_to_path_patterns="${__unit_linking_to_path_patterns# }"

   ! ${must_unset_noglob} || set +f

   systemd_hacks_search_target_dirs_all "${__target_arg}" \
      __systemd_hacks_filter_unit_linking_to_do "$@"
}

# ~int systemd_hacks_search_system_units (
#    unit_pattern, func, *args
# )
#
systemd_hacks_search_system_units() {
   : ${1:?} ${2:?}
   local unit_patterns
   get_fnmatch_unit_patterns "${1}"

   shift || die

   system_libdir__walk "/" test_is_file_or_symlink \
      if_fnmatch_unit_do "${unit_patterns}" "$@"
}

# ~int systemd_hacks_search_config_units (
#    unit_pattern, func, *args
# )
#
systemd_hacks_search_config_units() {
   : ${1:?} ${2:?}
   local unit_patterns
   get_fnmatch_unit_patterns "${1}"

   shift || die

   system_confdir__walk "/" test_is_file_or_symlink \
      if_fnmatch_unit_do "${unit_patterns}" "$@"
}

# int systemd_hacks_enable_single_unit (
#    unit, target:=**SYSTEMD_HACKS_DEFAULT_TARGET
# )
#
systemd_hacks_enable_single_unit() {
   __systemd_hacks_set_default_target


   if locate_unit_file "${1-}"; then
      autodie get_systemd_target_wants_dir \
         "${2:-${SYSTEMD_HACKS_DEFAULT_TARGET}}"

      target_dir="${confdir:?}"
      target="${target_dir##*/}"; target="${target%.target.*}"

      if [ -n "${confdir_unit_file}" ]; then
         __systemd_hacks_enable_unit confdir
      else
         __systemd_hacks_enable_unit libdir
      fi

   elif [ "${SYSTEMD_HACKS_IGNORE_MISSING_UNITS:-n}" != "y" ]; then
      die "failed to locate unit file ${1}" ${EX_NO_SUCH_UNIT}

   else
      [ "${SYSTEMD_HACKS_QUIET:-n}" = "y" ] || \
         __systemd_hacks_print_action_err "failed to locate unit file ${1}"
      return ${EX_NO_SUCH_UNIT}
   fi
}

# int systemd_hacks_enable_matching_units (
#    unit_patterns, target:=**SYSTEMD_HACKS_DEFAULT_TARGET
# )
#
systemd_hacks_enable_matching_units() {
   __systemd_hacks_set_default_target

   if [ -z "${1-}" ]; then
      die "no unit patterns given"
   fi


   local unit_patterns
   get_fnmatch_unit_patterns "${1}"

   local __unit_enable_target_dir
   autodie get_systemd_target_wants_dir \
      "${2:-${SYSTEMD_HACKS_DEFAULT_TARGET}}"
   __unit_enable_target_dir="${confdir}"

   systemd_hacks_search_system_units "${unit_patterns}" \
      __systemd_hacks_enable_matching_libdir_unit

   systemd_hacks_search_config_units "${unit_patterns}" \
      __systemd_hacks_enable_matching_confdir_unit

}


# int systemd_hacks_enable_unit (
#    unit|unit_pattern, target:=**SYSTEMD_HACKS_DEFAULT_TARGET
# )
#
#  Dispatcher that calls systemd_hacks_enable_single_unit(unit,target) or
#  systemd_hacks_enable_matching_units(unit_pattern,target), depending
#  on whether the first arg contains wildcard chars or not.
#
systemd_hacks_enable_unit() {
   case "${1-}" in
      *[\*\?]*)
         systemd_hacks_enable_matching_units "$@"
      ;;
      *)
         systemd_hacks_enable_single_unit "$@"
      ;;
   esac
}

# int systemd_hacks_enable_units (
#    *unit, **SYSTEMD_HACKS_DEFAULT_TARGET
# )
#
systemd_hacks_enable_units() {
   local retcode=0

   while [ $# -gt 0 ]; do
      [ -z "${1}" ] || systemd_hacks_enable_unit "${1}" || retcode=${?}
      shift
   done

   return ${retcode}
}

# int systemd_hacks_disable_unit (
#    unit, target:=**SYSTEMD_HACKS_DEFAULT_TARGET
# )
#
systemd_hacks_disable_unit() {
   systemd_hacks_search_target_dirs \
      "${1}" "${2-}" __systemd_hacks_disable_unit
}

# int systemd_hacks_disable_units ( *unit )
#
systemd_hacks_disable_units() {
   systemd_hacks_search_target_dirs "${*}" "" __systemd_hacks_disable_unit
}

# int systemd_hacks_disable_all_units()
#
systemd_hacks_disable_all_units() {
   systemd_hacks_disable_unit '*' '*'
}

# int systemd_hacks_disable_units_linking_to (
#    link_dest_patterns, target="@any"
# )
#
systemd_hacks_disable_units_linking_to() {
   systemd_hacks_search_target_dirs_linking_to \
      "${1-}" "${2-@any}" __systemd_hacks_disable_unit
}

# int systemd_hacks_remove_unit ( unit_patterns )
#
systemd_hacks_remove_unit() {
   autodie systemd_hacks_search_config_units \
      "${1}" __systemd_hacks_remove_unit_file

   autodie systemd_hacks_search_system_units \
      "${1}" __systemd_hacks_remove_unit_file
}

# int systemd_hacks_uninstall_unit ( unit_patterns )
#
systemd_hacks_uninstall_unit() {
   systemd_hacks_disable_units_linking_to "${1}" "@any" && \
   systemd_hacks_remove_unit "${1}"
}

# int systemd_hacks_install_unit ( unit_src, unit_dst= )
#
systemd_hacks_install_unit() {
   local src_file iter

   src_file="${1-}"

   if [ -z "${src_file}" ]; then
      die "missing <unit_src> arg."
   elif ! test_is_real_file "${src_file}"; then
      die "<unit_src> arg ${src_file} is not a file."
   fi

   __systemd_hacks_resolve_unit_destfile_path \
      "${2:-${src_file##*/}}" "${src_file}"

   for iter in \
      "${unit_file}" \
      "${TARGET_DIR%/}/${unit_file_alt_relpath#/}"
   do
      if test_fs_exists "${iter}"; then
         __systemd_hacks_print_action_info \
            "removing ${iter#${TARGET_DIR%/}} (about to be replaced)"
         autodie remove_file "${iter}"
      fi
   done

   __systemd_hacks_print_action_info \
      "installing ${src_file##*/} to ${unit_file_relpath}"
   autodie copy_file "${src_file}" "${unit_file}"
}

# int systemd_hacks_replace_unit ( unit_src, unit_dst= )
#
systemd_hacks_replace_unit() {
   systemd_hacks_install_unit "$@" || return

   __systemd_hacks_print_action_info \
      "fixing units linking to ${unit_file_alt_relpath} -> ${unit_file_relpath}"
   systemd_hacks_search_target_dirs_linking_to \
      "${unit_file_alt_relpath:?}" @any \
      __systemd_hacks_replace_unit_symlink "${unit_file_relpath}"
}

__systemd_hacks_move_unit_to_libdir() {
   is_systemd_unit_type_libdir_preferred "${unit_suffix}" || return 0

   # kind of var abuse // document vars properly
   autodie systemd_hacks_replace_unit \
      "${unit_link:?}" "${unit_file_relpath:?}"
}

# int systemd_hacks_move_units_to_libdir ( unit_patterns )
#
systemd_hacks_move_units_to_libdir() {
   autodie systemd_hacks_search_config_units "${1-*.*}" \
      __systemd_hacks_move_unit_to_libdir
}

__systemd_hacks_mask_unit() {
   local k

   if [ -h "${unit_link:?}" ]; then
      k="$(readlink -- "${unit_link}")"
      case "${k}" in
         /dev/null)
            __systemd_hacks_print_action_info \
               "${unit_suffix#.} ${unit_link_name:?} already masked"
            return 0
         ;;
      esac

      autodie remove_file "${unit_link}"

   elif [ -e "${unit_link}" ]; then
      __systemd_hacks_print_action_info \
         "${unit_suffix#.} ${unit_link_name:?}" \
         "exists and is not a link, removing it"

      autodie remove_file "${unit_link}"
   fi

   if ! test_fs_exists "${unit_file:?}"; then
      __systemd_hacks_print_action_warn \
         "${unit_suffix#.} ${unit_link_name:?}" \
         "doesn't need to be masked (does not exist in libdir)"

      if [ "${SYSTEMD_HACKS_MASK_PHANTOMS:-n}" != "y" ]; then
         return 0
      fi

      __systemd_hacks_print_action_warn \
         "masking it anyway due to MASK_PHANTOMS=y"
   fi

   __systemd_hacks_print_action_info "masking ${unit_link_name:?}"
   autodie create_symlink /dev/null "${unit_link}"
}

# int systemd_hacks_mask_units ( *unit )
#
systemd_hacks_mask_units() {
   if [ -z "${1-}" ]; then
      die "missing <unit> arg."
   fi

   while [ $# -gt 0 ]; do
      if [ -n "${1}" ]; then
         zap_unit_vars

         normalize_unit_name "${1}"
         get_systemd_confdir "/system/${unit_name:?}"
         __set_confdir_system_unit_vars "${confdir}" system

         autodie __systemd_hacks_mask_unit
      fi

      shift
   done
}

# int systemd_hacks_mask_matching_units ( unit_patterns )
#
systemd_hacks_mask_matching_units() {
   systemd_hacks_search_system_units "${1}" __systemd_hacks_mask_unit
}
