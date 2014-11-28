require 'chunky_png'
require './lib/models'
require 'time'

RAIN_IMG_WIDTH = 720
RAIN_IMG_HEIGHT = 16
RAIN_DELTA_T = 3*24*3600
T_END = Time.now
T_START = T_END - RAIN_DELTA_T

def rain_color(rc)
  colors = %w(FFFFFF B3ECFF 9DD5EB 83BED7 69A7C3 4F91AF 357A9B 1B6387 014D74) #http://www.perbang.dk/rgbgradient/
  thresholds = [0,1,2,4,8,16,32,64]
  if rc <= 0
    color_hex = colors.first
  elsif rc >= thresholds.last
    color_hex = colors.last
  else
    color_hex = colors[thresholds.find_index{|e| e >= rc}]
  end
  ChunkyPNG::Color.from_hex(color_hex)
end


def time_to_pixels(t1, t2)
  pixels_per_second = (RAIN_IMG_WIDTH/RAIN_DELTA_T).round
  return [0,0] if t1.nil?
  
  x1 = [[(RAIN_IMG_WIDTH*(t1 - T_START)/RAIN_DELTA_T).round, 0].max, RAIN_IMG_WIDTH - 1].min
  x2 = [[(RAIN_IMG_WIDTH*(t2 - T_START)/RAIN_DELTA_T).round, 0].max, RAIN_IMG_WIDTH - 1].min
  return [x1, x2]
end


def rains_to_png(rains)
  png = ChunkyPNG::Image.new(RAIN_IMG_WIDTH, RAIN_IMG_HEIGHT, ChunkyPNG::Color::TRANSPARENT)
  png[0,0] = ChunkyPNG::Color.rgb(255, 0,0)
  png[RAIN_IMG_WIDTH-1,0] = ChunkyPNG::Color.rgb(255, 0,0)

  rains.reverse.each do |rain|
    x1, x2 = time_to_pixels(rain.from, rain.to)
    # png.line(x1,0,x2,0,rain_color(rain.size))
    c = rain_color(rain.size)
    png.rect(x1,0,x2,RAIN_IMG_HEIGHT-1,c,c)
    break if x2 <= 0
  end
  png
end

rains_to_png(Rainsum.where(row_names: T_START..T_END).rains).save('rains.png')
