#!/bin/sh
# 'make install' rewrites DIR.

DIR=/srv/who-is-on
. ${DIR}/.env
echo WIO_SUBNET $WIO_SUBNET
echo WIO_DB $WIO_DB
racket ${DIR}/who-is-on-update.rkt


