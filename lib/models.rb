require 'sequel'
require 'json'

DB = Sequel.sqlite(File.join(BASE_DIR, 'db', 'air_quality.sqlite3'))
TIME_OFFSET = 4*60*60

class City < Sequel::Model
    attr_accessor :max_year, :min_year, :is_active
    one_to_many :measurements

    def after_initialize
        super
        @is_active = false
        @min_year = Measurement.where(:city_id => id).order(:id).last.year
        @max_year = Measurement.where(:city_id => id).order(:id).first.year
    end

    def to_json
        self.values.merge({:max_year => @max_year, :min_year => @min_year, :is_active => @is_active}).to_json
    end
end


class Group < Sequel::Model
    attr_accessor :is_active
    one_to_many :allergens

    def after_initialize
        @is_active = false
    end

    def to_json
        self.values.merge({:is_active => @is_active}).to_json
    end
end


class Allergen < Sequel::Model
    attr_accessor :is_active
    many_to_one :group
    one_to_many :measurements

    def after_initialize
        @is_active = false
    end
end


class Measurement < Sequel::Model
    many_to_one :city
    many_to_one :allergen

    def year
        Time.at(measured_at).year
    end
end


class Dc1100 < Sequel::Model
    AVG_INTERVAL = 30*60

    def ts_to_s( format = '%Y-%m-%d %H:%M')
        Time.at(measured_at + TIME_OFFSET).utc.strftime(format)
    end

    def self.timerange(from, to)
        Dc1100.reverse_order(:measured_at).where(:measured_at => from.to_i .. to.to_i).all
    end

    def self.deviations_range(from, to)
      # округлить на границу интервала усреднения
      samples = timerange(from, to)
      dev = []
      i = 0
      len = samples.length

      while (i < len)
        j = i
        i += 1 while (i < len -2) && (samples[j].measured_at - samples[i].measured_at < AVG_INTERVAL)

        d1 = samples[j..i].map {|d| d.d1}
        d2 = samples[j..i].map {|d| d.d2}
        rc = samples[j..i].map {|d| d.rc}
        ma = samples[j..i].map {|d| d.measured_at}

        r0 = rc[0]
        rc.map! {|rv| nv = r0 - rv; r0 = rv; nv}
        dev << { :d1 => d1.min_avg_max, :d2 => d2.min_avg_max, :rc => rc.min_avg_max,  :measured_at => ma.avg }

        i += 1
      end

      return dev
    end
end


class Dc1100s_stat < Sequel::Model


  def quant(i)
    (quantiles.split(',').map{|x| x.to_i})[i]
  end


  def level(n)
    qs = quantiles.split(',').map{|x| x.to_i}

    if n.between?(0, qs[0])
      return 0
    elsif n.between?(qs[0], qs[1])
      return 1
    elsif n.between?(qs[1], qs[2])
      return 2
    elsif n.between?(qs[2], qs[3])
      return 3
    else
      return 4
    end
  end


  def direction
    return 0 if trend.between?(-1,1)
    return 1 if trend > 0
    return -1
  end
end



Sequel::Model.dataset_module do 
  def xvalid?
    count >= model::REQUIRED_SAMPLES
  end
end



class Rollmedian < Sequel::Model
  REQUIRED_SAMPLES = 1000
end



class Rainsum < Sequel::Model
  REQUIRED_SAMPLES = 24*60
  SINGLE_RAIN_TIMEOUT = 30*60
  MINIMAL_RAIN_DURATION = 5*60
  SAMPLES_TO_MILIMITERS = 36.4

  def at
    Sequel.string_to_datetime(self.row_names)
  end

  def rc
    self.V1
  end
end



Rainsum.dataset_module do

  def rains
    res = []
    current_rain = {}

    order(:row_names).each do |rain_sample|
      if current_rain[:from].nil? && rain_sample.rc > 0
        current_rain.merge!({
          from: rain_sample.at,
          size: rain_sample.rc,
          last: rain_sample.at
        })

      elsif !current_rain[:from].nil? && rain_sample.rc == 0
        if rain_sample.at - current_rain[:last] > Rainsum::SINGLE_RAIN_TIMEOUT
          current_rain[:to] = current_rain[:last]

          if current_rain[:to] - current_rain[:from] > Rainsum::MINIMAL_RAIN_DURATION
            current_rain.delete(:last)
            res << current_rain.clone
          end

          current_rain = {}
        end

      elsif !current_rain[:from].nil? && rain_sample.rc > 0
        current_rain[:last] = rain_sample.at
        current_rain[:size] += rain_sample.rc
      end

    end

    if !current_rain[:from].nil? && (Time.now > current_rain[:from] - Rainsum::MINIMAL_RAIN_DURATION)
      res << current_rain.clone
      current_rain = {}
    end

    res
  end
end
