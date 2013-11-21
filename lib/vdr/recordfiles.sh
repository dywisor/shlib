#@section functions

# @private @stdout void vdr__print_all_record_file_names (
#    **VDR_RECORD_DIR, **VDR_RECORD_EXT
# )
#
vdr__print_all_record_file_names() {
   (
      set +f
      if cd "${VDR_RECORD_DIR}"; then
         fs_foreach_file_do echo ?*."${VDR_RECORD_EXT#.}"
      fi
   )
}

# @private @stdout void vdr__print_other_record_file_names (
#    **VDR_RECORD_DIR, **VDR_RECORD_EXT
# )
#
vdr__print_other_record_file_names() {
   (
      set +f

      # @lazy-bind <**VDR_RECORD_EXT> void __fsitem_emitter ( filename )
      #
      #  Echoes %filename if a %VDR_RECORD_EXT-specific conditions are met.
      #
      case "${VDR_RECORD_EXT#.}" in
         'ts')
            __fsitem_emitter() {
               case "${1}" in
                  [0-9][0-9][0-9][0-9][0-9]*".ts")
                     echo "${1}"
                  ;;
               esac
            }
         ;;
         'vdr')
            __fsitem_emitter() {
               case "${1}" in
                  [0-9][0-9][0-9]*".vdr")
                     echo "${1}"
                  ;;
               esac
            }
         ;;
         *)
            __fsitem_emitter() { echo "${1}"; }
         ;;
      esac

      if cd "${VDR_RECORD_DIR}"; then
         fs_foreach_file_do __fsitem_emitter ?*."${VDR_RECORD_EXT#.}"
      fi
   )
}

# @private @stdout void vdr__print_record_file_names (
#    **VDR_RECORD_DIR, **VDR_RECORD_EXT
# )
#
vdr__print_record_file_names() {
   (
      set +f

      if cd "${VDR_RECORD_DIR}"; then
         case "${VDR_RECORD_EXT#.}" in
            'ts')
               fs_foreach_file_do echo [0-9][0-9][0-9][0-9][0-9]*".ts"
            ;;
            'vdr')
               fs_foreach_file_do echo [0-9][0-9][0-9]*".vdr"
            ;;
            ?*)
               fs_foreach_file_do echo ?*".${VDR_RECORD_EXT#.}"
            ;;
         esac
      fi
   )
}

# int vdr_get_record_files (
#    type="default"
#    **VDR_RECORD_DIR, **VDR_RECORD_EXT, **v0!, **v1!
# )
#
#  Searches for record files in VDR_RECORD_DIR and stores their names in v0.
#  Also counts the # of record files and stores the result in v1.
#
vdr_get_record_files() {
   : ${VDR_RECORD_DIR?} ${VDR_RECORD_EXT?}
   v0=; v1=0;

   case "${1-}" in
      ''|'default')
         set -- $(vdr__print_record_file_names)
      ;;
      'all'|'any')
         set -- $(vdr__print_all_record_file_names)
      ;;
      'other'|'others')
         set -- $(vdr__print_other_record_file_names)
      ;;
      *)
         function_die \
            "unknown record file type '${1}'" "vdr_get_record_files"
      ;;
   esac

   v0="$*"; v1="$#";
   [ -n "${v0}" ]
}
