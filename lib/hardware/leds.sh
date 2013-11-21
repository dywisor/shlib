#@section functions

# int led__get_brightness ( **led_file, **v0! )
#
#  Read a leds brightness from led_file.
#  Returns 0 if the operation succeeded and the result is >= 0,
#  else a non-zero value is returned.
#
led__get_brightness() {
   v0=$(cat "${led_file:?}" 2>/dev/null)
   [ -n "${v0}" ] && [ "${v0}" -ge 0 2>/dev/null ]
}


# int led__get_led (
#    led_name|led_dir, led_file="brightness",
#    **led!, **led_file!
# )
#
#  Sets the led / led_file variables.
#  Returns true if the filesystem paths represented by these vars exist,
#  else false (IOW, returns true if the led exists).
#
led__get_led() {
   case "${1:?}" in
      /*)
         led="${1}"
      ;;
      *)
         led="/sys/class/leds/${1}"
      ;;
   esac

   case "${2-}" in
      '')
         led_file="${led}/brightness"
      ;;
      /*)
         led_file="${2}"
      ;;
      *)
         led_file="${led}/${2}"
      ;;
   esac

   [ -e "${led}" ] && [ -e "${led_file}" ]
}

# int led_avail ( led_name|led_dir, led_file="brightness" )
#
#  Returns 0 if the given led (referenced by name or filesystem path) exists,
#  else 1.
#
led_avail() {
   local led led_file
   led__get_led "$@"
}
# @function_alias led_available() renames led_avail()
led_available() { led_avail "$@"; }

# int led_control (
#    led_name|led_dir,
#    action|brightness,
#    led_file="brightness",
#    led_print_name=<auto>,
#    **LED_MAX_BRIGHTNESS=255,
# )
#
#  Control a led. Returns true on success, else false.
#
#  Actions are:
#  * <an integer> - set brightness directly
#  * on           - set brightness to 1
#  * off          - set brightness to 0
#  * inc, +       - increase brightness by 1
#  * dec, -       - decrease brightness by 1
#  * get, g       - store current brightness in %v0
#  * print, p     - print current brightness (using einfo/ewarn)
#
#
led_control() {
   local led led_file action

   if ! led__get_led "${1:?}" "${3-}"; then
      return 1
   elif [ -z "${2-}" ]; then
      return 0
   elif [ "${2}" -ge 0 2>/dev/null ]; then
      action="${2}"
   else
      case "${2}" in
         'on')
            action=1
         ;;
         'off')
            action=0
         ;;
         'inc'|'+')
            local v0
            led__get_brightness || return
            action=$(( ${v0} + 1 ))
         ;;
         'dec'|'-')
            local v0
            led__get_brightness || return
            action=$(( ${v0} - 1 ))
         ;;
         'get'|'g')
            led__get_brightness || return
            return 0
         ;;
         'print'|'p')
            local v0
            if led__get_brightness; then
               if [ "${HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
                  einfo "${4:-${led##*/}} = ${v0}"
               else
                  echo "${4:-${led##*/}} = ${v0}"
               fi
               return 0
            else
               if [ "${HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
                  ewarn "${4:-${led##*/}} = unknown"
               else
                  echo "${4:-${led##*/}} = unknown" 1>&2
               fi
               return 1
            fi
         ;;
         *)
            function_die "unknown action '${2}'"
         ;;
      esac
   fi

   if [ -z "${action-}" ]; then
      return 0
   elif [ "${action}" -eq 0 ] || [ "${action}" -lt 0 ]; then
      echo 0 > "${led_file}"
   elif [ "${action}" -gt "${LED_MAX_BRIGHTNESS:-255}" ]; then
      echo "${LED_MAX_BRIGHTNESS:-255}" > "${led_file}"
   else
      echo "${action}" > "${led_file}"
   fi
}
