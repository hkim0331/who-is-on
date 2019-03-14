#!/bin/sh
# use gnu sed. command c's format differs.

# linux's sed is gnu sed, macos not.
if [ -e /usr/local/bin/gsed ]; then
    SED=/usr/local/bin/gsed
else
    SED=`which sed`
fi
${SED} -i.bak "/(define VERSION/ c\
(define VERSION \"$1\")
" who-is-on-app.rkt

echo $1 > VERSION
