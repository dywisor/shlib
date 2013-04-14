# recordhook example
#
#  A recordhook file defines a function for each record state which is then
#  called by the recordmux.sh script.

# int before()
#
#  Performs pre-record actions, e.g. increments a "now recording" counter.
#
#  Technically, this function is called while vdr is recording.
#
before() {
   return 0
}

# int after()
#
#  Performs post-record actions, e.g. decrements the "now recording" counter,
#  merges and/or moves the record files.
#
after() {
   return 0
}

# int edited()
#
#  (No description here.)
#
edited() {
   return 0
}


# int __null__()
#
#  This is a "virtual" state meant for testing. It's typically used for
#  printing information.
#
__null__() {
   return 0
}
