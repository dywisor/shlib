#@section functions

pack__genscript_header() {
   local I="${CMDWRAPPER_INDENT}"

   printf \
"#!/bin/sh -u
# *** generated script ***

# some functions
die() {
${I}echo \"died: \${1:-UNKNOWN}\" 1>&2
${I}exit \${2:-2}
}

autodie() {
${I}\"\${@}\" || die \"command '\${*}' returned \${?}\" \${?}
}

dodir() {
${I}[ -d \"\${1:?}\" ] || mkdir -p -- \"\${1}\" || [ -d \"\${1}\" ]
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

# int pack_main ( pack_src, pack_destfile, *cmdv )
#
pack_main() {
${I}local pack_src=\"\${1?}\"
${I}local pack_destfile=\"\${2?}\"
${I}local pack_destdir=\"\${pack_destfile}\"
${I}: \"\${pack_destdir:=/}\"
${I}pack_destdir=\"\${pack_destdir%%/}/\"

${I}shift 2 && [ -n \"\${*}\" ] || return

${I}# verify that pack_src exists / handle overwrite
${I}if [ ! -d \"\${pack_src}\" ]; then
${I}${I}die \"pack src \${pack_src} does not exist.\"\n"

   if [ "${PACK_OVERWRITE:-n}" = "y" ]; then
      # overwriting is allowed, add backup/removal code
      printf \
"${I}elif [ -e \"\${pack_destfile}\" ]; then
${I}${I}bakmove \"\${pack_destfile}\"
${I}elif [ -h \"\${pack_destfile}\" ]; then
${I}${I}echo \"removing broken symlink \${pack_destfile}\" 1>&2
${I}${I}autodie rm -- \"\${pack_destfile}\"\n"
   else
      # overwriting is forbidden, simply check whether pack_destfile exists
      printf \
"${I}elif [ -e \"\${pack_destfile}\" ] || [ -h \"\${pack_destfile}\" ]; then
${I}${I}die \"destfile \${pack_destfile} exists.\"\n"
   fi

   printf \
"${I}elif ! dodir \"\${pack_destdir}\"; then
${I}${I}die \"failed to create pack destdir \${pack_destdir}\"
${I}fi

${I}without_globbing_do \"\${@}\" || die \"failed to pack \${pack_src}\"
}\n\n"

   # may add some cleanup / fail recovery code here
}

pack__genscript_command() {
   local CMDWRAPPER_INDENT_NOW=

   local pack_type_name="${PACK_TYPE-}"
   case "${pack_type_name}" in
      'tar')
         pack_type_name="tarball"
      ;;
   esac

   printf "\n# pack ${PACK_SRC} to ${PACK_DESTFILE} as ${pack_type_name:-??}\n"
   if [ ${#} -gt 7 ]; then
      quote_cmdv_newline "pack_main" "${PACK_SRC}" "${PACK_DESTFILE}" "$@"
   else
      quote_cmdv "pack_main" "${PACK_SRC}" "${PACK_DESTFILE}" "$@"
   fi
   printf "\n"
}

pack__genscript__really() {
   if [ "${PACK_GENSCRIPT__HAVE_HEADER:-n}" != "y" ]; then
      pack__genscript_header
      PACK_GENSCRIPT__HAVE_HEADER=y
   fi
   pack__genscript_command "$@"
}

pack__genscript() {
   if [ "${PACK_GENSCRIPT__TO_FD3:-n}" = "y" ]; then
      pack__genscript__really "$@" >&3
   else
      pack__genscript__really "$@"
   fi
}

# int pack_genscript_open_fd ( file=**PACK_GENSCRIPT_DEST )
#
pack_genscript_open_fd() {
   PACK_GENSCRIPT__HAVE_HEADER=n
   exec 3>"${1:-${PACK_GENSCRIPT_DEST:?}}" || return
   PACK_GENSCRIPT__TO_FD3=y
}

# int pack_genscript_close_fd()
#
pack_genscript_close_fd() {
   if [ "${PACK_GENSCRIPT__TO_FD3:-n}" = "y" ]; then
      exec 3>&- || return
      PACK_GENSCRIPT__TO_FD3=n
      PACK_GENSCRIPT__HAVE_HEADER=n
   fi
}
