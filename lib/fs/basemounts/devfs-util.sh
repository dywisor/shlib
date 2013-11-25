#@LICENSE
#
# Copyright (C) 2013 Andre Erdmann <dywi@mailerd.de>
# Distributed under the terms of the GNU General Public License;
# either version 2 of the License, or (at your option) any later version.
#

# Some code, namely device mapper handling and blkid output parsing, is based
# on the ideas of Piotr Karbowski's storage-device mdev helper,
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

# @stdout int devfs__print_misc_dev_minor (
#    re_name, max_num_matches=1 **v0
# )
#
#  Prints the first max(1,%max_num_matches) minor device numbers of the
#  entries in /proc/misc that match %re_name.
#
devfs_print_misc_dev_minor() {
   #sed -n -r -e "1,${2:-1}!b" -e "s,^\s*([0-9]+)\s+(${1})$,\1,p" /proc/misc 2>/dev/null
   sed -n -r -e "1,${2:-1}{s,^\s*([0-9]+)\s+(${1})$,\1,p}" /proc/misc 2>/dev/null
}

# int devfs_get_misc_dev_minor ( name, **v0 )
#
#  Stores the minor device number of the first entry in /proc/misc
#  matching %name in %v0 and returns 0.
#
#  Returns 1 if no match found and sets %v0="" in that case.
#
devfs_get_misc_dev_minor() {
   #@safety_check : ${1:?}
   v0="$( devfs_print_misc_dev_minor "${1}" )"
   [ -n "${v0}" ]
}

# int devfs_do_blockdev ( dev, major, minor, **X_MKNOD=mknod, **MKNOD_OPTS= )
#
#  Creates a block dev if it doesn't exist.
#
devfs_do_blockdev() {
   if [ ! -b "${1}" ]; then
      rm -f -- "${1}"
      ${X_MKNOD:-mknod} ${MKNOD_OPTS-} "${1}" b "${2}" "${3}"
   fi
}

# int devfs_do_chardev ( dev, major, minor, **X_MKNOD=mknod, **MKNOD_OPTS= )
#
#  Creates a char dev if it doesn't exist.
#
devfs_do_chardev() {
   if [ ! -c "${1}" ]; then
      rm -f -- "${1}"
      ${X_MKNOD:-mknod} ${MKNOD_OPTS-} "${1}" c "${2}" "${3}"
   fi
}

# int devfs_create_device_mapper_node (
#    devfs=/dev, **X_MKNOD=mknod, **MKNOD_OPTS=
# )
#
#  Tries to create %devfs/mapper/control (if it doesn't exist).
#
#  Returns 0 if the device node exists or has been created, else non-zero.
#
devfs_create_device_mapper_node() {
   local v0
   local node="${1:-/dev}/mapper/control"

   if [ -c "${node}" ]; then
      return 0

   elif devfs_get_misc_dev_minor device-mapper; then
      if [ -d "${node%/*}" ]; then
         rm -f -- "${node}"
      elif ! dodir_minimal "${node%/*}"; then
         return 248
      fi

      ${X_MKNOD:-mknod} ${MKNOD_OPTS-} "${node}" c "10" "${v0}"
      return ${?}
   else
      return 249
   fi
}

# int devfs_get_uuid_label_unsafe (
#    dev, **X_BLKID=blkid, **UUID!, **LABEL!, **?!
# )
#
#  Gets %LABEL and %UUID for the given device.
#  Returns 0 if %UUID and/or %LABEL have been set (and aren't empty), else 1.
#
devfs_get_uuid_label_unsafe() {
   local TYPE PTTYPE PARTLABEL PARTUUID
   unset -v UUID LABEL
   local __out="$(${X_BLKID:-blkid} "${1}")"
   eval "${__out#*:}"
   : ${UUID=} ${LABEL=}
   [ -n "${UUID-}${LABEL-}" ]
}

# @private @stdout int devfs__subshell_print_uuid_label (
#    dev, **X_BLKID=blkid
# )
#
#  Evaluates the output of %X_BLKID(%dev) and prints the %UUID and %LABEL
#  variables to stdout (VARNAME="VALUE"). Excepts to be run in a subshell.
#
devfs__subshell_print_uuid_label() {
   devfs_get_uuid_label_unsafe "$@"
   echo "UUID=\"${UUID-}\""
   echo "LABEL=\"${LABEL-}\""
}

# int devfs_get_uuid_label ( dev, **X_BLKID=blkid, **UUID!, **LABEL! )
#
#  Gets %LABEL and %UUID for the given device.
#  Returns 0 if %UUID and/or %LABEL have been set (and aren't empty), else 1.
#
#  Doesn't leak any other vars from the blkid call, but needs a subshell.
#
devfs_get_uuid_label() {
   UUID=; LABEL=
   eval "$(devfs__subshell_print_uuid_label "$@")"
   [ -n "${UUID-}${LABEL-}" ]
}
