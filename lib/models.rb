require 'sequel'
require 'json'

DB = Sequel.sqlite(Dir.pwd + '/db/air_quality.sqlite3')
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
    def ts_to_s( format = '%Y-%m-%d %H:%M')
        Time.at(measured_at + TIME_OFFSET).strftime(format)
    end

    def self.timerange(from, to)
        Dc1100.reverse_order(:measured_at).where(:measured_at => from.to_i .. to.to_i).all
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
    elsif n.between?(qs[3], qs[4])
      return 4
    else
      return 5
    end
  end


  def direction
    return 0 if trend.between?(-1,1)
    return 1 if trend > 0
    return -1
  end
end
