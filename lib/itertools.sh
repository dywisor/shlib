#@section header

# itertools
#  create/parse lists and entities that can be perceived as such,
#  e.g. directory/filesystem trees, file text lines, ...
#

#@section functions_export
# @extern int list_has ( word, *list_items )


#@section functions
# @private int __itertools_kw_is_not ( word, **kw )
#
#  Returns true if kw != word else false.
#
__itertools_kw_is_not() {
   [ "x${kw?}" != "x$*" ]
}


#@section functions

# void generic_iterator (
#    item_separator, *words,
#    **F_ITER=echo, **ITER_SKIP_EMPTY=y, **ITER_UNPACK_ITEM=n,
#    **F_ITER_ON_ERROR=return
#
# )
# DEFINES @iterator <item_separator> <iterator_name>
#
#  Iterates over a list of items separated by item_separator.
#  All words are interpreted as "one big list".
#
#  Calls F_ITER ( item ) for each item and F_ITER_ON_ERROR() if F_ITER
#  returns a non-zero value.
#  The items will be unpacked if ITER_UNPACK_ITEM is set to 'y',
#  otherwise the item is interpreted as one word (default 'n').
#
#  Empty items will be ignored if ITER_SKIP_EMPTY is set to 'y', which
#  is the default behavior.
#
#  Examples: see the specific iterator functions below.
#
generic_iterator() {
   local item
   local IFS="${1?}"
   shift
   set -- $*
   IFS="${IFS_DEFAULT?}"

   if [ "${ITER_SKIP_EMPTY:-y}" = "y" ]; then
      if [ "${ITER_UNPACK_ITEM:-n}" = "y" ]; then
         for item; do
            if [ -n "${item}" ]; then
               ${F_ITER:-echo} ${item} || ${F_ITER_ON_ERROR:-return}
            fi
         done
      else
         for item; do
            if [ -n "${item}" ]; then
               ${F_ITER:-echo} "${item}" || ${F_ITER_ON_ERROR:-return}
            fi
         done
      fi

   elif [ "${ITER_UNPACK_ITEM:-n}" = "y" ]; then
      for item; do
         ${F_ITER:-echo} ${item} || ${F_ITER_ON_ERROR:-return}
      done

   else
      for item; do
         ${F_ITER:-echo} "${item}" || ${F_ITER_ON_ERROR:-return}
      done

   fi

   return 0
}
# --- end of generic_iterator (...) ---

# void itertools_print_item ( item )
#
#  Prints a string representation of an item. Meant for testing.
#
itertools_print_item() {
   if [ -z "${2-}" ]; then
      echo "item<${*}>"
   else
      echo "items<${*}>"
   fi
}

# void itertools_print_fs_item ( item )
#
#  Prints a string representation of a filesystem item (file/dir).
#
itertools_print_fs_item() {
   echo "fs_item<path='${1-}' parent_dir='${2-}' name='${3-}' type='${4-}'>"
}

# void eval_iterator ( func_name, item_separator )
#
#  Creates @iterator functions.
#
eval_iterator() {
   eval "${1:?}() { generic_iterator \"${2?}\" \"\$@\"; }"
}

# @iterator <newline> line_iterator
line_iterator() {
   generic_iterator "${IFS_NEWLINE?}" "$@"
}
# @iterator "," list_iterator
list_iterator() {
   generic_iterator "," "$@"
}
# @iterator ":" colon_iterator
colon_iterator() {
   generic_iterator ":" "$@"
}
# @iterator "." dot_iterator
dot_iterator() {
   generic_iterator "." "$@"
}
# @iterator <default> default_iterator
default_iterator() {
   generic_iterator "${IFS_DEFAULT?}" "$@"
}


