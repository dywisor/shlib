#@LICENSE
#
# Copyright (C) 2013 Andre Erdmann <dywi@mailerd.de>
# Distributed under the terms of the GNU General Public License;
# either version 2 of the License, or (at your option) any later version.
#

# The symlink db is inspired by Piotr Karbowski's storage-device mdev helper,
# its license follows.
#
# https://github.com/slashbeast/mdev-like-a-boss
#
#
# Copyright (c) 2012, Piotr Karbowski <piotr.karbowski@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice, this list
# of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
# * Neither the name of the Piotr Karbowski nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE US
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# This script meant to create /dev/disk/by-* and /dev/mapper/* symlinks.
# and remove them after storage device is removed.
# the /dev/disk/by-* handling based on the idea and proof of concept from BitJam.
#


#@section functions

#@result_var db_ref

# int symlink_db_init ( db_root, cat_prefix=, **_SYMLINK_DB! )
#
#  Initializes a symlink db at %db_root.
#
symlink_db_init() {
   _SYMLINK_DB="${1:?}"
   SYMLINK_DB_CAT_PREFIX="${2-}"
   dodir_minimal "${_SYMLINK_DB}"
}

# void symlink_db_set_cat_prefix ( cat_prefix=, **SYMLINK_DB_CAT_PREFIX! )
#
symlink_db_set_cat_prefix() {
   SYMLINK_DB_CAT_PREFIX="${1-}"
}

# int symlink_db_exists ( **_SYMLINK_DB= )
#
#  Returns 0 if %_SYMLINK_DB is set and exists, else 1.
#
symlink_db_exists() {
   [ -n "${_SYMLINK_DB-}" ] && [ -d "${_SYMLINK_DB}" ]
}

# @private int symlink_db__iter_entries_with_name ( name, func )
#
#  Actual iter_entries_with_name function.
#
symlink_db__iter_entries_with_name() {
   local db_ref db_relpath db_category

   for db_ref in "${_SYMLINK_DB}/${SYMLINK_DB_CAT_PREFIX-}"*"___"${1}; do
      if [ -e "${db_ref}" ]; then
         db_relpath="${db_ref#${_SYMLINK_DB}/}"
         db_category="${db_relpath%___*}"

         ${2:?} "${db_ref}" "${db_relpath##*___}" \
            "${db_category#${SYMLINK_DB_CAT_PREFIX-}}" || return ${?}
      fi
   done
   return 0
}

# int symlink_db_iter_entries_with_name (
#    name, func, **SYMLINK_DB_CAT_PREFIX, **_SYMLINK_DB
# )
#
#  Calls %func( db_ref, name, category, **db_category, **db_relpath, **db_ref )
#  for each entry in the symlink db whose category starts with
#  SYMLINK_DB_CAT_PREFIX (if set) and matches the given name.
#
#  Immediately passes func's return code if it is != 0.
#
symlink_db_iter_entries_with_name() {
   : ${2:?}
   [ -n "${1-}" ] && \
   with_globbing_do symlink_db__iter_entries_with_name "$@"
}

# @private void symlink_db__cleanup_recursive ( dir )
#
#  Actual cleanup function.
#
symlink_db__cleanup_recursive() {
   local f v0
   for f in "${1}/"*; do
      if [ -h "${f}" ]; then
         # symlink_db_cleanup() needs to be called twice in order to
         # remove all inner-db symlinks
         #
         if [ ! -e "${f}" ]; then
            #@debug_print symlink_db_cleanup: removing broken symlink \"${f}\"
            rm -f -- "${f}"
         #@debug else
            #@debug_print symlink_db_cleanup: cannot process \"${f}\": symlink
         fi

      elif [ -h "${f}.lock" ]; then
         # file/dir is locked, cant process it
         #@debug_print symlink_db_cleanup: cannot process \"${f}\": locked
         true

      elif [ -f "${f}" ]; then
         v0="$(cat "${f}" 2>/dev/null)"
         if [ -n "${v0}" ] && [ ! -e "${v0}" ]; then
            # drop entry + broken symlink (if any)
            #@debug_print symlink_db_cleanup: removing orphaned entry \"${f}\"
            rm -f -- "${f}" "${v0}"
         fi

      elif [ -d "${f}" ]; then
         # resolve by recursion
         symlink_db__cleanup_recursive "${f}"
      fi
   done
}

