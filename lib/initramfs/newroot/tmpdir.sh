# @private void newroot_tmpdir__setperm_user ( dir, **tmpdir_owner_id )
#
#  Sets permissions (chown&chmod) for a user tmpdir.
#
newroot_tmpdir__setperm_user() {
   inonfatal chown "${tmpdir_owner_id?}" "${1}" || true
   inonfatal chmod 0700 "${1}" || true
}

# @private void newroot_tmpdir__setperm_user_root ( dir )
#
#  Sets permissions for the user tmpdir root directory.
#
newroot_tmpdir__setperm_user_root() {
   local rc=0
   inonfatal chown 0:0 "${1}"  || rc=$?
   inonfatal chmod 0711 "${1}" || rc=$?
   return ${rc}
}

# @private int newroot_tmpdir__dodir_user ( **tmpdir_user, **tmpdir_owner_id )
#
#  Creates a user tmpdir and sets permissions.
#
newroot_tmpdir__dodir_user() {
   newroot_tmpdir_dodir /users/${tmpdir_user:?} newroot_tmpdir__setperm_user
}

# void newroot_tmpdir_init (
#    tmpdir="/tmp", tmpdir_name=<default>, extra_opts=,
#    **NEWROOT_TMPDIR!, **NEWROOT, **NEWROOT_TMPDIR_SIZE=20%,
#    **NEWROOT_TMPDIR_NAME_PREFIX="i_"
# )
#
#  Mounts %NEWROOT/%tmpdir (if not already mounted).
#
newroot_tmpdir_init() {
   NEWROOT_TMPDIR=
   local t="${1:-/tmp}"
   local mp="${NEWROOT?}/${t#/}"

   {
      # %mp already mounted, premount %t, mount %mp?
      is_mounted "${mp}" || \
      inonfatal newroot_premount "${t}" || \
      imount_fs "${mp}" \
         "${NEWROOT_TMPDIR_NAME_PREFIX-i_}${t##*/}" \
         "defaults,rw,size=${NEWROOT_TMPDIR_SIZE:=20%}${3:+,}${3-}" \
         tmpfs
   } && NEWROOT_TMPDIR="${mp}"
}

# int newroot_tmpdir_dodir (
#    dir, f_dodir_created=,
#    mkdir_opts_append=,
#    f_dodir_existed=, f_dodir_existed_file=,
#    **v0!, **NEWROOT_TMPDIR
# )
#
#  dodir() wrapper.
#  Sets v0=%NEWROOT_TMPDIR/%dir and ensures that this directory exists.
#
newroot_tmpdir_dodir() {
   v0="${NEWROOT_TMPDIR}/${1#/}"

   F_DODIR_CREATED="${2-}" \
   MKDIR_OPTS_APPEND="${3-}" \
   F_DODIR_EXISTED="${4-}" \
   F_DODIR_EXISTED_FILE="${5-}" \
   KEEPDIR=y \
   DODIR_PREFIX="" \
   dodir "${v0}"
}

# int newroot_tmpdir_avail ( **NEWROOT_TMPDIR )
#
#  Returns 0 if NEWROOT_TMPDIR is set, else 1.
#
newroot_tmpdir_avail() { [ -n "${NEWROOT_TMPDIR-}" ]; }

# int newroot_tmpdir_users (
#    *user_spec,
#    **NEWROOT_TMPDIR,
#    **NEWROOT_TMPDIR_USER_GID=0, **NEWROOT_TMPDIR_USER_ONLY=n
# )
#
#  Creates private per-user dirs in %NEWROOT_TMPDIR/users/.
#
#  Always creates %NEWROOT_TMPDIR/users and %NEWROOT_TMPDIR/users/root
#  unless NEWROOT_TMPDIR_USER_ONLY is set to 'y'.
#  This variable will automatically be set to 'y' once these directories
#  have been created, so no manual interaction required here.
#
#  A user spec is a 2- or 3-tuple containing the user's name, uid and gid,
#  separated by colon characters:
#
#   user_spec ::= <name>:<uid>[:[<gid>]]
#
#  gid defaults NEWROOT_TMPDIR_USER_GID if the user_spec does not end
#  with ':', else the uid will be (re-)used as gid.
#
#  Example: "myself:1000:", which is exactly the same as "myself:1000:1000".
#
#  The return value corresponds to the number of directories that could not
#  be created.
#
#  Note:
#   This function does let you control the creation of root's tmpdir.
#
#  Another note:
#   You can also set up per-user tmp dirs during newroot's init process,
#   which allows to use names instead of uid/gid. The advantage of using this
#   function (if called during newroot_setup(), for example) is that you
#   can safely use private TMPDIRs, e.g. in later initramfs code or init
#   scripts.
#
newroot_tmpdir_users() {
   local v0 tmpdir_owner_id tmpdir_user fail=0

   if ! newroot_tmpdir_avail; then
      return 2
   elif [ "${NEWROOT_TMPDIR_USER_ONLY:-n}" != "y" ]; then
      inonfatal newroot_tmpdir_dodir /users \
         newroot_tmpdir__setperm_user_root "" \
         newroot_tmpdir__setperm_user_root || return

      tmpdir_owner_id="0:0"
      tmpdir_user="root"
      inonfatal newroot_tmpdir__dodir_user && \
         NEWROOT_TMPDIR_USER_ONLY=y || fail=1
   fi

   while [ $# -gt 0 ]; do
      if [ -n "${1-}" ]; then
         tmpdir_user="${1%%:*}"
         v0="${1#*:}"

         case "${v0}" in
            '')
               initramfs_die "newroot_tmpdir_users(): bad user spec: ${1}"
               continue
            ;;
            *:?*)
               tmpdir_owner_id="${v0}"
            ;;
            *:)
               tmpdir_owner_id="${v0}${v0%:}"
            ;;
            *)
               tmpdir_owner_id="${v0}:${NEWROOT_TMPDIR_USER_GID:-0}"
            ;;
         esac

         inonfatal newroot_tmpdir__dodir_user || fail=$(( ${fail} + 1 ))
      fi
      shift
   done
   return ${fail}
}
