#@section functions

test_is_file()            { test -f "${1:?}"; }
test_is_symlink()         { test -h "${1:?}"; }
test_is_file_or_symlink() { test -f "${1:?}" || test -h "${1:?}"; }
test_is_real_file()       { test -f "${1:?}" && test ! -h "${1:?}"; }
test_is_dir()             { test -d "${1:?}"; }
test_is_real_dir()        { test -d "${1:?}" && test ! -h "${1:?}"; }
test_fs_exists()          { test -e "${1:?}" || test -h "${1:?}"; }
