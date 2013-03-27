# int md_foreach_member (
#    md_identifier=<detect>,
#    *cmdv=**F_MD_FOREACH_MEMBER=einfo,
#    **F_MD_FOREACH_MEMBER_ONERROR=return,
#    **v0!
# )
#
#  Executes cmdv for each member of the given md device. Also stores the
#  member's device paths (/dev/..) in v0.
#
#  Tries to autodetect the md device if none is given. This will fail unless
#  the system has exactly one.
#
#  Passing true as cmdv (or F_MD_FOREACH_MEMBER=true) results in storing
#  the member's device in v0 only.
#
md_foreach_member() {
   v0=
   local MD="${1-}"

   # auto-detect md if unset (or empty)
   if [ -z "${MD}" ]; then
      local md
      for md in /sys/block/md?*; do
         if [ -d "${md}" ]; then
            if [ -z "${MD}" ]; then
               MD="${md##*/}"
            else
               eerror "no md device given, cannot autodetect (found more than one device)."
               return 5
            fi
         fi
      done
      if [ -n "${MD}" ]; then
         einfo "no md device given, using ${MD}."
      else
         eerror "no md device given, cannot autodetect (none found)."
         return 6
      fi
   else
      MD="${MD##*/}"
   fi

   local MD_BLOCK="/sys/block/${MD}"

   if [ -z "${MD}" ] || [ ! -d "${MD_BLOCK}" ]; then

      eerror "no such md device: ${MD} (${MD_BLOCK})"
      return 2

   else
      [ $# -eq 0 ] || shift || return 3

      # get members
      local member dev_name dev MD_MEMBERS=
      for member in "${MD_BLOCK}/slaves/"[hsm]d?*; do
         if [ -e "${member}" ]; then
            dev_name="${member##*/}"
            dev_name="${dev_name%%[0-9]*}"
            dev="/dev/${dev_name}"
            if [ -b "${dev}" ]; then
               MD_MEMBERS="${MD_MEMBERS} ${dev}"
            else
               ewarn "device ${dev} (member ${member}) cannot be found"
            fi
         fi
      done

      v0="${MD_MEMBERS# }"

      # run cmdv

      if [ -z "${MD_MEMBERS}" ]; then

         ewarn "no devices found."
         return 3

      elif \
         [ "x${1-}" = "xtrue" ] || \
         [ "x${F_MD_FOREACH_MEMBER-}" = "xtrue" ]
      then

         true

      elif [ -n "${1-}" ]; then

         for dev in ${MD_MEMBERS}; do
            "$@" "${dev}" || \
               ${F_MD_FOREACH_MEMBER_ONERROR:-return}
         done

      elif [ -n "${F_MD_FOREACH_MEMBER-}" ]; then

         for dev in ${MD_MEMBERS}; do
            ${F_MD_FOREACH_MEMBER} "${dev}" || \
               ${F_MD_FOREACH_MEMBER_ONERROR:-return}
         done

      else
         einfo "members of ${MD}: ${MD_MEMBERS# }"
      fi
   fi
}
