#!/usr/bin/R
# install.packages('xts')
# install.packages('yaml')
# install.packages('RPostgreSQL')
# script can be called with one or two parameters: "update" and "plot"
# R --slave -f ./script/rollmedian.r --args update

library(RPostgreSQL)
library(xts)
library(yaml)

args = commandArgs()
args[2] = 'all'
print(args)
script_name = args[4]
is_interactive = FALSE #is.na(script_name)
 
base_dir = ifelse(is_interactive, 
  paste(Sys.getenv('HOME'), '/air-quality', sep=""),
  normalizePath(paste(dirname(script_name), '/../', sep=""))
)

base_dir = paste(Sys.getenv('HOME'), '/projects/air-quality/', sep="")

config = yaml.load_file(paste(base_dir, 'db/r_config.yaml', sep=''))

# print(args)
# print(db_name)
dbh = dbConnect(PostgreSQL(), host=config$db$host, dbname=config$db$name, user=config$db$user, password=config$db$password)

PROJECT_STARTED_AT = 1345549845 #2012-08-21 15:50:45 +0400
MEDIAN_WINDOW = 3*7*24*60*60 # seconds
YEAR = 365*24*60*60
MEDIAN_DUST_TABLE = "rollmedians"
SUM_RAIN_TABLE = "rainsums"
OUT_FILE_NAME = paste(base_dir, 'public/img/filtered.png', sep="")
  
                   
update_roll <- function(start_ts, end_ts)
{
  sql = paste("select measured_at, d1, rc from dc1100s where measured_at between ", start_ts, " and ", end_ts, " order by measured_at")
  d = dbGetQuery(dbh, sql)
  dust_ts = xts(d$d1, as.POSIXct(d$measured_at, origin="1970-01-01"))
  clear_rain = mapply(function(a,b){max(0, b - a)}, head(d$rc, -1), tail(d$rc, -1))
  rain_ts = xts(clear_rain, as.POSIXct(head(d$measured_at, -1), origin="1970-01-01"))
  dust_rollmed = rollmedian(dust_ts, 3001, fill=c("extend", "extend", "extend"))
  # rain_rollsum = rollapply(rain_ts, 5, sum, fill=c("extend", "extend", "extend"))

  save_roll(MEDIAN_DUST_TABLE, as.data.frame(dust_rollmed))
  save_roll(SUM_RAIN_TABLE, as.data.frame(rain_ts))
}

save_roll <- function(table_name, dataset)
{
  if (dbExistsTable(dbh, table_name)) {dbRemoveTable(dbh, table_name)}
  dbWriteTable(dbh, table_name, as.data.frame(dataset), row.names=TRUE, field.types=list(row_names="char(19)", V1="integer"))
}

plot_rollmedian <- function(width, height)
{
  sql = paste("select * from", MEDIAN_DUST_TABLE, "order by row_names")
  d = dbGetQuery(dbh, sql)
  dx = xts(d$V1, as.POSIXct(d$row_names, origin="1970-01-01"))
  
  if (is_interactive)
    plot(dx)
  else
  {
    #colors()[grep("green",colors())]
    png(OUT_FILE_NAME, width=width, height=height, units="px")
       par(mar=c(2,2,2,2))
       plot(dx, main="сглаженный график PM2.5")
       lines(dx, lwd="3", col="darkgreen")
    dev.off()   
  }
}

end_ts = as.numeric(Sys.time()) - YEAR
start_ts = end_ts - MEDIAN_WINDOW

 if ("update" %in% args)
 {
   print("updating rollmedian")
   update_roll(start_ts, end_ts)
 }
 
 if ("plot" %in% args)
 {
   print("plotting rollmedian")
   plot_rollmedian(786, 214)
 }
 
 if ("all" %in% args)
 {
   #PROJECT_STARTED_AT, end_ts) 
   print("updating...")
   update_roll(end_ts - YEAR, end_ts)
   print("plotting...")
   plot_rollmedian(2500, 200)
 }
 
 #dbDisconnect(dbh)
