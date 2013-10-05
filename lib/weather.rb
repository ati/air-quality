require 'exifr'
require 'yaml'
require 'json'
require 'net/http'
require 'fileutils'

class Weather
  attr_accessor :t_url, :p_url

  # d is Time object
  def initialize(d)
    d_dir = [BASE_DIR, 'public', 'potd', d.utc.date_path].join(File::SEPARATOR)
    f = d_dir + File::SEPARATOR + 'tp.json'
    tp = nil
    now = Time.now.utc

    begin
      tp = File.exists?(f) ? JSON.parse(IO.read(f)) : read_weather()

      if Time.at(tp['a_ts'].to_i).utc > now - 7.days
        if now.to_i - top['now'].to_i > 30.minutes
          tp = read_weather
        end
      end
    rescue Exception => e
      puts "ERROR parsing json for '#{f}': " + e.message
    end

    if !tp.nil? && tp['status'].eql?('ok')
      @t_url = tp['t']
      @p_url = tp['p']
    end
  end

  private

  def read_weather
    s = Net::HTTP.get( URI.parse 'http://ljsm.tautology2.net/weather/archive.php?ts=' + (d.to_i - 4.days).to_s)
    tp = JSON.parse(s)
    FileUtils.mkpath(d_dir)
    File.open(f, 'w') do |outfile|
      outfile.puts s
    end
    tp
  end



end
