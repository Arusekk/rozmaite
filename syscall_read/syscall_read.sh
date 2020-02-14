#!/bin/bash

maxs=30
PATH_MAX=${PATH_MAX:-4096}

fpath() {
  string0at $(($1)) |cstring $PATH_MAX
}
fmode() {
  printf '0%03o\n' "$@"
}
fstring() {
  stringat $(($1)) $(($2)) |cstring $maxs
}
ffd() {
  local fd
  fd=$(($1))

  if [[ $fd -eq 0xffffff9c ]]; then # 2**32-100 == AT_FDCWD
    echo AT_FDCWD
  else
    echo $fd
  fi
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
stringat() {
  local addr sz
  addr=$1
  sz=$2
  if [[ addr -eq 0 ]]; then
    printf NULL
    return 1
  fi
  dd if=/proc/$p/mem bs=1 skip=$addr count=$sz
}
charat() {
  local addr
  addr=$1
  dd if=/proc/$p/mem bs=1 skip=$addr count=1
}
string0at() {
  local addr b
  addr=$1
  b=x
  until [[ -z "$b" ]]; do
    b=$(charat $addr)
    printf %c "$b"
    addr=$((addr+1))
  done
}
fdset() {
  local addr nfds pos c
  addr=$1
  nfds=$2

  if [[ $addr -eq 0 ]]; then
    printf NULL
    return
  fi
  printf '[ '
  pos=0
  stringat $addr $(( (nfds+7)/8)) | while LC_CTYPE=C read -rN1 c; do
    c=$(LC_CTYPE=C printf %d "'$c")
    for i in 0 1 2 3 4 5 6 7; do
      if [[ $((c & (1<<i))) -ne 0 ]]; then
        printf '%d ' $((pos + i))
      fi
    done
    pos=$((pos+8))
  done
  printf ]
}
pollfd() {
  local addr nfds sz
  addr=$1
  nfds=$2
  sz=8

  printf '['
  for i in `seq 1 $nfds`; do
    stringat $addr $sz | base64 -w0
    echo -n ", "
  done
  printf ]
}
go_parser() {
  local sc
  n="$1"
  sc="$2"
  shift
  shift
  "parse_$n" "$@"
}

source strings.sh
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
  go_parser $name ${sysc[@]} 2>/dev/null
done

# vi: et ts=2 sw=2
