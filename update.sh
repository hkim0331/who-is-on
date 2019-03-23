#!/bin/sh
# 'make install' rewrites DIR.

DIR=.
. ${DIR}/.env && \
racket ${DIR}/who-is-on-update.rkt >> ${DIR}/update.log 2>&1 && \
at -f ${DIR}/update.sh \
            now + `awk "BEGIN{srand(); print ${WIO_BASE} + int(rand() * ${WIO_RAND})}"` minutes >> ${DIR}/update.log 2>&1
