#@section const

# semi-const __SYSTEMD_HACKS_TARGET_VARS
readonly __SYSTEMD_HACKS_DEFAULT_TARGET_VARS="\
target target_dir"

__SYSTEMD_HACKS_TARGET_VARS="${__SYSTEMD_HACKS_DEFAULT_TARGET_VARS}"

# semi-const __SYSTEMD_HACKS_UNIT_VARS
readonly __SYSTEMD_HACKS_DEFAULT_UNIT_VARS="\
unit_name unit_basename unit_suffix unit_template_name unit_template_stem \
unit_link unit_link_relpath unit_link_name \
unit_file unit_file_relpath unit_file_relpath_orig unit_file_alt_relpath \
unit_file_name \
confdir_unit_file libdir_unit_file"

__SYSTEMD_HACKS_UNIT_VARS="${__SYSTEMD_HACKS_DEFAULT_UNIT_VARS}"


#@section functions

is_systemd_unit_type() {
   case "${1#.}" in
      service|socket|device|mount|automount|swap|target|\
      path|timer|snapshot|slice|scope)
         return 0
      ;;
   esac

   return 1
}

is_systemd_unit_type_libdir_preferred() {
   case "${1#.}" in
      service|socket|timer)
         return 0
      ;;
   esac

   return 1
}

# get_fnmatch_unit_patterns ( *input, **unit_patterns! )
#
get_fnmatch_unit_patterns() {
   unit_patterns=
   local iter must_unset_noglob

   if check_globbing_enabled; then
      must_unset_noglob=true
      set -f
   else
      must_unset_noglob=false
   fi

   while [ $# -gt 0 ]; do
      for iter in ${1}; do
         case "${iter}" in
            *.*)
               unit_patterns="${unit_patterns} ${iter}"
            ;;
            *)
               unit_patterns="${unit_patterns} ${iter}.service"
            ;;
         esac
      done

      shift
   done

   ! ${must_unset_noglob} || set +f

   unit_patterns="${unit_patterns# }"
}

# int if_fnmatch_unit_do ( unit_patterns, func, *args, **unit_name )
#
if_fnmatch_unit_do() {
   fnmatch_in_any "${unit_name?}" "${1}" || return 0
   shift || die
   "$@"
}

get_systemd_libdir() {
   libdir_root="${TARGET_DIR:?}/${SYSTEMD_LIBDIR#/}"
   case "${1-}" in
      ''|'/')
         libdir="${libdir_root}"
      ;;
      *)
         libdir="${libdir_root}/${1#/}"
      ;;
   esac
}

get_systemd_confdir() {
   confdir_root="${TARGET_DIR:?}/${SYSTEMD_CONFDIR#/}"
   case "${1-}" in
      ''|'/')
         confdir="${confdir_root}"
      ;;
      *)
         confdir="${confdir_root}/${1#/}"
      ;;
   esac
}

# void get_systemd_target_dep_dir (
#    target, dep_name,
#    **confdir!, **confdir_root!
# )
#
get_systemd_target_dep_dir() {
   : ${1:?} ${2:?}
   get_systemd_confdir "system/${1%.target}.target.${2}"
}

# void get_systemd_target_wants_dir (
#    target,
#    **target_wants_dir!, **confdir!, **confdir_root!
# )
#
get_systemd_target_wants_dir() {
   get_systemd_target_dep_dir "${1?}" wants
   target_wants_dir="${confdir}"
}

