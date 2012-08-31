#!/usr/bin/R --slave -f

suppressMessages(library(RSQLite))
#
## constants
db_name =  "~ati/air-quality/db/air_quality.sqlite3"
averages = c("select avg(d1) as d from dc1100s group by measured_at/3600", "select avg(d2) as d from dc1100s group by measured_at/3600")
trends = c("select measured_at, d1 as d from dc1100s order by id desc limit 60", "select measured_at, d2 as d from dc1100s order by id desc limit 60")
sql = data.frame(averages, trends)

dbh = dbConnect(SQLite(), db_name)

get_data <- function(q_type, n_sensor)
{
  query = paste(sql[[q_type]][n_sensor])
	res = dbGetQuery(dbh, query)
}

get_quantiles <- function(n_sensor)
{
  res = get_data('averages', n_sensor)
  paste(round(quantile(res$d)), collapse=",")
}

get_trend <- function(n_sensor)
{
  res = get_data('trends', n_sensor)
  r = lm(res$measured_at ~ res$d)
  paste(round(r[[1]][2]))
}

# main loop
for (sensor in 1:2)
{
  t = get_trend(sensor)
  q = get_quantiles(sensor)
  res = dbSendQuery(dbh, paste("update dc1100s_stats set trend=", t, ", quantiles='", q, "' where n_sensor=", sensor, sep=""))
  dbClearResult(res)
}

