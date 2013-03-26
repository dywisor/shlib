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
