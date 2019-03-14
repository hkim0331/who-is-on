#!/bin/sh
# for production
# this script must be called from cron.
DIR=/srv/who-is-in
source ${DIR}/env/production && \
  /usr/bin/racket ${DIR}/who-is-on-update.rkt
