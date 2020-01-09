parse_read() {
  local fd addr len
  fd=$(($1))
  addr=$2
  len=$(($3))

  fdinfo $fd
  echo "read($fd, $addr, $len)"
}

parse_rename() {
  local path newpath
  path=$(fpath $1)
  newpath=$(fpath $2)

  echo "rename($path, $newpath)"
}

parse_mkdir() {
  local path mode
  path=$(fpath $1)
  mode=$(fmode $2)

  echo "mkdir($path, $mode)"
}

parse_execve() {
  local path argv envp
  path=$(fpath $1)
  argv=$2
  envp=$3

  echo "execve($path, $argv, $envp)"
}

parse_unlink() {
  local path
  path=$(fpath $1)

  echo "unlink($path)"
}
parse_openat() {
  local dirfd path flags mode
  dirfd=$(($1))
  path=$(fpath $2)
  flags=$3
  mode=$(fmode $4)

  fdinfo $dirfd
  echo "openat($dirfd, $path, $flags, $mode)"
}
parse_newfstatat() {
  local dirfd path statp flags
  dirfd=$(($1))
  path=$(fpath $2)
  statp=$3
  flags=$(atflags $4)

  fdinfo $dirfd
  echo "newfstatat($dirfd, $path, $statp, $flags)"
}

parse_write() {
  local fd data len lenorg ellipsis
  fd=$(($1))
  data=$(($2))
  len=$(($3))

  fdinfo $fd
  echo "write($fd, $(fstring $data $len), $lenorg)"
}
parse_fsync() {
  local fd
  fd=$(($1))

  fdinfo $fd
  echo "fsync($fd)"
}
parse_sync_file_range() {
  local fd start len flags
  fd=$(($1))
  start=$(($2))
  len=$(($3))
  flags=$4

  fdinfo $fd
  echo "sync_file_range($fd, $start, $len, $flags)"
}
parse_syncfs() {
  local fd
  fd=$(($1))

  fdinfo $fd
  echo "syncfd($fd)"
}
parse_ioctl() {
  local fd
  fd=$(($1))
  shift

  fdinfo $fd
  echo "ioctl($fd, [$*])"
}

parse_wait4() {
  local pid pstatus prusage flags
  pid=$(($1))
  pstatus=$2
  flags=$(wflags $3)
  prusage=$4

  pidinfo $pid
  echo "wait4($pid, $pstatus, $flags, $prusage)"
}

parse_pselect6() {
  local rfds wfds efds nfds ptime pmask
  nfds=$(($1))
  rfds=$(($2))
  wfds=$(($3))
  efds=$(($4))
  ptime=$5
  pmask=$6

  echo "pselect6($nfds, [$(fdset $rfds $nfds)], [$(fdset $wfds $nfds)], [$(fdset $efds $nfds)], $ptime, $pmask)"
}

parse_select() {
  local rfds wfds efds nfds ptime
  nfds=$(($1))
  rfds=$(($2))
  wfds=$(($3))
  efds=$(($4))
  ptime=$5

  echo "select($nfds, [$(fdset $rfds $nfds)], [$(fdset $wfds $nfds)], [$(fdset $efds $nfds)], $ptime)"
}

parse_poll() {
  local fds nfds timeout
  fds=$(($1))
  nfds=$(($2))
  timeout=$(($3))

  echo "poll([$(pollfd $fds $nfds)], $nfds, $timeout)"
}
