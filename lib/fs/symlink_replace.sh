# int symlink_replace ( symlink, new_target )
#
#  Safely replaces a symlink. It is guaranteed that the symlink exists at any
#  time during execution of this function (if it existed before), either
#  pointing to the old target or the new one.
#  Returns 0 if the symlink has been replaced, else a non-zero value will
#  be returned.
#
symlink_replace() {
   local symlink="${1:?}" ltarget_new="${2:?}" symlink_tmp
   symlink_tmp=$(mktemp -u "${symlink}.XXXXXXXXXXX")

   [ -n "${symlink_tmp}" ] && \
      ln -s -T -- "${ltarget_new}" "${symlink_tmp}" || return

   if mv -T -- "${symlink_tmp}" "${symlink}"; then
      return 0
   else
      local rc=$?
      rm -f "${symlink_tmp}"
      return ${rc}
   fi
}