# @iterator <file> file_iterator ( **ITER_SKIP_COMMENT=y )
#
#  Reads zero or more files and calls F_ITER for each line.
#
file_iterator() {
   local line
   while [ $# -gt 0 ]; do
      if [ -f "${1:?}" ]; then
         while read line; do
            if [ -z "${line}" ] && [ "${ITER_SKIP_EMPTY:-y}" = "y" ]; then
               true
            elif \
               [ "${ITER_SKIP_COMMENT:-y}" = "y" ] && \
               [ "x${line#\#}" != "x${line}" ]
            then
               true
            elif [ "${ITER_UNPACK_ITEM:-n}" = "y" ]; then
               ${F_ITER:-echo} ${line}   || ${F_ITER_ON_ERROR:-return}
            else
               ${F_ITER:-echo} "${line}" || ${F_ITER_ON_ERROR:-return}
            fi
         done < "${1}"
      else
         ${F_ITER_ON_ERROR:-return} 40
      fi
      shift
   done
}

# ~int file_list_iterator ( f_iter, *file )
#  WRAPS file_iterator ( *file )
#
#  Reads zero or more list files (one item per line, ignore empty items,
#  ignore comments) and calls f_iter for each item.
#
file_list_iterator() {
   local F_ITER="${1:?}"; shift;

   ITER_UNPACK_ITEM=n ITER_SKIP_COMMENT=y ITER_SKIP_EMPTY=y file_iterator "$@"
}


# @iterator <filesystem> fs_iterator (
#    *dirs,
#    ...,
#    **F_ITER_DIR_MISSING=function_die
# )
#
# For each <dir> in dirs:
#  Iterates over the entries of a filesystem tree starting at <dir>.
#
#
fs_iterator() {
   local d
   for d; do
      if [ -d "${d%/}/" ]; then
         line_iterator "$( find ${d%/}/ )"
      elif [ -n "${F_ITER_DIR_MISSING-}" ]; then
         ${F_ITER_DIR_MISSING} "${d%/}"
      else
         function_die "no such directory: ${d}"
      fi
   done
}


# void dir_iterator (
#    *dirs,
#    **F_ITER=echo,
#    **F_ITER_FILE=(F_ITER),
#    **F_ITER_DIR=(F_ITER),
#    **F_ITER_ON_ERROR=return,
#    **F_ITER_DIR_MISSING=function_die,
#    **ITER_IGNORE_SYMLINK=n,
#    **ITER_ABSPATH=y,
#    **ITER_ENTRY_PREFIX="",
#    **ITER_ENTRY_SUFFIX="",
# )
# DEFINES @dir_iterator <fixed keywords> <function name> (
#    *dirs,
#    <variable keywords>
# )
#
# Iterates over the content of zero or more directories and calls
# F_ITER_FILE / F_ITER_DIR / F_ITER for each file / dir / ...
#
# Each item function (F_ITER*) has to accept 4 args,
# 1: path to the item
# 2: path to the directory containing the item
# 3: the item's name
# 4: the item's type "file" for file, "dir" for directory, "" for unknown
#
# Not recursive.
#
dir_iterator() {
   local d f
   while [ $# -gt 0 ]; do
      if [ -n "${1}" ]; then
         if [ "${ITER_ABSPATH:-y}" = "y" ]; then
            d=$(readlink -f "${1}")
         else
            d="${1}"
         fi

         if [ -d "${d}" ]; then

            for f in "${d}"/${ITER_ENTRY_PREFIX-}*${ITER_ENTRY_SUFFIX-}; do
               if [ "$f" != "${d}/${ITER_ENTRY_PREFIX-}*${ITER_ENTRY_SUFFIX-}" ]; then
                  # else empty dir
                  if \
                     [ -h "${f}" ] && [ "${ITER_IGNORE_SYMLINK:-n}" = "y" ]
                  then
                     true
                  elif [ -f "${f}" ]; then
                     ${F_ITER_FILE:-${F_ITER:-echo}} \
                        "${f}" "${d}" "${f##*/}" "file"

                  elif [ -d "${f}" ]; then
                     ${F_ITER_DIR:-${F_ITER:-echo}} \
                        "${f}" "${d}" "${f##*/}" "dir"
                  elif [ -n "${F_ITER-}" ]; then
                     # char/block dev, broken symlinks, ...
                     ${F_ITER} "${f}" "${d}" "${f##*/}" ""
                  fi
               fi
            done

         elif [ -n "${F_ITER_DIR_MISSING:-}" ]; then
            ${F_ITER_DIR_MISSING} "${1}" "${d}"
         else
            function_die "no such directory: ${1}"
         fi
      fi
      shift
   done
}

# @dir_iterator F_ITER_DIR=<self> recursive_dir_iterator ( dir )
#
recursive_dir_iterator() {
   F_ITER_DIR=recursive_dir_iterator dir_iterator "${1:?}"
}

# int linelist_has ( word, list )
#
#  Returns true if word is in the given list (list items separated by
#  a newline char) else false.
#
linelist_has() {
   local kw="${1:-}"
   shift && F_ITER=__itertools_kw_is_not line_iterator "$@" || return 0
   return 1
}


# void generic_list_join (
#    item_separator, *items,
#    **LIST_JOIN_STDOUT=n, **LIST_JOIN_SKIP_EMPTY=y
# )
# DEFINES @list_join <item_separator> <function_name>
#
#  Joins zero or more items and stores the resulting list in %v0
#  if LIST_JOIN_STDOUT is not set to 'y', else echoes it.
#
generic_list_join() {
   local sep="${1?}" result=""
   shift
   while [ $# -gt 0 ]; do
      if [ -n "${1}" ] || [ "${LIST_JOIN_SKIP_EMPTY:-y}" != "y" ]; then
         if [ -n "${result}" ]; then
            result="${result}${sep}${1}"
         else
            result="${1}"
         fi
      fi
      shift
   done
   if [ "${LIST_JOIN_STDOUT:-n}" = "y" ]; then
      echo "${result}"
   else
      v0="${result}"
   fi
}


# void eval_list_join ( func_name, item_separator )
#
#  Creates @list_join functions.
#
eval_list_join() {
   eval "${1:?}() { generic_list_join \"${2?}\" \"\$@\"; }"
}
