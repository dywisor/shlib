# get_blocklist.sh
#
# download blocklist files from list.iblocklist.com into a temporary dir,
# extract them and move the blocklist file into the destination dir.
#
# The syntax of a blocklist file is as follows:
#
# <blocklist remote name|blocklist uri> [ => <local name>]
#
# (without the leading "# ")
#
# Example:
#
# bt_level1 => level1
# bt_level2 => level2
# bt_level3 => level3
#
# This will (try to) fetch the level 1..3 lists.
#

readconfig_optional_search "${SCRIPT_NAME}"

: ${BLOCKLIST_FORMAT:=p2p}
: ${BLOCKLIST_COMPRESSION:=gz}
: ${BLOCKLIST_REMOTE:=http://list.iblocklist.com}
: ${WGET_QUIET:=y}

HELP_DESCRIPTION="get blocklists"
HELP_BODY=""

HELP_USAGE="Usage: ${SCRIPT_FILENAME} [option...] <blocklist_file> <distdir>"

HELP_OPTIONS="
--fileformat   (-F) -- set the list format (default: ${BLOCKLIST_FORMAT})
--compression  (-C) -- set the archive format (default: ${BLOCKLIST_COMPRESSION})
--remote       (-R) -- set the remote (default ${BLOCKLIST_REMOTE})
--infile       (-i) -- set <blocklist_file>
--outdir       (-O) -- set <distdir>
--config       (-c) -- load config file
--transmission,
--remove-bin        -- remove <list>.bin files in distdir for each fetched <list>
"

# void blocklist_set_infile ( file ), raises die()
#
#  Sets and verifies BLOCKLIST_FILE.
#
blocklist_set_infile() {
   if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
      die "no such blocklist file: '${1-}'"
   else
      BLOCKLIST_FILE="${1}"
   fi
}

# void blocklist_set_distdir ( dir ), raises die()
#
#  Sets and verifies BLOCKLIST_DISTDIR.
#
blocklist_set_distdir() {
   if [ -z "${1-}" ]; then
      die "blocklist distdir must not be empty."
   elif [ -d "${1}" ]; then
      touch "${1}" 2>/dev/null || die "distdir '${1}' is not writable."
      BLOCKLIST_DISTDIR="${1}"
   elif [ -e "${1}" ]; then
      die "blocklist distdir '${1}' exists, but is not a directory."
   else
      BLOCKLIST_DISTDIR="${1}"
   fi
}

# int blocklist_update_file (
#    distfile, distfile_name, **BLOCKLIST_REMOVE_BIN, **BLOCKLIST_DISTDIR
# )
#
#  Transfers a list file to BLOCKLIST_DISTDIR.
#
blocklist_update_file() {
   dest="${BLOCKLIST_DISTDIR}/${2:?}"

   # this may be transmission specific, but shouldn't do much harm
   if yesno "${BLOCKLIST_REMOVE_BIN:-n}"; then
      rm -f "${dest}.bin"
   fi

   if __verbose__; then
      if [ -e "${dest}" ]; then
         einfo "Replacing list: ${dest}"
      else
         einfo "New list: ${dest}"
      fi
   fi
   mv "${1:?}" "${dest}"
}

# @argparse_handle argparse_break (...)
#
#  Ignored.
#
argparse_break() { return 0; }

# @argparse_handle argparse_arg (...)
#
argparse_arg() {
   if [ -z "${ARG0-}" ]; then
      ARG0="${arg}"
   elif [ -z "${ARG1-}" ]; then
      ARG1="${arg}"
   else
      die "${SCRIPT_NAME} takes up to 2 positional args, but got at least three."
   fi
}

# @argparse_handle argparse_longopt (...)
#
argparse_longopt() {
   case "${longopt?}" in
      'fileformat')
         argparse_need_arg "$@"
         BLOCKLIST_FORMAT="${1}"
      ;;
      'compression')
         argparse_need_arg "$@"
         BLOCKLIST_COMPRESSION="${1}"
      ;;
      'remote')
         argparse_need_arg "$@"
         BLOCKLIST_REMOTE="${1}"
      ;;
      'infile')
         argparse_need_arg "$@"
         blocklist_set_infile "${1}"
      ;;
      'outdir')
         argparse_need_arg "$@"
         blocklist_set_distdir "${1}"
      ;;
      'config')
         argparse_need_arg "$@"
         readconfig "${1}"
      ;;
      'remove-bin'|'transmission')
         BLOCKLIST_REMOVE_BIN=y
      ;;
      *)
         argparse_unknown
      ;;
   esac
}

# @argparse_handle argparse_shortopt (...)
#
argparse_shortopt() {
   case "${shortopt?}" in
      'F')
         argparse_need_arg "$@"
         BLOCKLIST_FORMAT="${1}"
      ;;
      'C')
         argparse_need_arg "$@"
         BLOCKLIST_COMPRESSION="${1}"
      ;;
      'R')
         argparse_need_arg "$@"
         BLOCKLIST_REMOTE="${1}"
      ;;
      'i')
         argparse_need_arg "$@"
         blocklist_set_infile "${1}"
      ;;
      'O')
         argparse_need_arg "$@"
         blocklist_set_distdir "${1}"
      ;;
      'c')
         argparse_need_arg "$@"
         readconfig "${1}"
      ;;
      *)
         argparse_unknown
      ;;
   esac
}

# @implicit int main (...)
#
#  Parse args, fetch blocklists and put them into BLOCKLIST_DISTDIR.
#

argparse_autodetect
argparse_parse "$@"


if [ -z "${BLOCKLIST_FILE-}" ]; then

   if [ -n "${ARG0-}" ]; then
      blocklist_set_infile "${ARG0}"
   else
      die "<blocklist_file> not specified."
   fi

   if [ -z "${BLOCKLIST_DISTDIR-}" ]; then
      if [ -n "${ARG1-}" ]; then
         blocklist_set_distdir "${ARG1}"
      else
         die "<distdir> not specified."
      fi
   fi

elif [ -z "${BLOCKLIST_DISTDIR-}" ]; then

   if [ -n "${ARG0-}" ]; then
      blocklist_set_distdir "${ARG0}"
   else
      die "<distdir> not specified."
   fi

fi

# double-check, these variables could have been read from a config file
blocklist_set_distdir "${BLOCKLIST_DISTDIR}"
blocklist_set_infile "${BLOCKLIST_FILE}"

if __debug__; then
   WGET_QUIET=n
elif __quiet__; then
   WGET_QUIET=y
fi

dodir_clean "${BLOCKLIST_DISTDIR}" || \
   die "Cannot create distdir '${BLOCKLIST_DISTDIR}'!"

get_tmpdir ${SCRIPT_NAME}_$$ || die "Cannot create temporary distdir!"

BLOCKLIST_TMPDIR="${T}"

einfo "Fetching blocklist files ..."

DISTDIR="${BLOCKLIST_TMPDIR}" \
FETCH_URI_PREFIX="${BLOCKLIST_REMOTE}/?list=" \
FETCH_URI_SUFFIX="&fileformat=${BLOCKLIST_FORMAT}&archiveformat=${BLOCKLIST_COMPRESSION}" \
FETCH_UNCOMPRESS="${BLOCKLIST_COMPRESSION}" \
F_FETCH_ON_SUCCESS="blocklist_update_file" \
fetch_list_from_file "${BLOCKLIST_FILE}"

[ "${FETCH_FAIL:-n}" != "y" ] || \
   die "At least one blocklist could not be processed properly." 2
