#@LICENSE
#
#  This module incorporates ideas and concepts from various sources,
#  most notably from Gentoo's systemd.eclass, its license follows.
# ---
# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# ---


#@section functions

# int check_is_systemd_booted()
#
#  Returns 0 if the system has been booted with systemd as init process,
#  else 1.
#
check_is_systemd_booted() {
   [ -d /run/systemd/system ]
}
