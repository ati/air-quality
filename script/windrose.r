#!/usr/bin/R
# install.packages('yaml')
# install.packages('RPostgreSQL')

library(RPostgreSQL)
library(yaml)
library(openair)

base_dir = paste(Sys.getenv('HOME'), '/projects/air-quality/', sep="")
config = yaml.load_file(paste(base_dir, 'db/r_config.yaml', sep=''))
dbh = dbConnect(PostgreSQL(), host=config$db$host, dbname=config$db$name, user=config$db$user, password=config$db$password)

sql = "select dt as date, max(windspeed) as ws, max(winddirection) as wd, avg(d1) as pm25 
from weather_data w left outer join dc1100s d on 
  d.measured_at < extract(epoch from w.dt)::int + 15*60
  and d.measured_at > extract(epoch from w.dt)::int - 15*60
where dt between '2013-11-27 00:00:00' and '2014-11-27 00:00:00'
and w.winddirection not in (0,360)
and site='UUEE'
group by(dt)
order by dt"

d = dbGetQuery(dbh, sql)
#pollutionRose(d, pollutant="pm25", ws = "ws", wd = "wd", angle=10, type="season")
windRose(d, ws = "ws", wd = "wd", angle=10, type="season")
dbDisconnect(dbh)
