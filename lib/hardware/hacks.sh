# int hardware_hacks_i915()
#
#  Applies i915-specific hardware hacks (disables polling).
#
hardware_hacks_i915() {
   dofile_if /sys/module/drm_kms_helper/parameters/poll N
}

# void hardware_hacks_auto()
#
#  Applies *all* hardware hacks.
#
hardware_hacks_auto() {
   hardware_hacks_i915
   return 0
}