# void symlink_db_cleanup ( **_SYMLINK_DB= )
#
#  Removes entries whose symlinks do no longer exist.
#
#  Notes:
#  * empty and locked entries won't get removed
#
symlink_db_cleanup() {
   if symlink_db_exists; then
      with_globbing_do \
         symlink_db__cleanup_recursive "${_SYMLINK_DB}"
   fi
}

# int symlink_db_get_location (
#    name, category, **SYMLINK_DB_CAT_PREFIX=, **_SYMLINK_DB, **db_ref!
# )
#
#  Determines the filesystem location where information for
#  %category's %name would/should be stored and returns it via %db_ref.
#
#  %name and %category must not be empty.
#
#  Returns 0 if the db entry exists (test -e), else 1.
#
symlink_db_get_location() {
   # structured db (subdirs)
   #db_ref="${_SYMLINK_DB:?}/${SYMLINK_DB_CAT_PREFIX-}${2:?}/${1:?}"

   # flat db (3 underscore chars separate category/name)
   db_ref="${_SYMLINK_DB:?}/${SYMLINK_DB_CAT_PREFIX-}${2:?}___${1:?}"

   [ -e "${db_ref}" ]
}

# void symlink_db_read_entry_by_ref ( db_ref, *args_ignored, **v0! )
#
symlink_db_read_entry_by_ref() {
   v0="$( cat "${1}" 2>/dev/null )"
   return 0
}

# int symlink_db_read_entry (
#    name, category, **SYMLINK_DB_CAT_PREFIX=, **_SYMLINK_DB,
#    **db_ref!, **v0!
# )
#
#  Reads %category's entry for %name and stores its content in %v0.
#  Also passes the %db_ref from symlink_db_get_location().
#
#  Returns 0 if %db_ref was a non-empty file, else 1.
#
symlink_db_read_entry() {
   v0=
   symlink_db_get_location "${1:?}" "${2:?}" && [ -f "${db_ref}" ] && \
      symlink_db_read_entry_by_ref "${db_ref}"
}

# int symlink_db_write_entry_by_ref ( db_ref, text= )
#
symlink_db_write_entry_by_ref() {
   if ! dodir_minimal "${1%/*}"; then
      return 2
   elif ! ln -ns -- . "${1}.lock" 2>/dev/null; then
      return 3
   else
      local rc=0
      echo "${2-}" > "${1}" || rc=$?
      rm -f -- "${1}.lock"
      return ${rc}
   fi
}

# int symlink_db_write_new_entry_by_ref ( db_ref, text=)
#
symlink_db_write_new_entry_by_ref() {
   if ! dodir_minimal "${1%/*}"; then
      return 2
   elif ! ln -ns -- . "${1}.lock" 2>/dev/null; then
      return 3
   else
      local rc=0
      if [ -e "${1}" ]; then
         #@debug_print symlink_db_write_new_entry_by_ref(): entry \"${1}\" exists
         rc=1
      else
         #@debug_print symlink_db_write_new_entry_by_ref(): creating new entry \"${1}\"
         echo "${2-}" > "${1}" || rc=$?
      fi
      rm -f -- "${1}.lock"
      return ${rc}
   fi
}

# int symlink_db_write_entry (
#    name, category, text=, **_SYMLINK_DB, **db_ref!
# )
#
#  Writes %text to the %name entry in %category.
#  Locks the entry before writing to it and releases the lock afterwards.
#
#  Returns 0 if the entry has been (re-)written, else non-zero.
#
symlink_db_write_entry() {
   symlink_db_get_location "${1:?}" "${2:?}" || true
   symlink_db_write_entry_by_ref "${db_ref}" "${3-}"
}

# int symlink_db_write_new_entry (
#    name, category, text=, **_SYMLINK_DB, **db_ref!
# )
#
#  Writes %text to the %name entry in %category IFF the entry does not exist.
#  Locks the entry before writing to it and releases the lock afterwards.
#
#  Returns 0 if the entry has been written, else non-zero.
#
symlink_db_write_new_entry() {
   if ! symlink_db_get_location "${1:?}" "${2:?}"; then
      symlink_db_write_new_entry_by_ref "${db_ref}" "${3-}"
   else
      #@debug_print symlink_db_write_new_entry(): \"${db_ref}\" exists
      return 20
   fi
}