# void normalize_unit_name ( unit_name_in, **unit_name! ), raises die()
#
normalize_unit_name() {
   unit_name=

   case "${1}" in
      ''|*/*)
         die "bad unit name: ${1:-<empty>}"
      ;;
      *.*)
         unit_name="${1}"
      ;;
      *)
         unit_name="${1}.service"
      ;;
   esac
}

# split_unit_name (
#    unit_name=**unit_name,
#    **unit_basename!, **unit_suffix!, **unit_template_name!
# )
#
split_unit_name() {
   unit_basename=
   unit_suffix=
   unit_template_name=
   unit_template_stem=

   local u
   u="${1:-${unit_name:?}}"

   unit_basename="${u%.*}"
   unit_suffix=".${u##*.}"

   case "${unit_basename}" in
      ?*@*)
         unit_template_stem="${unit_basename##*@}"
         unit_template_name="${unit_basename%@*}@${unit_suffix}"
      ;;
   esac
}


# void get_unit_confdir (
#    unit,
#    **unit_name!, **unit_confdir!, **confdir!, **confdir_root!
# )
#
get_unit_confdir() {
   normalize_unit_name "${1:?}"
   get_systemd_confdir "system/${unit_name}.d"
   unit_confdir="${confdir}"
}

# void dump_unit_vars()
#
dump_unit_vars() {
   printf "\n%s\n" "${SYSTEMD_HACKS_HLINE?}"

   printvar \
      ${__SYSTEMD_HACKS_DEFAULT_TARGET_VARS?} \
      ${__SYSTEMD_HACKS_DEFAULT_UNIT_VARS?}

   printf "%s\n" "${SYSTEMD_HACKS_HLINE?}"
}

# void zap_unit_vars()
#
zap_unit_vars() {
   local __vname
   if [ $# -gt 0 ]; then
      for __vname in ${__SYSTEMD_HACKS_UNIT_VARS?}; do
         if ! fnmatch_in_any "${__vname}" "$@"; then
            eval "${__vname}="
         fi
      done
   else
      for __vname in ${__SYSTEMD_HACKS_UNIT_VARS?}; do
         eval "${__vname}="
      done
   fi
}


__set_unit_file_alt_relpath() {
   case "${unit_file_relpath-}" in
      '')
         die "unit_file_relpath empty or not set."
      ;;

      "${SYSTEMD_CONFDIR%/}/"*)
         unit_file_alt_relpath="\
${SYSTEMD_LIBDIR%/}${unit_file_relpath#${SYSTEMD_CONFDIR%/}}"
      ;;

      "${SYSTEMD_LIBDIR%/}/"*)
         unit_file_alt_relpath="\
${SYSTEMD_CONFDIR%/}${unit_file_relpath#${SYSTEMD_LIBDIR%/}}"
      ;;

      *)
         die "bad unit file relpath: ${unit_file_relpath}"
      ;;
   esac
}

__set_confdir_system_unit_vars() {
   local v0 relpath_parent
   zap_unit_vars

   unit_link="${1:?}"

   unit_link_relpath="${unit_link#${TARGET_DIR%/}}"
   unit_link_name="${unit_link_relpath##*/}"
   unit_name="${unit_link_name}"
   normalize_unit_name "${unit_name}"
   split_unit_name

   unit_file_relpath_orig="$(readlink -- "${unit_link}" 2>/dev/null)"

   case "${2:?}" in
      target|subdir|subdir=1)
         relpath_parent="${SYSTEMD_CONFDIR%/}/system"
      ;;
      system|nosubdir|subdir=0)
         relpath_parent="${SYSTEMD_CONFDIR%/}"
         if [ -z "${unit_file_relpath_orig}" ]; then
            unit_file_relpath="${SYSTEMD_LIBDIR%/}/system/${unit_name}"
         fi
      ;;
      *)
         die "bad usage"
      ;;
   esac

   if [ -z "${unit_file_relpath}" ]; then
      case "${unit_file_relpath_orig}" in
         '../..'|'../../'*|'../'*'/..'|'../'*'/../'*|'../'*'/..')
            # requires normpath()
            target_normpath \
               "${relpath_parent}/${unit_file_relpath_orig#../}"
            unit_file_relpath="${v0:?}"

         ;;
         /*)
            # could use normpath here, too ("."->"" etc)
            unit_file_relpath="${unit_file_relpath_orig}"
         ;;
         ../*)
            unit_file_relpath="${relpath_parent}/${unit_file_relpath_orig#../}"
         ;;
         *)
            die "bad unit_file_relpath ${unit_file_relpath_orig}"
         ;;
      esac
   fi

   unit_file_name="${unit_file_relpath##*/}"
   get_target_path "${unit_file_relpath}"
   unit_file="${v0:?}"

   __set_unit_file_alt_relpath
}


__extend_unit_file_vars() {
   # don't use ${a:=${b:=${c:=...}}}
   #  this would leave $b and $c unset if $a is set

   if [ -z "${unit_file-}" ]; then
      if [ -n "${unit_file_relpath-}" ]; then
         unit_file="${TARGET_DIR%/}/${unit_file_relpath#/}"
      else
         die "neither unit_file nor unit_file_relpath set"
      fi
   fi

   if [ -n "${unit_link-}" ]; then
      unit_link_relpath="${unit_link#${TARGET_DIR%/}}"
      unit_link_name="${unit_link_relpath##*/}"
   fi

   unit_file_relpath="${unit_file#${TARGET_DIR%/}}"
   unit_file_name="${unit_file##*/}"

   normalize_unit_name "${unit_name:=${unit_file_name}}"
   split_unit_name

   __set_unit_file_alt_relpath
}

