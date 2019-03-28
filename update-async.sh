#!/bin/sh
# 'make install' rewrites DIR.

DIR=.
. ${DIR}/.env && \
    racket ${DIR}/who-is-on-update.rkt >> ${DIR}/update.log 2>&1

