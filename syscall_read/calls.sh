# PATH based

parse_unlink() { # p
  local path
  path=$(fpath $1)

  echo "$n($path)"
}

parse_stat() { # p *
  local path addr
  path=$(fpath $1)
  addr=$2

  echo "$n($path, $addr)"
}
parse_lstat() { parse_stat "$@"; }

parse_rename() { # p p
  local path newpath
  path=$(fpath $1)
  newpath=$(fpath $2)

  echo "$n($path, $newpath)"
}

parse_mkdir() { # p m
  local path mode
  path=$(fpath $1)
  mode=$(fmode $2)

  echo "$n($path, $mode)"
}

parse_chown() { # p ui gi
  local path uid gid
  path=$(fpath $1)
  uid=$(($2))
  gid=$(($3))

  echo "$n($path, $uid, $gid)"
}
parse_lchown() { parse_chown "$@"; }

parse_execve() { # p [s [s
  local path argv envp
  path=$(fpath $1)
  argv=$2
  envp=$3

  echo "$n($path, $argv, $envp)"
}


# FD based

parse_fsync() { # fd
  local fd
  fd=$(($1))

  fdinfo $fd
  echo "$n($fd)"
}
parse_syncfs() { parse_fsync "$@"; }

parse_fstat() { # fd *
  local fd addr
  fd=$(($1))
  addr=$2

  fdinfo $fd
  echo "$n($fd, $addr)"
}

parse_read() { # fd * n
  local fd addr len
  fd=$(($1))
  addr=$2
  len=$(($3))

  fdinfo $fd
  echo "$n($fd, $addr, $len)"
}
parse_getdents() { parse_read "$@"; }
parse_getdents64() { parse_read "$@"; }

parse_write() { # fd s n
  local fd data len
  fd=$(($1))
  data=$(($2))
  len=$3

  fdinfo $fd
  echo "$n($fd, $(fstring $data $len), $len)"
}

parse_sync_file_range() { # fd n n f
  local fd start len flags
  fd=$(($1))
  start=$(($2))
  len=$(($3))
  flags=$4

  fdinfo $fd
  echo "$n($fd, $start, $len, $flags)"
}

parse_ioctl() { # fd ...
  local fd
  fd=$(($1))
  shift

  fdinfo $fd
  echo "$n($fd, [$*])"
}


# AT based

parse_newfstatat() { # a p * AT_
  local dirfd path statp flags
  dirfd=$(ffd $1)
  path=$(fpath $2)
  statp=$3
  flags=$(atflags $4)

  fdinfo $dirfd
  echo "$n($dirfd, $path, $statp, $flags)"
}

parse_openat() { # a p O_|AT_ m
  local dirfd path flags mode
  dirfd=$(ffd $1)
  path=$(fpath $2)
  flags=$3
  mode=$(fmode $4)

  fdinfo $dirfd
  echo "$n($dirfd, $path, $flags, $mode)"
}


# multiplexing

parse_select() { # n fds fds fds t
  local rfds wfds efds nfds ptime
  nfds=$(($1))
  rfds=$(($2))
  wfds=$(($3))
  efds=$(($4))
  ptime=$5

  echo "$n($nfds, $(fdset $rfds $nfds), $(fdset $wfds $nfds), $(fdset $efds $nfds), $ptime)"
}

parse_pselect6() { # n fds fds fds t *
  local rfds wfds efds nfds ptime pmask
  nfds=$(($1))
  rfds=$(($2))
  wfds=$(($3))
  efds=$(($4))
  ptime=$5
  pmask=$6

  echo "$n($nfds, $(fdset $rfds $nfds), $(fdset $wfds $nfds), $(fdset $efds $nfds), $ptime, $pmask)"
}

parse_poll() { # poll n t
  local fds nfds timeout
  fds=$(($1))
  nfds=$(($2))
  timeout=$(($3))

  echo "$n($(pollfd $fds $nfds), $nfds, $timeout)"
}

# PID based

parse_wait4() { # pid * W_ *
  local pid pstatus prusage flags
  pid=$(($1))
  pstatus=$2
  flags=$(wflags $3)
  prusage=$4

  pidinfo $pid
  echo "$n($pid, $pstatus, $flags, $prusage)"
}