# void __systemd_hacks_do_walk ( *args, **... )
#
__systemd_hacks_do_walk() {
   local v0 ${__SYSTEMD_HACKS_TARGET_VARS?} ${__SYSTEMD_HACKS_UNIT_VARS?}

   for target_dir in "${__walk_root}/"${dir_pattern}"/."; do
      [ -d "${target_dir}" ] || continue

      # don't leak %confdir, %libdir (#A)
      confdir=; libdir=;

      target_dir="${target_dir%/.}"

      target="${target_dir##*/}"
      target="${target%.target.*}"

      for unit_link in "${target_dir%/}/"*; do
         ${item_filter:?} "${unit_link}" || continue
         zap_unit_vars unit_link

         autodie ${__walk_dispatcher:?} "$@"

         # don't leak %confdir, %libdir (#B)
         confdir=; libdir=;
      done
   done
}

__systemd_hacks_walk_dispatcher_confdir() {
   __set_confdir_system_unit_vars "${unit_link}" "${subdir_type:?}"
   autodie ${func:?} "$@" "${unit_link_relpath:?}"
}

__systemd_hacks_walk_dispatcher_libdir() {
   unit_file="${unit_link:?}"
   __extend_unit_file_vars
   autodie ${func:?} "$@" "${unit_file_relpath:?}"
}

# void system_libdir__walk ( dir_pattern, item_filter, func, *args )
#
system_libdir__walk() {
   : ${1:?} ${2:?} ${3:?}
   local confdir_root libdir_root confdir libdir v0
   local dir_pattern item_filter func subdir_type
   local __walk_dispatcher __walk_root

   dir_pattern="${1%/}"
   item_filter="${2}"
   func="${3}"
   shift 3 || die

   get_systemd_libdir "system"
   __walk_dispatcher=__systemd_hacks_walk_dispatcher_libdir
   __walk_root="${libdir}"

   __systemd_hacks_do_walk "$@"
}

# void system_confdir__walk ( dir_pattern, item_filter, func, *args )
#
system_confdir__walk() {
   : ${1:?} ${2:?} ${3:?}
   local confdir_root libdir_root confdir libdir
   local dir_pattern item_filter func subdir_type
   local __walk_dispatcher __walk_root

   dir_pattern="${1%/}"
   item_filter="${2}"
   func="${3}"
   shift 3 || die

   case "${dir_pattern}" in
      ''|'/')
         dir_pattern=
         subdir_type=system
      ;;
      *)
         subdir_type=subdir
      ;;
   esac

   get_systemd_confdir "system"
   __walk_dispatcher="__systemd_hacks_walk_dispatcher_confdir"
   __walk_root="${confdir}"

   __systemd_hacks_do_walk "$@"
}

# system_confdir__walk_target_deps ( dep_type, func, *args )
#
system_confdir__walk_target_deps() {
   local dep_type="${1:?}"

   shift
   system_confdir__walk "*.target.${dep_type}" test_is_file_or_symlink "$@"
}


# int locate_unit_file__in_dir (
#    dir, **v0!,
#    **unit_name, **unit_template_stem, **unit_template_name
# )
#
locate_unit_file__in_dir() {
   if [ -f "${1}/${unit_name}" ]; then
      v0="${1}/${unit_name}"
      return 0

   elif \
      [ -n "${unit_template_stem}" ] && \
      [ -f "${1}/${unit_template_name}" ]
   then
      v0="${1}/${unit_template_name}"
      return 0

   else
      return 5
   fi
}

# int locate_unit_file ( unit_ident, **...! )
#
locate_unit_file() {
   local v0 confdir_root libdir_root confdir libdir
   zap_unit_vars

   case "${1-}" in
      '')
         die "unit file name must not be empty."
      ;;
   esac

   normalize_unit_name "${1}" || return
   split_unit_name || return

   get_systemd_confdir "system"
   if locate_unit_file__in_dir "${confdir}"; then
      confdir_unit_file="${v0}"
   fi

   get_systemd_libdir "system"
   if locate_unit_file__in_dir "${libdir}"; then
      libdir_unit_file="${v0}"
   fi

   for v0 in "${confdir_unit_file}" "${libdir_unit_file}"; do
      if [ -n "${v0}" ]; then
         unit_file="${v0}"
         __extend_unit_file_vars
         return 0
      fi
   done

   return ${EX_NO_SUCH_UNIT}
}
