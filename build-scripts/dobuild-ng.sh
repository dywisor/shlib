dobuild_writevars() {
   (
      DOBUILD_WRITEVARS=

      addvar() { DOBUILD_WRITEVARS="${DOBUILD_WRITEVARS} $*"; }
      ifdef() {
         local v
         local varname
         for varname; do
            eval "v=\"\${${varname:?}+SET}\"";
            if [ -n "${v}" ]; then
               addvar "${varname}"
            fi
         done
      }

      LANG=C
      LC_ALL=C

      RECIPE_ROOT=$( readlink -f "${PWD}" )
      PRJROOT_RECIPE="${PRJROOT}/files/recipe"

      USE="${USE-}${USE:+ }\${USE-}"
      : ${USE_REDUX:=y}

      addvar "LANG LC_ALL RECIPE_ROOT PRJROOT_RECIPE USE USE_REDUX"


      ifdef \
         D \
         TARGET_SHLIB_ROOT \
         TARGET_SHLIB_NAME \
         NO_COLOR PRINTCMD_QUIET PRINTMSG_QUIET \
         SCRIPT_OVERWRITE DEFAULT_SCRIPT_INTERPRETER SCRIPT_INTERPRETER

      writevars ${DOBUILD_WRITEVARS# }
   )
}

F_BUILDSCRIPT_PRE_CREATE=dobuild_writevars make_buildscript dobuild
[ $# -eq 0 ] || run_buildscript dobuild "$@"
