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


PM25_SENSOR = 1
DUST_NOTIFICATION_TIME = 6.hours
REQUIRED_MEDIAN_SAMPLES = 1000



############################################

class DustAnnouncer
  SPAM_PROTECTION_INTERVAL = 60.minutes
  
  def self.prowls
    Prowl.where(do_rain: 1).where{dust_announced_at + SPAM_PROTECTION_INTERVAL < Time.now}
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



begin
	LOGGER.info("starting...")

  if !DB.table_exists?(:rollmedians)
    LOGGER.warn("Table 'rollmedians' does not exists. Aborting.")
    exit(1)
  end

  pm25 = Dc1100s_stat.where(n_sensor: PM25_SENSOR).first
  subset = Rollmedian.where{row_names > Time.now - DUST_NOTIFICATION_TIME}
  quantile = Quantile.new(pm25)

  # ничего не делать, если недостаточно записей в табличке средних
  if subset.count > REQUIRED_MEDIAN_SAMPLES
    quantile.analyze_trend(subset.max(:V1), subset.min(:V1))
  else
    LOGGER.warn("Not enough median samples.")
  end

end
