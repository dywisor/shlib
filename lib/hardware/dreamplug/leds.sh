# int dreamplug_control_leds ( <see control_leds()> )
#
#  Wraps control_leds() form hardware/leds.sh and provides access to dreamplug
#  leds via friendly names.
#
#  Takes up to 4 args. Return value indicates success/failure.
#
dreamplug_control_leds() {
   local led_identifier="${1:?}" led_name

   ## Led mapping
   ## <wifi led>      := wifi 1
   ## <wifi ap led>   := wifi_ap ap 2
   ## <bluetooth led> := bluetooth bt 3
   ##
   case "${led_identifier}" in
      'wifi'|'1')
         led_name="wifi"
         led_identifier='dreamplug:green:wifi'
      ;;
      'wifi_ap'|'ap'|'2')
         led_name="wifi_ap"
         led_identifier='dreamplug:green:wifi_ap'
      ;;
      'bluetooth'|'bt'|'3')
         led_name="bluetooth"
         led_identifier='dreamplug:blue:bluetooth'
      ;;
      *)
         led_name="${4-}"
      ;;
   esac

   control_leds "${led_identifier}" "${2-}" "${3-}" "${led_name-}"
}

# @function_alias dreamplug_leds_control() renames dreamplug_control_leds()
dreamplug_leds_control() { dreamplug_control_leds "$@"; }

# int dreamplug_leds_available()
#
#  Returns the number of dreamplug leds that are missing.
#
#  => Returns 0 if all dreamplug leds found.
#
dreamplug_leds_available() {
   local missing=0 led_name
   for led_name in \
      'dreamplug:green:wifi' \
      'dreamplug:green:wifi_ap' \
      'dreamplug:blue:bluetooth'
   do
      led_avail "${led_name}" || missing=$(( ${missing} + 1 ))
   done
   return ${missing}
}
