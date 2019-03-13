DB=who-is-on.sqlite3

all:
	@echo make ds218j to make remote repo to ds218j
	@echo make syno2 to make remote repo to syno2j
	@echo make create to create database and insert seeds
	@echo make clean

ds218j:
	git remote set-url origin ssh://hkim@ds218j.local/git/who-is-on.git

syno2:
	git remote set-url origin ssh://hkim@syno2.local/git/who-is-on.git

create:
	sqlite3 ${DB} < create.sql
	racket seed.rkt

clean:
	${RM} *~

