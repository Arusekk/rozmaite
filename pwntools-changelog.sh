#!/bin/bash

set -ex

remote=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref HEAD))
rbranch=${remote#*/}
remote=${remote%%/*}
owner=$(git remote show -n "$remote" |grep -o 'github\.com.[^/]*' |cut -c12- |uniq)
numtit=$(curl -s "https://api.github.com/repos/Gallopsled/pwntools/pulls?head=$owner:$rbranch" |jq '[.[0].number, .[0].base.ref, .[0].title]')
num=$(jq '.[0]' <<<$numtit)
base=$(jq -r '.[1]' <<<$numtit)
title=$(jq -r '.[2]' <<<$numtit)
url="https://github.com/Gallopsled/pwntools/pull/$num"

sed -i -e '/(`'$base'`)/{n
    :loop
    n
    s/./&/
    t loop
    i'"- [#$num][$num] $title"'

    :loop2
    n
    s/./&/
    t loop2
    i'"[$num]: $url"'
    }' CHANGELOG.md

git commit CHANGELOG.md -m 'Update changelog'
git push "$remote" "HEAD:$rbranch"
