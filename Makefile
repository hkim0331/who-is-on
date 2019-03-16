DB=who-is-on.sqlite3

all:
	@echo make ds218j to make remote repo to ds218j
	@echo make syno2 to make remote repo to syno2j
	@echo make create to create database and insert seeds
	@echo make production
	@echo make deveopmelt
	@echo make install-systemd
	@echo make clean

install:
	make production
	for i in update.sh who-is-*.rkt; do \
		insall -m 0755 $$i /srv/who-is-on;
	done

production:
	sed -i.bak -e "s|href='/|href='/w/|g" who-is-on-app.rkt
	sed -i.bak -e "s|DIR=.*|DIR=/srv/who-is-in|"	update.sh

development:
	sed -i.bak -e "s|href='/|href='/w/|g" who-is-on-app.rkt
	sed -i.bak -e 's|DIR=.*|DIR=.|' update.sh

install-systemd:
	cp who-is-on.service /etc/systemd/system
	systemctl daemon-reload
	systemctl start who-is-on
	systemctl enable who-is-on

run:
	racket who-is-on-app.rkt

ds218j:
	git remote set-url origin ssh://ds218j.local/git/who-is-on.git

syno2:
	git remote set-url origin ssh://syno2.local/git/who-is-on.git

create:
	sqlite3 ${DB} < create.sql
	racket who-is-on-seed.rkt

clean:
	${RM} *~ *.bak
