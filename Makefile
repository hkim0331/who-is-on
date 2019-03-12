DB = who-is-on.sqlite3

create:
	sqlite3 ${DB} < create.sql
	racket seed.rkt

clean:
	${RM} *~

