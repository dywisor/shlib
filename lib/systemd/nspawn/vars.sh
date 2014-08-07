#@section functions

systemd_nspawn_set_root_dir() {
   SYSTEMD_NSPAWN_ROOT_DIR="${1?}"
   SYSTEMD_NSPAWN_ROOT_IMAGE=
   [ -n "${SYSTEMD_NSPAWN_ROOT_DIR}" ] && [ -d "${SYSTEMD_NSPAWN_ROOT_DIR}" ]
}

systemd_nspawn_set_root_image() {
   SYSTEMD_NSPAWN_ROOT_DIR=
   SYSTEMD_NSPAWN_ROOT_IMAGE="${1?}"
   [ -n "${SYSTEMD_NSPAWN_ROOT_IMAGE}" ] && \
   [ -f "${SYSTEMD_NSPAWN_ROOT_IMAGE}" ]
}

# void systemd_nspawn_get_root_opt(...), raises function_die()
#
systemd_nspawn_get_root_opt() {
   root_opt=
   root_val=

   if [ -n "${SYSTEMD_NSPAWN_ROOT_DIR-}" ]; then
      if [ -n "${SYSTEMD_NSPAWN_ROOT_IMAGE-}" ]; then
         function_die "both root dir and root image are set!" \
            "systemd_nspawn_get_root_opt()"

      else
         root_opt="-D"
         root_val="${SYSTEMD_NSPAWN_ROOT_DIR}"
      fi

   elif [ -n "${SYSTEMD_NSPAWN_ROOT_IMAGE-}" ]; then
      root_opt="-i"
      root_val="${SYSTEMD_NSPAWN_ROOT_IMAGE}"

   else
      function_die "neither root dir nor root image are set!" \
         "systemd_nspawn_get_root_opt()"
   fi
}

# @private systemd_nspawn__list_add_colon_option (
#    list_name, option, value1[, value2]
# )
#
systemd_nspawn__list_add_colon_option() {
   case "${4-}" in
      ''|'${3}')
         systemd_nspawn__append_${1:?} "${2:?}" "${3:?}"
      ;;
      *)
         systemd_nspawn__append_${1:?} "${2:?}" "${3:?}:${4}"
      ;;
   esac
}

# void systemd_nspawn_add_bind_mount_ro ( from[, to] )
#
#  Appends a readonly bind mount to the list of bind mounts.
#
systemd_nspawn_add_bind_mount_ro() {
   systemd_nspawn__list_add_colon_option bind '--bind-ro' "${@}"
}

# void systemd_nspawn_add_bind_mount_rw ( from[, to] )
#
#  Appends a read-write bind mount to the list of bind mounts.
#
systemd_nspawn_add_bind_mount_rw() {
   systemd_nspawn__list_add_colon_option bind '--bind' "${@}"
}

# void systemd_nspawn_add_tmpfs_mount ( mount_point[, mount_opts] )
#
#  Appends a tmpfs mount to the list of tmpfs mounts.
#
systemd_nspawn_add_tmpfs_mount() {
   systemd_nspawn__list_add_colon_option tmpfs '--tmpfs' "${@}"
}

# void systemd_nspawn_add_network_options ( *options )
#
#  Appends network-related options to the "net" list.
#
#  Use this function for systemd-nspawn switches not covered by any other
#  functions, e.g. --user, --boot, --journal, --context, ...
#
systemd_nspawn_add_network_options() {
   [ ${#} -eq 0 ] || systemd_nspawn__append_net "${@}"
}

# void systemd_nspawn_add_options ( *options )
#
#  Adds arbitrary options to the "misc" list.
#
systemd_nspawn_add_options() {
   [ ${#} -eq 0 ] || systemd_nspawn__append_misc "${@}"
}

# void systemd_nspawn_add_bind_mounts ( *definition ), raises function_die()
#
#  Appends several bind mount definitions to the list of bind mounts.
#
#  A definition can be any of:
#  * <from>[:<to>]  -- bind-mount <from> to <to> (:=<from>)
#                      (refer to "man systemd-nspawn")
#  * @ro            -- make all following bind mounts readonly
#  * @rw            -- make all following bind mounts read+writable (default)
#  * @<from>[:<to>] -- (un-)sets from/to prefix directories,
#                       which cause all following "<a>[:<b>]" statements to
#                       behave as if <from><a>:<to><b> have been given
#
#                       Note: Prefixes must be absolute paths
#
#  * @, @:          -- special case that clears the from/to prefixes
#  * '' (empty str) -- ignored
#  * #*             -- ignored
#
# "@*", "/:*", "*:/" and "*:*:*" statements are illegal, which causes
#  this function to die (function_die()).
#
#  Example:
#     systemd_nspawn_add_bind_mounts \
#        @rw @/machines/data:/data /shared \
#        @ro /src:/src-ro
#
#   Bind-mounts /machines/data/shared -> <chroot>/data/shared in read-write
#   mode and /machines/data/src -> <chroot>/data/src-ro readonly
#
systemd_nspawn_add_bind_mounts() {
   local ro_flag from_prefix to_prefix mnt_from mnt_to buf

   ro_flag=rw
   from_prefix=
   to_prefix=

   while [ ${#} -gt 0 ]; do
      case "${1}" in

         ''|'#'*)
            true
         ;;

         *:*:*)
            function_die \
               "cannot handle ${1}: unexpected/invalid" \
               "systemd_nspawn_add_bind_mounts()"
         ;;

         '@'|'@:')
            from_prefix=
            to_prefix=
         ;;
         '@ro')
            ro_flag=ro
         ;;
         '@rw')
            ro_flag=rw
         ;;
         '@/'*:*|'@:/'*)
            buf="${1#@}"
            from_prefix="${buf%%:*}"
            to_prefix="${buf#*:}"
         ;;
         '@/'*)
            from_prefix="${1#@}"
            to_prefix=
         ;;
         '@'*)
            function_die "unknown @control-sequence: ${1}" \
               "systemd_nspawn_add_bind_mounts"
         ;;

         /:*|*:/)
            function_die "please dont do that: bind-${ro_flag} ${1}" \
               "systemd_nspawn_add_bind_mounts"
         ;;

         ?*:?*)
            mnt_from="${from_prefix-}${1%%:*}"
            mnt_to="${to_prefix-}${1#*:}"

            systemd_nspawn_add_bind_mount_${ro_flag:?} \
               "${mnt_from}" "${mnt_to}" || function_die
         ;;

         ?*)
            mnt_from="${from_prefix-}${1}"
            mnt_to="${to_prefix-}${1}"

            systemd_nspawn_add_bind_mount_${ro_flag:?} \
               "${mnt_from}" "${mnt_to}" || function_die
         ;;

         *)
            function_die "expected input, got garbage: ${1}" \
               "systemd_nspawn_add_bind_mounts"
         ;;
      esac

      shift
   done
}


