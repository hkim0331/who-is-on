drop table if exists users;
create table users (
  id     integer primary key autoincrement,
  name   varchar(32) not null unique,
  jname  varchar(32) default "",
  wifi   char(17) not null unique,
  group int default 0,
  create_at       timestamp default (datetime('now','localtime')),
  update_at       timestamp default (datetime('now','localtime')));

drop table if exists mac_addrs;
create table mac_addrs (
  id    integer primary key autoincrement,
  mac   char(17),
  date date default (date('now', 'localtime')),
  time time default (time('now', 'localtime')));
