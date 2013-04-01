## this is a virtual module that pulls in nearly all other modules,
## with the expection of:
## * initramfs/

HAVE_SHLIB_ALL=y

EXPORT_FUNCTIONS list_has linelist_has \
   line_iterator list_iterator colon_iterator dot_iterator default_iterator \
   file_iterator fs_iterator dir_iterator recursive_dir_iterator
