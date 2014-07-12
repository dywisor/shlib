#@section module_init

PYPURGE="2.7 3.3"

INITD_PURGE=
CONFD_PURGE="${INITD_PURGE}"

LOCALE_PURGE="\
af ar ast az be be@latin bg bg_BG bn bn_IN ca ca@valencia cs cy da de_AT \
el eo es et fa fa_IR fi fo fr ga gl he hi hr hu ia id is it ja ka kk kn \
ko ku ky lg lt lv ms nb nl nn oc pa pl pt pt_BR ro ru rw sk sl sq sr sr@latin \
sv te th tr uz vi wa zh_CN zh_HK zh_TW"
##LOCALE_PURGE="${LOCALE_PURGE} en_GB uk"

BUILD_FILES="/BUILD /TODO /NOTES /IMPORT /README /README.txt \
/NO_TMP /NO_PORTAGE /NO_VTMP"


#@section functions

pypurge_site() {
   local pyver verlist
   verlist="${1?}"; shift
   for pyver in ${verlist}; do
      ex_prefix_foreach /usr/lib/python${pyver}/site-packages ${*}
   done
}

homex() {
   local homedir root_home iter

   homedir="${1:-/home}"
   root_home="${2:-/root}"

   for iter in bash sh ash; do
      exf "${homedir}/*/.${iter}_history"
      exf "${root_home}/.${iter}_history"
   done

   for iter in .config .gconfd .distcc .screen; do
      exf "${homedir}/*/${iter}"
      exf "${root_home}/${iter}"
   done
}

pack_target_stage4() {
   next / name stage4 as squashfs

   exf   ${BUILD_FILES?} /stagemounts.sh /stagemounts
   exf   /portage

   exd   /proc /sys /dev /run
   exd   /tmp /mnt /media /var/tmp
   exd   /boot /lib/modules

   exd                  /usr/portage /usr/tmp /usr/src
   exf                  /usr/share/gtk-doc
   exf                  /usr/share/doc /usr/share/info /usr/share/man
   ex_prefix_foreach    /usr/share/locale ${LOCALE_PURGE?}
   #pypurge_site         "${PYPURGE}" portage _emerge repoman

   homex /home /root

   ex_prefix_foreach    /etc passwd- shadow- group- gshadow-
   ex_prefix_foreach    /etc/init.d ${INITD_PURGE?}
   ex_prefix_foreach    /etc/conf.d ${CONFD_PURGE?}
}

pack_target_stage4_overlay() {
   next / name stage4-overlay as squashfs

   exf  ${BUILD_FILES?}

   exd  /proc /sys /run /tmp /mnt /media /var/tmp
}



#@section module_init
register_target stage4
register_target stage4_overlay
