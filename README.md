# Moscow air quality

![image](http://i.imgur.com/Yuem5l.png)

This is a code, that powers [Vozduh (russian for "air")](http://vozduh.msk.ru/) air quality monitoring project, including
- arduino patch for measurement unit and sensor's docs (arduino/)
- xbee interface and data publishing script, running on local FreeBSD server (dust_daemon.rb)
- sinatra script with libraries, which powers web site (main.rb)
- R script for statistics calculation (script/dust_stats.r)

Deploy: git push production master
Start: unicorn -c /home/ati/air-quality/unicorn.rb -E production -D
