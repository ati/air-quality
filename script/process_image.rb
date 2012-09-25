require 'time'
require 'exifr'
require 'mini_magick'
require 'fileutils'

BASE_DIR = [File.dirname(File.dirname(__FILE__)), 'public', 'potd'].join(File::SEPARATOR)
ARCHIVE_DIR = [BASE_DIR, 'archive'].join(File::SEPARATOR)
DEBUG = 0
#BASE_DIR = './tmp'
#ARCHIVE_DIR = './tmp'

# dimensions => filename suffix
IMAGES = {
  '648x484' => '',
  '194x145' => 's',
}

warn("usage: #{$0} file_name.jpg") && exit(1) unless ((ARGV.size == 1) && (File.exists?(ARGV[0])))


def sane_date(d)
  return d.kind_of?(Time) && d.between?(Time.at(0), Time.now)
end


def next_filename(dir)
  (Dir.entries(dir).grep(/^\d+\.jpg$/).sort.last.to_i + 1).to_s
end


def save_potd(fn, dir)
  puts("saving potd(#{fn}) to #{dir}") unless DEBUG.zero?
  n = next_filename(dir) # TODO: race
  IMAGES.keys.each do |wxh|
    img = MiniMagick::Image.open(fn)
    img.resize(wxh)
    newfn = n + IMAGES[wxh] + '.jpg'
    puts "new filename: #{newfn}" unless DEBUG.zero?
    img.write([dir, n + IMAGES[wxh] + '.jpg'].join(File::SEPARATOR))
  end
  # TODO: geocoding + description for images
end


# get date of the image
begin
  fn = ARGV[0]
  exif = EXIFR::JPEG.new(fn)
  d = exif.date_time || Time.parse(File.basename(fn, '.jpg'))
  warn("can't get valid timestamp for file #{fn}. aborting.") && exit(2) unless sane_date(d)
  puts "date seems sane: #{d}" unless DEBUG.zero?
  dir = [BASE_DIR, d.year, "%02d" % d.month, "%02d" % d.day].join(File::SEPARATOR)
  FileUtils.mkpath(dir)
  save_potd(fn, dir)
  FileUtils.mv(fn, [ARCHIVE_DIR, File.basename(fn)].join(File::SEPARATOR))

rescue Exception => e
  warn("Error processing #{fn}: #{e.message}") && exit(4)
end

exit(0)