# void symlink_db_purge_last_lock ( **db_ref= )
#
#  Forcefully removes %db_ref's lock.
#
symlink_db_purge_last_lock() {
   [ -z "${db_ref-}" ] || rm -f "${db_ref}"
}

# int symlink_db_purge_entry_by_ref ( db_ref:=**db_ref, *args_ignored )
#
#  Purges an entry referenced by %db_ref.
#  Returns 0 if the entry does not exist (at the end of this function),
#  else non-zero.
#
#  Note: you can actually purge locks with this function - use with care
#
symlink_db_purge_entry_by_ref() {
   local my_ref="${1:-${db_ref-}}"

   if [ -z "${my_ref-}" ]; then
      return 2
   elif [ ! -e "${my_ref}" ] && [ ! -h "${my_ref}" ]; then
      return 0
   elif ! ln -ns -- . "${my_ref}.lock" 2>/dev/null; then
      return 3
   else
      local rc=0
      if rm -- "${my_ref}" 2>/dev/null; then
         true
      elif [ -e "${my_ref}" ] || [ -h "${my_ref}" ]; then
         # failed to remove entry
         rc=1
      fi
      rm -f "${my_ref}.lock"
      return ${rc}
   fi
}

# int symlink_db_purge_entry (
#    name, category, **_SYMLINK_DB, **db_ref!
# )
#
#  Sets %db_ref and calls symlink_db_purge_entry_by_ref() afterwards.
#
symlink_db_purge_entry() {
   symlink_db_get_location "$@" || return 0
   symlink_db_purge_entry_by_ref
}


# int symlink_db_remove_symlink_by_ref ( db_ref, link_target= )
#
symlink_db_remove_symlink_by_ref() {
   : ${1:?}
   local rc v0

   ln -ns -- . "${1}.lock" 2>/dev/null || return 3

   if ! symlink_db_read_entry_by_ref "${1}"; then
      rc=1
   elif [ -z "${v0-}" ] || [ ! -h "${v0}" ]; then
      rc=2
   elif \
      [ -n "${2-}" ] && [ "$(readlink "${v0}" 2>/dev/null)" != "${2}" ]
   then
      #@debug_print link \"${v0}\", but does not point to \"${2}\"
      rc=4
   elif rm -f -- "${v0}"; then
      #@debug_print removed link \"${v0}\"
      rm -f -- "${1}"
      rc=0
   else
      #@debug_warn failed to remove link \"${v0}\"
      rc=5
   fi

   rm -f -- "${1}.lock"
   return ${rc}
}

# int symlink_db_create_new_symlink (
#    db_name, db_category, link_dest, link, **db_ref!
# )
#
#  Registers a symlink %link->%link_dest as new entry (old entries won't
#  get overwritten) and, if successful, runs "ln -snf %link_dest %link".
#
symlink_db_create_new_symlink() {
   : ${1:?} ${2:?} ${3:?} ${4:?}
   #@debug_print symlink_db_create_new_symlink():
   #@debug_print * db_name     = \"${1}\"
   #@debug_print * db_category = \"${2}\"
   #@debug_print * link_dest   = \"${3}\"
   #@debug_print * link        = \"${4}\"
   [ ! -d "${4}" ] || [ -h "${4}" ] || return 1

   local link_dir="${4%/*}"

   if [ -n "${link_dir}" ] && [ "${link_dir}" != "${4}" ]; then
      dodir_minimal "${link_dir}" || return 2
   fi


   if ! symlink_db_write_new_entry "${1}" "${2}" "${4}"; then
      return 3

   elif [ -e "${4}" ]; then
      # another process created %link, don't claim it
      symlink_db_purge_entry_by_ref
      db_ref=
      return 4

   elif ln -snf ${LN_OPT_NO_TARGET_DIR-} -- "${3}" "${4}"; then
      #@debug_print symlink_db_create_new_symlink(): created \"${4}\"
      return 0
   else
      symlink_db_purge_entry_by_ref
      db_ref=
      return 5
   fi
}
