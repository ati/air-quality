1 i\
set constraints all deferred;
/PRAGMA/ d
/sqlite_sequence/ d
s/`//g
s/id integer primary/id serial primary/
s/KEY AUTOINCREMENT,/KEY,/
s/measured_at integer/measured_at bigint/
s/ts integer/ts bigint/
