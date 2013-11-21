#@section functions

# int hardware_hacks_i915()
#
#  Applies i915-specific hardware hacks (disables polling).
#
hardware_hacks_i915() {
   runcmd dofile_if /sys/module/drm_kms_helper/parameters/poll N
}

# void hardware_hacks_auto()
#
#  Applies *all* hardware hacks.
#
hardware_hacks_auto() {
   local DOFILE_WARN_MISSING=n
   hardware_hacks_i915
   return 0
}
