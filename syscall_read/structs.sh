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
    stringat $addr $sz | (printf 'fd=%d ev=0x%x' $(num 4) $(num 2))
    echo -n ", "
  done
  printf ]
}
