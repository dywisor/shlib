#@section vars
: ${X_GIT:=git}

#@section functions

instagitlet_fakecmd() {
   local tag="${1:-cmd}"; shift || die "out of bounds"
   einfo "${*}" "(${tag})"
}


instagitlet_dodir() {
   if __faking__; then
      instagitlet_fakecmd dodir "$@"
   elif dodir_clean "$@"; then
      return 0
   else
      local rc=${?}
      eerror "failed to create directories: ${*}"
      return ${rc}
   fi
}

instagitlet_run_git() {
   #@VARCHECK X_GIT *
   if __faking__; then
      instagitlet_fakecmd git-cmd ${X_GIT} "$@"
   elif ${X_GIT} "$@"; then
      return 0
   else
      local rc=${?}
      eerror "'${X_GIT} ${*}' failed (${rc})."
      return ${rc}
   fi
}

instagitlet_chdir() {
   if __faking__; then
      FAKE_MODE_CHDIR_FAIL=
      instagitlet_fakecmd chdir "$@"
      if ! cd "$@" 2>/dev/null; then
         FAKE_MODE_CHDIR_FAIL="$*"
         ewarn "cd '${*}' failed, continuing anyway." '!!!'
      fi
      return 0
   elif cd "$@"; then
      return 0
   else
      eerror "cd '${*}' failed!"
      return 1
   fi
}



# int git_repo_update ( store_dir, git_uri )
#
git_repo_update() {
   #@VARCHECK 1 2 X_GIT
   instagitlet_dodir "${1%/*}" || return

   if [ -d "${1}" ]; then
      einfo "Updating existing git repo ${1}"
      (
         git=instagitlet_run_git || die "\$git is readonly"

         instagitlet_chdir "${1}" && \
         ${git} fetch && \
         ${git} config merge.defaultToUpstream true && \
         ${git} merge --ff-only
      )
   else
      einfo "Downloading git repo ${2}"
      instagitlet_run_git clone "${2}" "${1}"
   fi
}

# int instagitlet__get_vars_from_passwd (
#    user="",
#    **ID_USER!, **ID_UID!, **ID_GID!, **ID_HOME!
# )
#
instagitlet__get_vars_from_passwd() {
   ID_USER=; ID_UID=; ID_GID=; ID_HOME=;

   local my_uid pwd_entry

   if \
      my_uid="$(id -u ${1-} 2>/dev/null)" && \
      pwd_entry="$( getent passwd "${my_uid}")"
   then
      local IFS=":"
      set -- ${pwd_entry}
      IFS="${IFS_DEFAULT}"

      ID_USER="${1-}"
      ID_UID="${3-}"
      ID_GID="${4-}"
      ID_HOME="${6-}"

      if \
         [ -n "${1-}" ] && [ -n "${3-}" ] && [ -n "${4-}" ] && \
         [ -n "${6+SET}" ]
      then
         return 0
      else
         return 3
      fi
   else

      return 2
   fi
}




# void instagitlet_init_vars (
#    project_name, git_uri,
#    destdir=%GIT_STORE_DIR/%project_name,
#    **GIT_STORE_DIR=%HOME/git-src,
#    **HOME!x,
#    **GIT_APP_NAME!, **GIT_APP_URI!, **GIT_APP_ROOT!, **GIT_APP_REAL_ROOT!
# ), raises die()
#
instagitlet_init_vars() {
   local v0

   [ -n "${1-}" ] || die "project name must not be empty." ${EX_USAGE}
   [ -n "${2-}" ] || ewarn "empty git uri prevents sync actions."

   if ! instagitlet__get_vars_from_passwd; then
      ewarn "failed to get passwd data!"
   fi

   if [ -z "${HOME-}" ] && [ -n "${ID_HOME}" ]; then
      HOME="${ID_HOME}"
      export HOME
   fi

   [ -z "${HOME-}" ] || : ${GIT_STORE_DIR:="${HOME}/git-src"}

   GIT_APP_NAME="${1}"
   GIT_APP_URI="${2-}"

   case "${3-}" in
      '')
         [ -n "${HOME-}" ] || die "\$HOME is not set."
         GIT_APP_ROOT="${GIT_STORE_DIR}/${GIT_APP_NAME}"
      ;;
      ./*|/*)
         GIT_APP_ROOT="${3}"
      ;;
      *)
         GIT_APP_ROOT="${GIT_STORE_DIR}/${3}"
      ;;
   esac

   GIT_APP_REAL_ROOT="$(readlink -m "${GIT_APP_ROOT}")"
   return 0
}

instagitlet_get_src() {
   local KEEPDIR=y
   varcheck GIT_APP_URI GIT_APP_ROOT GIT_APP_REAL_ROOT
   autodie git_repo_update "${GIT_APP_REAL_ROOT}" "${GIT_APP_URI}"
}
