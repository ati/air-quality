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

class Rain
  #TODO: check for rain counter overflow

  DAY_STEP = 1.day
  RAIN_TIMEOUT = 5.minutes
  TIC_IN_MM = 25.4*0.01

  @data_points = []
  @start_point = {:measured_at => 0, :value => 0}
  @end_point = {:measured_at => 0, :value => 0}

  attr_reader :data_points, :start_point, :end_point


  def load_range(from, to)
    Dc1100.timerange(from, to).map {|d| {:measured_at => d.measured_at, :value => d.rc}} #NB! loaded in reverse chronological order
  end

  def set_range(from, to)
    @data_points = load_range(from,to)
    return nil if @data_points.empty?
    @start_point = @data_points.last
    @end_point = @data_points.first
    set_counters()
  end


  def find_last
    # load one day of data at a time to find most recent rain
    end_day = Time.now.to_i
    start_day = end_day - DAY_STEP
    @data_points = []
    @start_point = @end_point = nil

    begin
      @data_points = load_range(start_day, end_day)
      #puts "start_day = #{start_day}, end_day = #{end_day}, data_points: #{@data_points.first.inspect} - #{@data_points.last.inspect}"
      end_day = start_day
      start_day -= DAY_STEP
      @end_point ||= get_finish()
    end until (@start_point = get_start()) || @data_points.empty?
  end


  def milimiters
    return nil if @start_point.nil?
    return ((@end_point[:value] - @start_point[:value])*TIC_IN_MM).round
  end


  def duration
    return nil if @start_point.nil?
    (@end_point[:measured_at] - @start_point[:measured_at]).duration
  end


  def is_falling
    return Time.now.to_i - @end_point[:measured_at] < RAIN_TIMEOUT
  end


  def started_at(format = '%Y-%m-%d %H:%M')
    if @start_point.nil? || @start_point[:value] == 0
      return nil
    else
      return Time.at(@start_point[:measured_at]).strftime(format)
    end
  end


  def set_counters
    cnt = @data_points.count
    if cnt == 0
      return true

    elsif cnt == 1
      @data_points[0][:count] = 0

    else
      @data_points.each_with_index do |dp,i|
        @data_points[i][:count] = (@data_points[i][:value] - @data_points[i+1][:value]).abs
        break if i >= cnt - 2
      end
      @data_points[cnt-1][:count] = @data_points[cnt-2][:count]
    end
  end


#  def intensity(ts)
#    return nil if @data_points.empty?
#    return nil unless ts.between?(@data_points.last[:measured_at], @data_points.first[:measured_at])
#    
#    cnt = @data_points.count
#    return 0 if cnt == 1
#
#    @data_points.each_with_index do |dp,i|
#      p2 = @data_points[i]
#      p1 = @data_points[i+1]
#      break if (i = cnt - 2) || (dp[:measured_at] <= ts)
#    end
#    
#    return (INTENSITY_SCALE*(p2[:value] - p1[:value])/(p2[:measured_at] - p1[:measured_at])).round
#  end


  private
    # end_point should be found before calling get_start
    # we are looking for constant value sequence of RAIN_TIMEOUT length
    def get_start()
      return nil if @end_point.nil?
      current_point = @end_point
      dry_time_start = 0
      start_point = nil

      @data_points.each do |dp|
        next if dp[:measured_at] >= @end_point[:measured_at]
        return start_point if dry_time_start - dp[:measured_at] >= RAIN_TIMEOUT

        if dp[:value] == current_point[:value]
          if dry_time_start == 0
            start_point = dp
            dry_time_start = dp[:measured_at]
          end
        else
          dry_time_start = 0
        end
        current_point = dp
      end

      return nil
    end

    def get_finish()
      current_point = @data_points.first
      @data_points.each_with_index do |dp,i|
        if dp[:value] != current_point[:value]
          return @data_points[i-1]
        end
      end
      return nil
    end

end
