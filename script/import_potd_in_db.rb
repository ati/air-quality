
BASE_DIR = File.dirname(File.dirname(__FILE__))
IMG_DIR = BASE_DIR + '/public/potd/archive'
$LOAD_PATH << BASE_DIR + '/lib'

require 'exifr'
require 'fileutils'
require 'models'

Dir.entries(IMG_DIR).grep(/^\w{32}$/).each do |f|
  Potd.from_file(f)
end