# void systemd_nspawn_add_tmpfs_mounts ( *definition ), raises function_die()
#
#  Appends several tmpfs mount definitions to the list of tmpfs mounts.
#
#  A definition can be any of:
#  * <mp>[:<opts>]  -- mount a tmpfs at <mp> with the given <opts>
#                       <mp> must be an absolute path
#  * @:<opts>,
#  * @<opts>        -- set default <opts> for all following mounts
#                       (prefixes <mp>-specific <opts>)
#
#  * @, @:          -- clear default <opts>
#  * '' (empty str) -- ignored
#  * #*             -- ignored
#
#  ":*" and "*:*:*" statements are illegal, causing this function
#  to die (function_die()).
#
#  Example:
#     systemd_nspawn_add_tmpfs_mounts \
#        @:rw,size=10% /tmp:nodev,nosuid /var/tmp
#
#    Tmpfs-mount <chroot>/tmp with opts=rw,size=10%,nodev,nosuid
#    and <chroot>/var/tmp with opts=rw,size=10%
#
systemd_nspawn_add_tmpfs_mounts() {
   local default_mnt_opts mp mnt_opts

   # %default_mnt_opts must be empty or end with ","
   default_mnt_opts=


   while [ ${#} -gt 0 ]; do
      case "${1}" in

         ''|'#'*)
            true
         ;;

         *:*:*)
            function_die \
               "cannot handle ${1}: unexpected/invalid" \
               "systemd_nspawn_add_tmpfs_mounts()"
         ;;

         '@')
            default_mnt_opts=
         ;;
         '@:'*)
            default_mnt_opts="${1#@:},"
         ;;
         '@'*)
            default_mnt_opts="${1#@},"
         ;;

         /:*|/)
            function_die "please dont do that: / as tmpfs" \
               "systemd_nspawn_add_tmpfs_mounts()"
         ;;

         /*:?*)
            # @omg-optimize: don't split if %default_mnt_opts is empty
            mp="${1%%:*}"
            mnt_opts="${1#*:}"

            systemd_nspawn_add_tmpfs_mount \
               "${mp}" "${default_mnt_opts}${mnt_opts}" || function_die
         ;;

         /*)
            mp="${1%:}"
            systemd_nspawn_add_tmpfs_mount \
               "${mp}" "${default_mnt_opts%,}" || function_die
         ;;

         *)
            function_die "expected input, got garbage: ${1}" \
               "systemd_nspawn_add_tmpfs_mounts()"
         ;;
      esac

      shift
   done
}

# void systemd_nspawn_add_network ( *definition )
#
#  Appends several network definitions to the "net" list.
#
#  A definition <def> can be any of:
#  * --<option>        -- passed blindly to systemd_nspawn_add_network_options()
#
#  * --                -- stop definition parsing and pass all following args
#                         to systemd_nspawn_add_network_options()
#
#  * bridge,           -- adds an interface bridged
#  * bridge=@default      to the host's default network interface(1)
#
#  * macvlan,          -- adds a macvlan interface using
#  * machines=@default    the host's default network interface(1)
#
#  * interface=?*      -- same as --network-interface=?*
#  * macvlan=?*        -- same as --network-macvlan=?*
#  * veth              -- same as --network-veth
#  * bridge=?*         -- same as --network-bridge?*
#  * private           -- same as --private-network
#  * '' (empty str)    -- ignored
#  * #*                -- ignored
#
#  (1) network interface that has the "default" route
#
systemd_nspawn_add_network() {
   local v0

   while [ ${#} -gt 0 ]; do
      case "${1-}" in
         ''|'#'*)
            true
         ;;

         '--')
            shift
            systemd_nspawn_add_network_options "${@}"
            break
         ;;

         '--'*)
            systemd_nspawn_add_network_options "${1}"
         ;;

         bridge|bridge=@default|macvlan|macvlan=@default)
            if systemd_nspawn_get_default_network_interface; then
               systemd_nspawn_add_network_options --network-${1%%=*}=${v0}
            else
               # FIXME: don't die, return non-zero
               function_die "failed to autodetect default network interface" \
                  "systemd_nspawn_add_network()"
            fi
         ;;

         interface=?*|macvlan=?*|veth|bridge=?*)
            systemd_nspawn_add_network_options "--network-${1}"
         ;;

         private)
            systemd_nspawn_add_network_options "--${1}-network"
         ;;


         *)
            function_die "unknown network def: ${1}" \
               "systemd_nspawn_add_network()"
         ;;

      esac

      shift
   done
}
