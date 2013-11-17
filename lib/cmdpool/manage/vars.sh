# CMDPOOL_EX_
#  exit/return codes
#
readonly CMDPOOL_EX_DENIED=20
readonly CMDPOOL_EX_NOROOT=22
readonly CMDPOOL_EX_FAILROOT=23
readonly CMDPOOL_EX_NOSLOT=24
readonly CMDPOOL_EX_FAILSLOT=25
readonly CMDPOOL_EX_BADSLOT=26
readonly CMDPOOL_EX_STARTFAIL=27
readonly CMDPOOL_EX_CMDRUNNING=28
readonly CMDPOOL_EX_NOHELPER=29


# void cmdpool_manage_defsym (
#    **RUNDIR!, **USER!,
#    **DEFAULT_CMDPOOL_ROOT!, **CMDPOOL_ROOT!,
#    **DEFAULT_X_CMDPOOL_RUNCMD!, **X_CMDPOOL_RUNCMD!,
#    **CMDPOOL_COMMAND!u,
#    **CMDPOOL_SUBCOMMAND!u,
#    **CMDPOOL_MANAGE_LIST_NAMES_ONLY!u,
#    **CMDPOOL_WAIT_TIMEOUT!u,
#    **CMDPOOL_SINGLE_SLOT!u, **CMDPOOL_SLOTS!u, **CMDPOOL_SLOT_BASENAMES!u,
#    **CMDPOOL_WANT_ALL_SLOTS!u
# )
#
#  Initializes cmdpool(-manage) variables.
#
cmdpool_manage_defsym() {
   local libdir

   [ -n "${RUNDIR-}" ] || RUNDIR="/run"
   [ -n "${USER-}"   ] || USER="$(id -nu)"

   DEFAULT_CMDPOOL_ROOT="${RUNDIR}/cmdpool.${USER}/default"
   CMDPOOL_ROOT="${DEFAULT_CMDPOOL_ROOT}"

   DEFAULT_X_CMDPOOL_RUNCMD="/usr/bin/cmdpool-runcmd.sh"
   for libdir in /usr/lib64 /usr/lib32 /usr/lib; do
      if [ -f "${libdir}/shlib/cmdpool-runcmd.sh" ]; then
         DEFAULT_X_CMDPOOL_RUNCMD="${libdir}/shlib/cmdpool-runcmd.sh"
         break
      fi
   done
   X_CMDPOOL_RUNCMD="${DEFAULT_X_CMDPOOL_RUNCMD}"

   unset -v \
      CMDPOOL_COMMAND CMDPOOL_SUBCOMMAND \
      CMDPOOL_MANAGE_LIST_NAMES_ONLY CMDPOOL_WAIT_TIMEOUT \
      CMDPOOL_SINGLE_SLOT CMDPOOL_SLOTS CMDPOOL_SLOT_BASENAMES \
      CMDPOOL_WANT_ALL_SLOTS
}

# int cmdpool_manage_has_root ( **CMDPOOL_ROOT )
#
#  Returns 0 if %CMDPOOL_ROOT is set and exists (as dir),
#  and %CMDPOOL_EX_NOROOT otherwise.
#
cmdpool_manage_has_root() {
   if [ -n "${CMDPOOL_ROOT-}" ] && [ -d "${CMDPOOL_ROOT}" ]; then
      return 0
   else
      return ${CMDPOOL_EX_NOROOT}
   fi
}

# int cmdpool_manage_has_runcmd ( **X_CMDPOOL_RUNCMD= )
#
#  Returns 0 if the runcmd helper script (%X_CMDPOOL_RUNCMD) is set and
#  is an executable file, else %CMDPOOL_EX_NOHELPER.
#
cmdpool_manage_has_runcmd() {
   if \
      [ -n "${X_CMDPOOL_RUNCMD-}" ] && \
      [ -f "${X_CMDPOOL_RUNCMD}" ] && [ -x "${X_CMDPOOL_RUNCMD}" ]
   then
      return 0
   else
      cmdpool_log_error "runcmd helper script not available"
      return ${CMDPOOL_EX_NOHELPER}
   fi
}

# void cmdpool_manage_set_root ( root, **CMDPOOL_ROOT! ), raises die()
#
#  Sets %CMDPOOL_ROOT to the absolute filesystem path of %root (possibly
#  dereferenced).
#
#  Dies if the given cmdpool root is not valid, i.e. is empty, forbidden
#  ("/") or exists, but is not a directory.
#
cmdpool_manage_set_root() {
   if [ -z "${1-}" ]; then
      die "cmdpool root must not be empty." ${EX_USAGE?}

   elif ! get_fspath "${1}"; then
      die "failed to get fs path for cmdpool root '${1}'" ${EX_USAGE?}

   elif [ "${v0}" = "/" ]; then
      die "cmdpool root must not be '${v0}'" ${EX_USAGE?}

   elif [ -d "${v0}" ] || [ ! -e "${v0}" ]; then
      CMDPOOL_ROOT="${v0}"

   else
      die "cmdpool root '${1}' exists, but is not a dir." ${EX_USAGE?}
   fi
}

