# encoding: utf-8
BASE_DIR = File.expand_path('../..', __FILE__)

require 'time'
require 'date'
require 'logger'
# require 'parseconfig'

# CONFIG = ParseConfig.new(BASE_DIR + '/db/dust.config')
LOGGER = Logger.new(STDOUT) # BASE_DIR + '/tmp/potd_import.log')
LOGGER.level = Logger::DEBUG

$LOAD_PATH << BASE_DIR + '/lib'
require 'core'
require 'models'
require 'prowl'


############################################

class DustAnnouncer
  SPAM_PROTECTION_INTERVAL = 60.minutes
  
  def self.prowls
    Prowl.where(do_dust: 1).where{dust_announced_at + SPAM_PROTECTION_INTERVAL < Time.now}
  end

  def self.notify(n, direction)
    if ! direction.eql?(0)
      message = "Уровень пыли #{direction > 0 ? "повысился" : "понизился"} до класса #{n}"
      prowls.each do |p|
        p.notify('Пыль', message)
      end
    end
  end
end



class RainAnnouncer
  SPAM_PROTECTION_INTERVAL = 60.minutes
  TIME_FORMAT = '%H:%M'
  
  def self.prowls
    Prowl.where(do_rain: 1).where{rain_announced_at + SPAM_PROTECTION_INTERVAL < Time.now}
  end

  def self.notify(ts, has_started, mm=nil)
    size =  mm.to_i > 0 ? " Выпало %.2f mm осадков." % mm : ''
    message = "В #{ts.strftime(TIME_FORMAT)} #{has_started ? "начался" : "закончился"} дождь.#{size}"
    prowls.each do |p|
      p.notify('Дождь', message)
    end
  end
end


class Quantile 
  attr_accessor :quantiles
  attr_accessor :pm25

  def initialize(pm25)
    @pm25 = pm25
    @quantiles = pm25.quantiles.split(',').map{|v| v.to_f}
  end


  def get(v)
    @quantiles.each_with_index do |qq, i|
      return i if v < qq
    end
    return @quantiles.count
  end


  def analyze_trend(min_m, max_m)
    max_median_q = get(max_m)
    min_median_q = get(min_m)

    # если и максимум и минимум уехали в другой квантиль, то мы анонсируем этот тренд
    # в других случаях ничего не сообщаем
    if max_median_q.eql?(min_median_q)
      announce_trend(max_median_q)
    end
  end


  def announce_trend(current_quantile)
    # сразу обновляем значение анонсированного квантиля, чтобы не спамить юзеров
    # в случае повторного запуска с теми же параметрами
    #
    if ! @pm25.announced_quantile.eql?(current_quantile)
      @pm25.update(announced_quantile: current_quantile)
    end

    DustAnnouncer.notify(current_quantile, current_quantile <=> @pm25.announced_quantile)
  end

end


def what_about_dust?
  pm25 = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM25_SENSOR).first
  subset = Rollmedian.where{row_names > Time.now - 1.5*60*Rollmedian::REQUIRED_SAMPLES}
  quantile = Quantile.new(pm25)

  # ничего не делать, если недостаточно записей в табличке средних
  if subset.xvalid?
    quantile.analyze_trend(subset.max(:V1), subset.min(:V1))
  else
    LOGGER.warn("Not enough median samples: #{subset.count}.")
  end
end


def what_about_rain?
  r_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::RAIN_SENSOR).first
  subset = Rainsum.where{row_names > Time.now - 1.5*60*Rainsum::REQUIRED_SAMPLES}
  if subset.xvalid?
    last_rain = subset.rains.last
    if changes = r_stat.rain.compare_to(last_rain)
      RainAnnouncer.notify(changes.push(last_rain.mm))
    end
    r_stat.rain = last_rain
    r_stat.save
  else
    LOGGER.warn("Not enough rain samples: #{subset.count}.")
  end
end


begin
	LOGGER.info("starting...")

  [:rollmedians, :rainsums].each do |table|
	  if !DB.table_exists?(table) 
		LOGGER.warn("Table '#{table}' does not exists. Aborting.")
		exit(1)
	  end
  end

  what_about_dust?
  what_about_rain?

end
