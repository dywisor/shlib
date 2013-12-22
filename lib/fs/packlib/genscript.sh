#@section functions

pack__genscript() {
   local pack_destdir="${PACK_DESTFILE%/*}"
   : ${pack_destdir:=/}
   pack_destdir="${pack_destdir%/}/"

   local CMDWRAPPER_INDENT_NOW
   local I="${CMDWRAPPER_INDENT}"

   local pack_type_name="${PACK_TYPE-}"
   case "${pack_type_name}" in
      'tar')
         pack_type_name="tarball"
      ;;
   esac

   printf \
"#!/bin/sh -u
# *** generated script ***
#  packs ${PACK_SRC:-??} to ${PACK_DESTFILE:-??} as ${pack_type_name:-??}

# some functions
die() {
${I}echo \"died: \${1:-UNKNOWN}\" 1>&2
${I}exit \${2:-2}
}

autodie() {
${I}\"\${@}\" || die \"command '\${*}' returned \${?}\" \${?}
}

dodir() {
${I}[ -d \"\${1:?}\" ] || mkdir -p -- \"\${1}\" || [ -d \"\${1:?}\" ]
}

bakmove() {
${I}autodie mv -vf -- \"\${1:?}\" \"\${1:?}.bak\"
}

catch_ret() { rc=-1; \"\${@}\"; rc=\${?}; }

without_globbing_do() {
${I}if [ \"\${-#*f}\" != \"\${-}\" ]; then
${I}${I}\"\${@}\"
${I}else
${I}${I}local rc
${I}${I}set +f
${I}${I}catch_ret \"\${@}\"
${I}${I}set -f
${I}${I}return \${rc}
${I}fi
}

# the main function
pack_main() {
${I}# verify that PACK_SRC exists / handle overwrite
${I}if [ ! -d \"${PACK_SRC}\" ]; then
${I}${I}die \"pack src ${PACK_SRC} does not exist.\"\n"

   if [ "${PACK_OVERWRITE:-n}" = "y" ]; then
      # overwriting is allowed, add backup/removal code
      printf \
"${I}elif [ -e \"${PACK_DESTFILE}\" ]; then
${I}${I}bakmove \"${PACK_DESTFILE}\"
${I}elif [ -h \"${PACK_DESTFILE}\" ]; then
${I}${I}echo \"removing broken symlink ${PACK_DESTFILE}\" 1>&2
${I}${I}autodie rm -- \"${PACK_DESTFILE}\"\n"
   else
      # overwriting is forbidden, simply check whether PACK_DESTFILE exists
      printf \
"${I}elif [ -e \"${PACK_DESTFILE}\" ] || [ -h \"${PACK_DESTFILE}\" ]; then
${I}${I}die \"destfile ${PACK_DESTFILE}\" exists.\"\n"
   fi

   printf \
"${I}elif ! dodir \"${pack_destdir}\"; then
${I}${I}die \"failed to create pack destdir ${pack_destdir}\"
${I}fi
\n"

   CMDWRAPPER_INDENT_NOW="${I}"
   if [ ${#} -gt 7 ]; then
      quote_cmdv_newline "$@"
   else
      quote_cmdv "$@"
   fi
   printf " || return\n"
   CMDWRAPPER_INDENT_NOW=

   # may add some cleanup / fail recovery code here (and replace "|| return")

   printf \
"}
\n
if [ \"\${PACKSCRIPT_AS_LIB:-n}\" != \"y\" ]; then
${I}pack_main \"\${@}\"
${I}exit \${?}
fi\n"

}
