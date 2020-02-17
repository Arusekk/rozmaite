#!/bin/sh

if [ $# -lt 1 ] || ! [ -d $1 ]; then
  echo Remember to cd to target installation directory!
  echo Usage: $0 /path/to/mageia/8/x86_64 --stage2-update /dev/sda1,/boot/EFI
  echo 'On gentoo, emerge dev-perl/File-Sync dev-perl/perl-headers x11-base/xorg-server[xephyr]'
  echo 'Run this script in an X session (Xephyr is an X inception)'
  exit 1
fi

die() {
  echo "$@"
  exit 1
}

install_rpm() {
  rpm2cpio $resources/media/core/release/$1-*.rpm | cpio -i -d
}

set -ex

resources="$1"
target="$PWD"

[ -f "$resources/install/stage2/mdkinst.sqfs" ]
! [ -e "$target/install/stage2" ]
! [ -e "$target/.bashrc" ]

export PERL5LIB="$target/usr/share/perl5/vendor_perl"

perldoc -l File::Sync || die "please install perl-File-Sync (dev-perl/File-Sync)"
perldoc -l MDK::Common || install_rpm perl-MDK-Common
[ -x "$target/usr/lib64/drakx-installer-stage2/misc/drakx-in-chroot" ] || install_rpm drakx-installer-stage2
which Xephyr || die "please install x11-server-xephyr (x11-base/xorg-server[xephyr])"

exec "$target/usr/lib64/drakx-installer-stage2/misc/drakx-in-chroot" "$resources" "$target" "$@"
