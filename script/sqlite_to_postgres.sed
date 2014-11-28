1 i\
set constraints all deferred;
/PRAGMA/ d
/sqlite_sequence/ d
s/`//g
s/id integer primary/id serial primary/
s/id integer NOT NULL/id serial/
s/KEY AUTOINCREMENT,/KEY,/
s/measured_at integer/measured_at bigint/
s/ts integer/ts bigint/

# alter SEQUENCE dc1100s_id_seq RESTART 545816;
$a\
SELECT setval(pg_get_serial_sequence('dc1100s', 'id'), (SELECT MAX(id) FROM dc1100s)+1);
$a\
SELECT setval(pg_get_serial_sequence('allergens', 'id'), (SELECT MAX(id) FROM allergens)+1);
$a\
SELECT setval(pg_get_serial_sequence('cities', 'id'), (SELECT MAX(id) FROM cities)+1);
$a\
SELECT setval(pg_get_serial_sequence('dc1100s_stats', 'id'), (SELECT MAX(id) FROM dc1100s_stats)+1);
$a\
SELECT setval(pg_get_serial_sequence('groups', 'id'), (SELECT MAX(id) FROM groups)+1);
$a\
SELECT setval(pg_get_serial_sequence('measurements', 'id'), (SELECT MAX(id) FROM measurements)+1);
$a\
SELECT setval(pg_get_serial_sequence('prowls', 'id'), (SELECT MAX(id) FROM prowls)+1);

