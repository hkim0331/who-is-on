#!/bin/sh
DIR=/srv/who-is-on && \
. ${DIR}/env/production && \
/usr/bin/racket ${DIR}/who-is-on-update.rkt >> ${DIR}/update.log 2>&1 && \
at -f ${DIR}/update.sh now +`awk 'BEGIN{ srand(); print 55 + substr(rand(),3) % 10}'`minutes
