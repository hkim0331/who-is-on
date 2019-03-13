DB = who-is-on.sqlite3

ds218j:
	git remote set-url origin ssh://hkim@ds218j.local/git/who-is-on.git

syno2:
	git remote set-url origin ssh://hkim@sino2.local/git/who-is-on.git

create:
	sqlite3 ${DB} < create.sql
	racket seed.rkt

clean:
	${RM} *~

