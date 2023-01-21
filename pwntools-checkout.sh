#!/bin/sh

if [ -z "$1" ]; then
  echo "Usage: $0 <pr#>"
  exit 1
fi

set -ex

data=$(curl -s "https://api.github.com/repos/Gallopsled/pwntools/pulls/$1" |jq '[.head.user.login, .head.ref, .head.repo.html_url]')
user=$(jq -r '.[0]' <<<$data)
ref=$(jq -r '.[1]' <<<$data)
url=$(jq -r '.[2]' <<<$data)

if ! git remote show "$user" &>/dev/null; then
    git remote add "$user" "$url"
fi
git fetch "$user"
if ! git checkout "$ref" ||
   ( [ "$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref HEAD))" != "$user/$ref" ] && ! git checkout "$user-$ref" ); then
    git checkout -b "$user-$ref" --track "$user/$ref"
fi
