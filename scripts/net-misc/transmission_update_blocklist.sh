readconfig_optional /etc/transmission/blocklist.config

: ${TRANSMISSION_BLOCKLIST_FILE:=/etc/transmission/blocklist.in}
: ${TRANSMISSION_BLOCKLIST_DISTDIR:=/var/transmission/config/blocklists}

EXE="${GET_BLOCKLIST:-/sh/get_blocklist}" \
reexec_as_user \
   "${TRANSMISSION_USER:-transmission}" \
   -F p2p -C gz \
   -i "${TRANSMISSION_BLOCKLIST_FILE}" \
   -O "${TRANSMISSION_BLOCKLIST_DISTDIR}" \
   "$@"
