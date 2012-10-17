suppressMessages(library(RSQLite))
suppressMessages(library(xts))
base_dir = paste(Sys.getenv('HOME'), '/air-quality/', sep="")
db_name = paste(base_dir, 'db/air_quality.sqlite3', sep="")
dbh = dbConnect(SQLite(), db_name)

sql = "select measured_at, d1 from dc1100s
where measured_at > strftime('%s', 'now') - 3*7*24*60*60
order by measured_at"

d = dbGetQuery(dbh, sql)
dx = xts(d$d1, as.POSIXct(d$measured_at, origin="1970-01-01"))
p = rollmedian(dx, 3001)

#colors()[grep("green",colors())]
png(paste(base_dir, 'public/img/weekly_filtered.png', sep=""), width=786, height=214, units="px")
  par(mar=c(2,2,2,2))
  plot(p, main="сглаженный график PM2.5")
  lines(p, lwd="3", col="darkgreen")
dev.off()
