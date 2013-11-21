#@section functions

# int md_foreach_member (
#    md_identifier=<detect>,
#    *cmdv=**F_MD_FOREACH_MEMBER=einfo,
#    **F_MD_FOREACH_MEMBER_ONERROR=return,
#    **DEFAULT_MD=, **MD_IMPLICIT=y, **MD_RESTRICT_NAMES=y,
#    **v0!
# )
#
#  Executes cmdv for each member of the given md device. Also stores the
#  member's device paths (/dev/..) in v0.
#
#  Tries to autodetect the md device if none is given and DEFAULT_MD is not
#  set (else DEFAULT_MD will be used).
#  This will fail unless the system has exactly one.
#
#  The first arg will part of *cmdv if MD_IMPLICIT is set to 'y' and if it
#  is empty or not a valid md_identifier. The latter one will only be
#  checked if MD_RESTRICT_NAMES is set to 'y', in which case identifiers
#  have to start with "md".
#
#  Passing true as cmdv (or F_MD_FOREACH_MEMBER=true) results in storing
#  the member's device in v0 only.
#
md_foreach_member() {
   v0=
   local MD="${1-}"

   # auto-detect md if unset (or empty) (#1)
   if [ -n "${MD}" ]; then
      MD="${MD##*/}"

      if [ "${MD_RESTRICT_NAMES:-y}" = "y" ]; then
         # reset MD if it does not start with "md" (or is empty)
         if [ -z "${MD}" ] || [ "${MD#md}" = "${MD}" ]; then
            MD=
         fi
      fi
   fi

   # auto-detect md if unset (or empty) (#2)
   if [ -n "${MD}" ]; then
      # MD is set, MD_IMPLICIT has no effect

      [ $# -eq 0 ] || shift || return 3

   elif [ -n "${DEFAULT_MD-}" ]; then
      # MD is not set but DEFAULT_MD is, MD_IMPLICIT defaults to y

      MD="${DEFAULT_MD##*/}"

      if [ $# -eq 0 ]; then
         true
      elif [ -z "${1}" ] || [ "${MD_IMPLICIT:-y}" != "y" ]; then
         shift || return 3
      fi

   else
      # MD and DEFAULT_MD are not set, MD_IMPLICIT defaults to y
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

         if [ $# -eq 0 ]; then
            true
         elif [ -z "${1}" ] || [ "${MD_IMPLICIT:-y}" != "y" ]; then
            shift || return 3
         fi

      else
         eerror "no md device given, cannot autodetect (none found)."
         return 6
      fi
   fi

   local MD_BLOCK="/sys/block/${MD}"

   if [ -z "${MD}" ] || [ ! -d "${MD_BLOCK}" ]; then

      eerror "no such md device: ${MD} (${MD_BLOCK})"
      return 2

   else

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
