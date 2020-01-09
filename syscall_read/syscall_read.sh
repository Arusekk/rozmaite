#!/bin/bash

maxs=30

fpath() {
  string0at "$@" |cstring
}
fmode() {
  printf '0%03o\n' "$@"
}
fstring() {
  stringat "$@" |cstring
}
fdinfo() {
  local fd
  fd=$1
  ls -lF --color /proc/$p/fd/$fd
  stat -L /proc/$p/fd/$fd
  cat /proc/$p/fdinfo/$fd
}
pidinfo() {
  local pid
  pid=$1
  echo "Info for pid $pid:"
  head -3 /proc/$pid/status
}
cstring() {
  echo -n \"
  python -c 'import sys;print(sys.stdin.read().replace("\\",r"\\").replace("\"","\\\""),end="")'
  echo -n \"
}
stringat() {
  local addr sz
  addr=$1
  sz=$2
  if [[ addr -eq 0 ]]; then
    echo -n "NULL"
    return 1
  fi
  dd if=/proc/$p/mem bs=1 skip=$addr count=$sz
}
string0at() {
  local addr
  addr=$1
  exec 3>&1
  b=x
  until [[ -z "$b" ]]; do
    b=$(dd if=/proc/$p/mem bs=1 skip=$addr count=1)
    echo -n "$b"
    addr=$((addr+1))
  done
}
fdset() {
  local addr nfds
  addr=$1
  nfds=$2

  stringat $addr $(( (nfds+7)/8)) | base64
}
pollfd() {
  local addr nfds sz
  addr=$1
  nfds=$2
  sz=8

  for i in `seq 1 $nfds`; do
    stringat $addr $sz | base64 -w0
    echo -n ", "
  done
}
go_parser() {
  local fun sc
  fun="$1"
  sc="$2"
  shift
  shift
  "$fun" "$@"
}

source calls.sh

f=(/usr/include/asm/unistd_64.h /usr/include/*/asm/unistd_64.h)
for ff in "${f[@]}"; do
  [ -r "$f" ] && break
done
for p in $@; do
  shopt -s nullglob
  sysc=($(cat /proc/$p/syscall |tee /dev/stderr)) nr=$sysc name=($(grep -o "__NR_.* $nr" $ff | cut -c6-))
  ls -l --color /proc/$p/fd
  echo $name'()'
  go_parser parse_$name ${sysc[@]} 2>/dev/null
done
