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
  PM25_SENSOR = 1
  PM10_SENSOR = 2
  RAIN_SENSOR = 3

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

  # dirty hack -- store last announced rain in quantiles string field for the rain sensor
  def rain
    Rain.from_s(quantiles)
  end

  def rain=(r)
    self.quantiles = r.to_s
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


class Rain
  SINGLE_RAIN_TIMEOUT = 30*60
  MINIMAL_RAIN_DURATION = 5*60
  SAMPLES_TO_MILIMITERS = 36.4

  attr_accessor :from, :to, :last, :size

  def eql?(another_rain)
    from.eql?(another_rain.from) && to.eql?(another_rain.to) && size.eql?(another_rain.size)
  end

  def duration
    return nil if from.nil?
    ended_at = to.nil? ? Time.now : to
    return ended_at - from
  end

  def started?
    !from.nil?
  end

  def valid?
    duration.to_i > MINIMAL_RAIN_DURATION
  end

  def close
    to = last
  end

  def mm
    size.to_i/SAMPLES_TO_MILIMITERS
  end

  def to_s
    {
      from: from.to_s,
      to: to.to_s,
      size: size
    }.to_s
  end

  def self.from_s(s)
    r = Rain.new
    fields = eval(s)
    from = fields[:from]
    to = fields[:to]
    r.from = (from.nil? || from.empty?) ? nil : Time.parse(from)
    r.to = (to.nil? || to.empty?) ? nil : Time.parse(to)
    r.size = fields[:size].nil? ? nil : fields[:size].to_i
    return r
  end


  # returns timestamp of event (rain start or stop), (bool) has_started?
  def compare_to(last_rain)
    if last_rain.nil? || from.nil? || self.eql?(last_rain) || !valid?
      return false

    else
      if !from.eql?(last_rain.from) && to.nil? # new valid rain just had started
        return [from, true]

      elsif from.eql?(last_rain.from) && last_rain.to.nil? && !to.nil? # current rain just ended
        return [to, false]

      elsif !from.eql?(last_rain.from) && !to.nil? # new rain that started and ended while we were waiting
        return (Time.now - to < 3*SINGLE_RAIN_TIMEOUT) ? [to, false] : false

      else
        $logger.info("LOOK, me=#{self.to_s}, last_rain = #{last_rain.to_s}")
      end
    end
  end

end


class Rainsum < Sequel::Model
  REQUIRED_SAMPLES = 24*60

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
    current_rain = Rain.new

    order(:row_names).each do |rain_sample|

      if !current_rain.started? && rain_sample.rc > 0
        current_rain.from = rain_sample.at
        current_rain.size = rain_sample.rc
        current_rain.last = rain_sample.at

      elsif current_rain.started? && rain_sample.rc > 0
        current_rain.last = rain_sample.at
        current_rain.size += rain_sample.rc

      elsif current_rain.started? && rain_sample.rc == 0
        if rain_sample.at - current_rain.last > Rain::SINGLE_RAIN_TIMEOUT
          current_rain.to = current_rain.last
          if current_rain.valid?
            res << current_rain
          end
          current_rain = Rain.new
        end
      end

    end

    if current_rain.valid?
      res << current_rain
    end

    res
  end
end
