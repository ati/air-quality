
suppressMessages(library(RSQLite))
dbh = dbConnect(SQLite(), db_name)
sql = "select datetime(measured_at, 'unixepoch') as ts, d1 from dc1100s order by id"
d = dbGetQuery(dbh, sql)
dx = xts(d$d1, strptime(d$ts, '%Y-%m-%d %H:%M:%S'))
plot(rollmedian(dx, 3001))
