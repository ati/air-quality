class Array
  def sum
    inject(0.0) {|result,el| result + el}
  end

  def avg
    sum / size
  end

  def min_avg_max
    return [nil] unless size > 0
    return [nil] if sum == 0
    mm = minmax
    [mm[0], avg.round, mm[1]]
  end
end

class Time
  def season
    ss = %w(spring summer autumn winter)
    ss[(month - 1)/3] 
  end

  def our_format(with_time = true)
    strftime((with_time == true)? '%Y-%m-%d %H:%M:%S' : '%Y-%m-%d') # just with_time? doesn't work
  end

  def date_path
    strftime(%w(%Y %m %d).join(File::SEPARATOR))
  end
end

class Numeric
  def duration
    secs  = self.to_int
    mins  = secs / 60
    hours = mins / 60
    days  = hours / 24

    if days > 0
      "#{days}d. #{hours % 24}h."
    elsif hours > 0
      "#{hours}h. #{mins % 60}m."
    elsif mins > 0
      "#{mins}m. #{secs % 60}s."
    elsif secs >= 0
      "#{secs}s."
    end
  end

  def days
    n = self.to_int
    return n*24*60*60
  end

  def day
    days
  end

  def minutes
    n = self.to_int
    return n*60
  end

  def minute
    minutes
  end

  def hour
    hour
  end

  def hours
    n = self.to_int
    return n*3600
  end

  def level_class
    case self.to_int
      when 0 then 'success'
      when 1 then 'info'
      when 2 then 'warning'
      when 3 then 'important'
      when 4 then 'important'
      when 5 then 'inverse'
      else raise "Unknown level"
    end
  end


end


