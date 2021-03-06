DEST=/srv/who-is-on
DB=who-is-on.sqlite3

all:
	@echo make install ... make system to ${DEST}
	@echo make install-systemd
	@echo make production ... modify source files for production
	@echo make developmelt ... modify source files for development
	@echo make ds218j ... to make remote repo to ds218j
	@echo make syno2 ... to make remote repo to syno2j
	@echo make create ...   to create database and insert seeds
	@echo make sync ... copy database from production
	@echo make clean

sync:
	scp vm2019:/srv/who-is-on/who-is-on.sqlite3 .

# migration
jname:
	sqlite3 ${DB} < migration/jname-add.sql
	racket migration/jname-insert.rkt

install:
	for i in update.sh update-async.sh who-is-*.rkt weekday.rkt; do \
		install -m 0755 $$i ${DEST}; \
	done
	for i in weekday.rkt arp.rkt; do \
		install -m 0644 $$i ${DEST}; \
	done
	make production
	@echo please restart who-is-on by
	@echo sudo systemctl restart who-is-on

production:
	sed -i.bak \
		-e "s|href='/user|href='/w/user|g" \
		-e "s|action='/users|action='/w/users|g" \
		-e "s|href='/i|href='/w/i|g" \
		-e "s|href='/list|href='/w/list|g" \
		-e "s|href='/amend|href='/w/amend|g" \
		-e "s|action='/amend|action='/w/amend|g" \
			${DEST}/who-is-on-app.rkt
	sed -i.bak -e "s|DIR=.*|DIR=/srv/who-is-on|" ${DEST}/update.sh
	sed -i.bak -e "s|DIR=.*|DIR=/srv/who-is-on|" ${DEST}/update-async.sh
	cp VERSION ${DEST}/

install-systemd:
	cp who-is-on.service /lib/systemd/system/
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
