validmb() { # assumes LC_CTYPE=C, but detects UTF-8
  # todo: e0 demands >= a0, f0 demands >= 90, f4 demands < 90
  local c
  local sb=$1
  shift
  case $# in
    1) if [[ $sb -lt 0xc2 ]] || [[ $sb -ge 0xe0 ]]; then return 1; fi;;
    2) if [[ $sb -lt 0xe0 ]] || [[ $sb -ge 0xf0 ]]; then return 1; fi;;
    3) if [[ $sb -lt 0xf0 ]] || [[ $sb -ge 0xf5 ]]; then return 1; fi;;
    *) return 1
  esac
  case $sb in
    224) if [[ $1 -lt 0xa0 ]]; then return 1; fi;; # E0 A0 ..
    240) if [[ $1 -lt 0x90 ]]; then return 1; fi;; # F0 90 .. ..
    244) if [[ $1 -ge 0x90 ]]; then return 1; fi;; # F4 90 .. ..
  esac
  for c in "$@"; do
    if [[ $c -lt 0x80 ]] || [[ $c -ge 0xc0 ]]; then
      return 1
    fi
  done
}
startmb() {
  local c
  local sb=$1
  shift
  if [[ $sb -ge 0xf5 ]]; then return 1; fi
  case $# in
    0|1) if [[ $sb -lt 0xc2 ]]; then return 1; fi;;
    2) if [[ $sb -lt 0xe0 ]]; then return 1; fi;;
    3) if [[ $sb -lt 0xf0 ]]; then return 1; fi;;
    *) return 1
  esac
  if [[ $# -gt 0 ]]; then
    case $sb in
      224) if [[ $1 -lt 0xa0 ]]; then return 1; fi;; # E0 A0 ..
      240) if [[ $1 -lt 0x90 ]]; then return 1; fi;; # F0 90 .. ..
      244) if [[ $1 -ge 0x90 ]]; then return 1; fi;; # F4 90 .. ..
    esac
  fi
  for c in "$@"; do
    if [[ $c -lt 0x80 ]] || [[ $c -ge 0xc0 ]]; then
      return 1
    fi
  done
}

ascstring() {
  local escaped i c limit oct
  limit=$1
  escaped=
  i=0
  oct=$LC_CTYPE

  printf \"
  LC_CTYPE=C
  while c=$(read1); do
    if [[ $i -gt $limit ]]; then
      break
    fi
    case "$c" in
    [\"\\]|$'\a'|$'\b'|$'\t'|$'\n'|$'\v'|$'\f'|$'\r')
      printf %s%s \\ "$c" | tr '\a\b\t\n\v\f\r' abtnvfr
      escaped=
      ;;
    [0-7])
      if [[ $escaped ]]; then
        printf %s \\6
      fi
      printf %s $c
      ;;
    ' '|[\!-~89A-Za-z])
      printf %s "$c"
      escaped=
      ;;
    *)
      printf %s%o \\ "'$c"
      escaped=1
      ;;
    esac
    i=$((i+1))
  done
  LC_CTYPE=$oct
  printf \"
  if [[ $i -gt $limit ]]; then
    printf ...
  fi
}

ucstring() {
  local escaped i c limit oct mb mbs cc ce
  limit=$1
  escaped=
  i=0
  oct=$LC_CTYPE
  mb=()
  mbs=

  printf \"
  LC_CTYPE=C
  while c=$(read1); do
    if [[ $i -gt $limit ]]; then
      break
    fi
    case "$c" in
    [\"\\]|$'\a'|$'\b'|$'\t'|$'\n'|$'\v'|$'\f'|$'\r')
      # roll $mb
      for ce in "${mb[@]}"; do
        printf %s%o \\ $ce
      done
      mb=()
      mbs=
      printf %s%s \\ "$c" | tr '\a\b\t\n\v\f\r' abtnvfr
      escaped=
      ;;
    [0-7])
      if [[ ${#mb[@]} -gt 0 ]]; then
        # roll $mb
        for ce in "${mb[@]}"; do
          printf %s%o \\ $ce
        done
        mb=()
        mbs=
        escaped=1
      fi
      if [[ $escaped ]]; then
        printf %s \\6
      fi
      printf %s $c
      ;;
    ' '|[\!-~89A-Za-z])
      # roll $mb
      for ce in "${mb[@]}"; do
        printf %s%o \\ $ce
      done
      mb=()
      mbs=
      printf %s "$c"
      escaped=
      ;;
    *)
      cc=$(printf %d "'$c")
      if validmb "${mb[@]}" $cc; then
        printf %s%s $mbs $c
        mb=()
        mbs=
      elif startmb "${mb[@]}" $cc; then
        mb+=($cc)
        mbs="$mbs$c"
      else
        # roll $mb
        for ce in "${mb[@]}"; do
          printf %s%o \\ $ce
        done
        if startmb $cc; then
          mb=($cc)
          mbs=$c
        else
          printf %s%o \\ $cc
          mb=()
          mbs=
        fi
        escaped=1
      fi
      ;;
    esac
    i=$((i+1))
  done
  LC_CTYPE=$oct
  printf \"
  if [[ $i -gt $limit ]]; then
    printf ...
  fi
}

cstring() {
  local str
  str=$(base64 -w0)
  echo $str |base64 -d | ascstring "$@"
  printf '(vs)'
  echo $str |base64 -d | ucstring "$@"
}

read1() {
  exec 3>&1
  (dd count=1 bs=1 | tr -d '\0' >&3) 2>&1 | grep -q 1+
}

numbe() {
  local i nu c width

  width=$1

  i=$((width))
  nu=0
  while [ $i -gt 0 ] && c=$(read1); do
    i=$((i-1))
    nu=$((nu | $(printf %d "'$c") << (i << 3)))
  done
  echo $nu
}
numle() {
  local i nu c width

  width=$1

  i=0
  nu=0
  while [ $i -lt $width ] && c=$(read1); do
    nu=$((nu | $(printf %d "'$c") << (i << 3)))
    i=$((i+1))
  done
  echo $nu
}
num(){ numle "$@"; }

# vi: et ts=2 sw=2
