#!/usr/bin/R --slave -f

suppressMessages(library(RSQLite))
#
## constants
db_name =  "~ati/air-quality/db/air_quality.sqlite3"
averages = c("select avg(d1) as d from dc1100s group by measured_at/3600", "select avg(d2) as d from dc1100s group by measured_at/3600")
trends = c("select measured_at, d1 as d from dc1100s order by id desc limit 300", "select measured_at, d2 as d from dc1100s order by id desc limit 300")
sql = data.frame(averages, trends)

dbh_read = dbConnect(SQLite(), db_name, flags = SQLITE_RO)

get_data <- function(q_type, n_sensor)
{
  query = paste(sql[[q_type]][n_sensor])
	res = dbGetQuery(dbh_read, query)
}

get_quantiles <- function(n_sensor)
{
  res = get_data('averages', n_sensor)
  paste(round(quantile(res$d, probs=seq(0,1,0.2))[-1]), collapse=",")
}

get_trend <- function(n_sensor)
{
  res = get_data('trends', n_sensor)
  r = lm(res$measured_at ~ res$d)
  paste(round(r[[1]][2]))
}


t1 = get_trend(1)
q1 = get_quantiles(1)

t2 = get_trend(2)
q2 = get_quantiles(2)

dbDisconnect(dbh_read)

dbh_write = dbConnect(SQLite(), db_name)
res = dbSendQuery(dbh_write, paste("update dc1100s_stats set trend=", t1, ", quantiles='", q1, "' where n_sensor=1", sep=""))
dbClearResult(res)
res = dbSendQuery(dbh_write, paste("update dc1100s_stats set trend=", t2, ", quantiles='", q2, "' where n_sensor=2", sep=""))
dbClearResult(res)

dbDisconnect(dbh_write)