# void cmdpool_manage_set_runcmd ( runcmd, **X_CMDPOOL_RUNCMD! ), raises die()
#
#  Sets %X_CMDPOOL_RUNCMD. Dies if %runcmd is not valid.
#
cmdpool_manage_set_runcmd() {
   if [ -z "${1-}" ]; then
      die "cmdpool runcmd must not be empty." ${EX_USAGE?}

   elif ! get_fspath "${1}"; then
      die "failed to get fs path for cmdpool runcmd '${1}'" ${EX_USAGE?}

   elif [ -f "${v0}" ] && [ -x "${v0}" ]; then
      cmdpool_set_runcmd "${v0}"

   else
      die "'${1}' is not a runcmd script."
   fi
}


# void cmdpool_manage_set_slot ( slot, **CMDPOOL_SINGLE_SLOT! ), raises die()
#
#  Sets %CMDPOOL_SINGLE_SLOT, if not already set, else dies.
#  Also dies if %slot is empty.
#
cmdpool_manage_set_slot() {
   if [ -n "${CMDPOOL_SINGLE_SLOT-}" ]; then
      die "slot already set." ${EX_USAGE?}
   elif [ -z "${1-}" ]; then
      die "slot name must not be empty." ${EX_USAGE?}
   else
      CMDPOOL_SINGLE_SLOT="${1}"
   fi
}

# int cmdpool_manage_add_slots ( *slots, **CMDPOOL_SLOTS! ), raises die()
#
#  Adds a slot to the list of slot names (%CMDPOOL_SLOTS).
#  Dies if an invalid (empty) slot name is encountered.
#
#  Returns 0 if one or more slot names have been added, else 1.
#
cmdpool_manage_add_slots() {
   local any_slot
   while [ $# -gt 0 ]; do
      if [ -n "${1}" ]; then
         any_slot="${1}"
         CMDPOOL_SLOTS="${CMDPOOL_SLOTS-}${CMDPOOL_SLOTS:+ }${1}"
      else
         die "slot name must not be empty." ${EX_USAGE?}
      fi
      shift
   done
   [ -n "${any_slot-}" ]
}

# int cmdpool_manage_add_slot_basenames (
#    *names, **CMDPOOL_SLOT_BASENAMES!
# ), raises die()
#
#
#  Adds a slot to the list of slot basenames (%CMDPOOL_SLOT_BASENAMES)
#  An entry %e in this list is supposed to match any slot name that begins
#  with %e.
#  Dies if an invalid (empty) slot name is encountered.
#
#  Returns 0 if one or more slot basenames have been added, else 1.
#
cmdpool_manage_add_slot_basenames() {
   local any_name
   while [ $# -gt 0 ]; do
      if [ -n "${1}" ]; then
         any_slot="${1}"
         if [ -n "${CMDPOOL_SLOT_BASENAMES-}" ]; then
            CMDPOOL_SLOT_BASENAMES="${CMDPOOL_SLOT_BASENAMES} ${1}"
         else
            CMDPOOL_SLOT_BASENAMES="${1}"
         fi
      else
         die "slot basename must not be empty." ${EX_USAGE?}
      fi
   done
   [ -n "${any_name-}" ]
}

# int cmdpool_manage_want_all_slots (
#    want_all_if_unset=y, want_all_if_empty=n,
#    **CMDPOOL_SINGLE_SLOT=, **CMDPOOL_SLOTS=, **CMDPOOL_SLOT_BASENAMES=,
#    **CMDPOOL_WANT_ALL_SLOTS=n
# )
#
#  Returns 0 if
#    %CMDPOOL_WANT_ALL_SLOTS is set to 'y'
#  or
#    %want_all_if_unset is set to 'y' and none of %CMDPOOL_SINGLE_SLOT,
#    %CMDPOOL_SLOTS, %CMDPOOL_SLOT_BASENAMES are set
#  or
#    %want_all_if_empty is set to 'y' and any slot variable is not empty
#
#  Returns 1 otherwise.
#
cmdpool_manage_want_all_slots() {
   if [ "${CMDPOOL_WANT_ALL_SLOTS:-n}" = "y" ]; then
      return 0
   elif \
      [ -n "${CMDPOOL_SLOTS+X}${CMDPOOL_SLOT_BASENAMES+X}${CMDPOOL_SINGLE_SLOT+X}" ]
   then
      # at least one slot var is set
      if \
         [ "${2:-n}" != "y" ] || \
         [ -n "${CMDPOOL_SLOTS-}${CMDPOOL_SLOT_BASENAMES-}${CMDPOOL_SINGLE_SLOT-}" ]
      then
         return 1
      else
         return 0
      fi
   elif [ "${1:-y}" = "y" ]; then
      return 0
   else
      return 1
   fi
}
