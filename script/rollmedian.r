#
# script can be called with one or two parameters: "update" and "plot"
# R --slave -f ./script/rollmedian.r --args update

suppressMessages(library(RSQLite))
suppressMessages(library(xts))

args = commandArgs()
script_name = args[4]
is_interactive = is.na(script_name)
 
base_dir = ifelse(is_interactive, 
  paste(Sys.getenv('HOME'), '/air-quality', sep=""),
  normalizePath(paste(dirname(script_name), '/../', sep=""))
)

db_name = paste(base_dir, '/db/air_quality.sqlite3', sep="")
dbh = dbConnect(SQLite(), db_name)

PAST_TIME = 3*7*24*60*60
MEDIAN_TABLE_NAME = "rollmedians"
OUT_FILE_NAME = paste(base_dir, '/public/img/weekly_filtered.png', sep="")
  
                   
update_rollmedian <- function()
{
  sql = paste("select measured_at, d1 from dc1100s
where measured_at > ", unclass(Sys.time()) - PAST_TIME, " order by measured_at")
  d = dbGetQuery(dbh, sql)
  dx = xts(d$d1, as.POSIXct(d$measured_at, origin="1970-01-01"))
  p = rollmedian(dx, 3001, fill=c("extend", "extend", "extend"))
  
  if (dbExistsTable(dbh, MEDIAN_TABLE_NAME))
  {
    dbRemoveTable(dbh, MEDIAN_TABLE_NAME)
  }
  dbWriteTable(dbh, MEDIAN_TABLE_NAME, as.data.frame(p))
}

                   

plot_rollmedian <- function()
{
  sql = "select row_names, V1 from rollmedians order by row_names"
  d = dbGetQuery(dbh, sql)
  dx = xts(d$V1, as.POSIXct(d$row_names, origin="1970-01-01"))
  
  if (is_interactive)
    plot(dx)
  else
  {
    #colors()[grep("green",colors())]
    png(OUT_FILE_NAME, width=786, height=214, units="px")
       par(mar=c(2,2,2,2))
       plot(dx, main="сглаженный график PM2.5")
       lines(dx, lwd="3", col="darkgreen")
    dev.off()   
  }
}

if ("update" %in% args)
  update_rollmedian()

if ("plot" %in% args)
  plot_rollmedian()
