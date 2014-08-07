#@section functions

# int system_setup_rootfs_from_tarball (
#    root_dir, tmpdir, tarball_fetch_func, tarball_file=, *tar_opts,
#    **CMD_PREFIX=,
#    **SYSTEM_ROOTFS!
# )
#
system_setup_rootfs_from_tarball() {
   : ${1:?} ${2:?} ${3:?}
   local root_dir tmpdir tarball_file tarball_fetch_func v0

   root_dir="$(readlink -m "${1}")"

   case "${root_dir}" in
      '')
         eerror "readlink() failed" '!!!'
         return 240
      ;;
      /)
         eerror "/ as system_setup rootfs is a bad idea" '!!!'
         return 20
      ;;
   esac


   tmpdir="${2}"
   tarball_fetch_func="${3}"
   shift 3 || return

   tarball_file="${1-}"
   [ -z "${1+SET}" ] || shift || return


   if [ -f "${root_dir}/.status/unpacked" ]; then
      eerror "root dir ${root_dir} exists and has already been unpacked!"
      return 3
   fi


   ${CMD_PREFIX-} mkdir -p -- "${tmpdir}" || return

   # get tarball file
   if [ "${tarball_file:-_}" = "_" ] || [ ! -f "${tarball_file}" ]; then
      einfo "fetching tarball file ${tarball_file}"

      system_setup_rootfs_from_tarball__runcmd \
         mkdir  -- "${tmpdir}/fetch" || return

      v0=
      if ${tarball_fetch_func} "${tmpdir}"; then
         true
      else
         eerror "tarball_fetch_func ${tarball_fetch_func}() returned non-zero (${?})."
         system_setup_rootfs_from_tarball__cleanup
         return 8
      fi

      if [ -z "${v0-}" ]; then
         eerror "tarball_fetch_func ${tarball_fetch_func}() did not set %v0!"
         system_setup_rootfs_from_tarball__cleanup
         return 9
      fi

      if [ "${tarball_file:-_}" = "_" ]; then
         tarball_file="${v0}"
      else
         system_setup_rootfs_from_tarball__runcmd \
            mkdir -p -- "$(dirname "${tarball_file}")" || return
         system_setup_rootfs_from_tarball__runcmd \
            mv -- "${v0}" "${tarball_file}" || return
      fi

   fi

   # unpack tarball file
   #
   #  directly if %root_dir exists and
   #  (a) %root_dir is not on the same filesystem as its parent directory
   #      (-> %root_dir is a mountpoint)
   #  OR
   #  (b) %root_dir cannot be removed (rmdir fails)
   #
   #  otherwise: unpack into temporary directory && mv
   #
   if \
      [ -d "${root_dir}" ] && \
      {
         ! parent_is_on_same_fs "${root_dir}" || \
         ! rmdir -- "${root_dir}" 2>>${DEVNULL}
      }
   then
      einfo "Unpacking ${tarball_file} directly into ${root_dir}"
      system_setup_rootfs_from_tarball__unpack \
         "${root_dir}" "${tarball_file}" "${@}" || return

   else
      einfo "Unpacking ${tarball_file} into temporary directory"

      ${CMD_PREFIX-} rm -f -- "${root_dir}"

      system_setup_rootfs_from_tarball__runcmd \
         mkdir -- "${tmpdir}/image" || return

      system_setup_rootfs_from_tarball__unpack \
         "${tmpdir}/image" "${tarball_file}" "${@}" || return

      system_setup_rootfs_from_tarball__runcmd \
         mv -T -- "${tmpdir}/image" "${root_dir}" || return
   fi

   system_setup_rootfs_from_tarball__cleanup
   SYSTEM_ROOTFS="${root_dir}"
   return 0
}


# @private
system_setup_rootfs_from_tarball__cleanup() {
   [ ! -d "${tmpdir}" ] || ${CMD_PREFIX-} rm -rf -- "${tmpdir}"
}

# @private
system_setup_rootfs_from_tarball__runcmd() {
   if ${CMD_PREFIX-} "${@}"; then
      return 0
   else
      local ret=${?}
      system_setup_rootfs_from_tarball__cleanup
      return ${reŧ}
   fi
}

# @private
system_setup_rootfs_from_tarball__unpack() {
   local d f
   d="${1:?}"; f="${2:?}"; shift 2

   if \
      ${CMD_PREFIX-} tar xap -C "${d}/" -f "${f}" "${@}" && \
      ${CMD_PREFIX-} mkdir -- "${d}/.status" && \
      ${CMD_PREFIX-} touch -- "${d}/.status/unpacked"
   then
      return 0
   else
      local ret=${?}
      system_setup_rootfs_from_tarball__cleanup
      return ${ret}
   fi
}
