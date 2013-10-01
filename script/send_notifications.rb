# encoding: utf-8
BASE_DIR = File.expand_path('../..', __FILE__)

require 'time'
require 'date'
require 'logger'
require 'parseconfig'

CONFIG = ParseConfig.new(BASE_DIR + '/db/dust.config')
LOGGER = Logger.new(STDOUT) # BASE_DIR + '/tmp/potd_import.log')
LOGGER.level = (CONFIG['VOZDUH_ENV'] && CONFIG['VOZDUH_ENV'].to_sym.eql?(:production)) ? Logger::WARN : Logger::DEBUG

$LOAD_PATH << BASE_DIR + '/lib'
require 'core'
require 'models'
require 'prowl'


############################################

class DustAnnouncer
  SPAM_PROTECTION_INTERVAL = 60.minutes
  
  def self.prowls
    Prowl.where(do_dust: 1).where("dust_at + interval '#{SPAM_PROTECTION_INTERVAL} seconds' < '#{Time.now}'")
  end

  def self.notify(n, direction)
    if ! direction.eql?(0)
      message = "Уровень пыли #{direction > 0 ? "повысился" : "понизился"} до класса #{n}"
      prowls.each do |p|
        p.notify(:dust, message)
      end
    end
  end
end



class RainAnnouncer
  SPAM_PROTECTION_INTERVAL = 60.minutes
  TIME_FORMAT = '%H:%M'
  
  def self.prowls
    Prowl.where(do_rain: 1).where("rain_at + interval '#{SPAM_PROTECTION_INTERVAL} seconds' < '#{Time.now}'")
  end

  def self.notify(params) # ts, has_started, mm=nil
	ts, has_started, mm = params
    size =  mm.to_i > 0 ? " Выпало %.2f mm осадков." % mm : ''
    ENV['TZ'] = "Europe/Moscow"
    message = "В #{ts.strftime(TIME_FORMAT)} #{has_started ? "начался" : "закончился"} дождь.#{size}"
    ENV['TZ'] = "UTC"
    prowls.each do |p|
      p.notify(:rain, message)
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
    else
      LOGGER.debug("same dust level, no new announcements.")
    end
  end


  def announce_trend(current_quantile)
    # сразу обновляем значение анонсированного квантиля, чтобы не спамить юзеров
    # в случае повторного запуска с теми же параметрами
    #
    if ! @pm25.announced_quantile.eql?(current_quantile)
      LOGGER.debug("announcing new dust level: #{current_quantile}")
      @pm25.update(announced_quantile: current_quantile)
    end

    DustAnnouncer.notify(current_quantile, current_quantile <=> @pm25.announced_quantile)
  end

end


def what_about_dust?
  pm25 = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM25_SENSOR).first
  subset = Rollmedian.where{row_names > Time.now - 2.days}
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
  subset = Rainsum.where{row_names > Time.now - 2.days}
  LOGGER.debug(subset.inspect)
  if subset.xvalid?
    if last_rain = subset.rains.last
      LOGGER.debug("last_rain: #{last_rain.inspect}, r_stat: #{r_stat.rain.inspect}")
      if changes = r_stat.rain.compare_to(last_rain)
        LOGGER.debug('sending rain notifications: ' + changes.inspect)
        RainAnnouncer.notify(changes.push(last_rain.mm))
      else
        LOGGER.debug('no new rain events to announce')
      end
      r_stat.rain = last_rain
      r_stat.save
    else
      LOGGER.debug("can't find last rain in valid subset")
    end
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
