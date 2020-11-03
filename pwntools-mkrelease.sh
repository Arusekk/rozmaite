#!/bin/sh
# vi: et ts=2 sw=2

set -ex

REL="$1"
VISUAL=${VISUAL:-vi}

# ensure main directory
test -d pwnlib/

OLD=
NEW=
case "$REL" in
  *.0dev)
    OLD=dev
    VERPATT="[0-9.]*beta[0-9]*"
    ;;
  *.0beta0)
    OLD=beta
    NEW=dev
    VERPATT="${REL%beta0}dev"
    MAJ=${REL%%.*}
    MIN=${REL#*.}
    MIN=${MIN%%.*}
    NEXTREL="${MAJ}.$((MIN+1)).0dev"
    ;;
  *.0beta*)
    OLD=beta
    VERPATT="[0-9.]*beta[0-9]*"
    ;;
  *dev*)
    echo Incorrect release: $REL
    exit 1
    ;;
  *beta*)
    echo Incorrect release: $REL
    exit 1
    ;;
  *.*.0)
    OLD=stable
    NEW=beta
    VERPATT="${REL}beta[0-9]*"
    NVER=$(git show dev:pwnlib/version.py | grep -o '[0-9.]*dev')
    NEXTREL="${NVER%dev}beta0"
    ;;
  *.*.*)
    OLD=stable
    VERPATT="[0-9.]*"
    ;;
  *)
    echo Incorrect release: $REL
    exit 1
    ;;
esac

git checkout $OLD
if [ -n "$NEW" ]; then
  git merge --ff-only $NEW
fi
if [ "$OLD" == beta ]; then
  if ! git merge --ff-only stable; then
    ! git merge --no-ff --no-commit stable
    git checkout "$OLD" -- pwnlib/version.py setup.py
  fi
elif [ "$OLD" == dev ]; then
  if ! git merge --ff-only beta; then
    ! git merge --no-ff --no-commit beta
    git checkout "$OLD" -- pwnlib/version.py setup.py
  fi
fi
grep -q "$VERPATT" pwnlib/version.py
grep -q "$VERPATT" setup.py

sed -i "s/\\(version\\s*=\\s*[\"']\\).*\\([\"'],\\)$/\\1$REL\\2/" setup.py
sed -i "s/\\(__version__\\s*=\\s*[\"']\\).*\\([\"']\\)$/\\1$REL\\2/" pwnlib/version.py
$VISUAL CHANGELOG.md
git add -- setup.py pwnlib/version.py CHANGELOG.md
if git status --porcelain -uno | grep -q both; then
  git status
  zsh
fi
if [ "$OLD" == dev ]; then
  git commit -m "Begin working on ${REL%dev}"
  git push Gallopsled $OLD
else
  git commit -m "Release $REL"
  python3 setup.py bdist_wheel --universal
  git push Gallopsled $OLD:$OLD-staging
  xdg-open "https://github.com/Gallopsled/pwntools/releases/new?tag=$REL"
fi

if [ -n "$NEXTREL" ]; then
  exec "$0" "$NEXTREL"
fi
