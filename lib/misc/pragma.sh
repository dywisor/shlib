# @funcdef shbool pragma __<name>__()
#
#  Returns true (0) if a certain behavior is desired (e.g. "be verbose?"),
#  else false (1).
#

# @pragma debug
#
#  Returns true if debugging is enabled, else false.
#
__debug__() {
   [ "${DEBUG:-n}" = "y" ]
}

# @pragma verbose
#
#  Returns true if this script should be verbose, else false.
#
__verbose__() {
   [ "${VERBOSE:-n}" = "y" ]
}

# @pragma quiet
#
#  Returns true if this script should be quiet, else false.
#
__quiet__() {
   [ "${QUIET:-n}" = "y" ]
}

# @pragma interactive
#
#  Returns true if user interaction is allowed, else false.
#
__interactive__() {
   [ "${INTERACTIVE:-n}" = "y" ]
}

# @pragma faking
#
#  Returns true if (certain/all) commands should only be printed and not
#  executed, else false.
#
__faking__() {
   [ "${FAKE_MODE:-n}" = "y" ]
}
