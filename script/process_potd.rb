require 'fileutils'
require 'time'
require 'logger'
require 'parseconfig'
require 'gmail'
require 'exifr'
require 'mini_magick'

BASE_DIR = File.dirname(File.dirname(__FILE__))
TMP_DIR = BASE_DIR + '/tmp'

CONFIG = ParseConfig.new(BASE_DIR + '/db/dust.config')
LOGGER = Logger.new(BASE_DIR + '/tmp/potd_import.log')
LOGGER.level = Logger::DEBUG

#IMG_BASE_DIR = './tmp'
IMG_BASE_DIR = [BASE_DIR, 'public', 'potd']*File::SEPARATOR
#IMG_ARCHIVE_DIR = './tmp/archive'
IMG_ARCHIVE_DIR = [IMG_BASE_DIR, 'archive']*File::SEPARATOR
IMG_SRC_DIR = [IMG_BASE_DIR, 'new']*File::SEPARATOR

GOOD_FILENAME=/^\d{4}\D\d{2}\D\d{2}.*\.jpg$/

# dimensions => filename suffix
IMAGES = {
  '648x484' => '',
  '194x145' => 's',
}

def is_valid(a)
  a.content_type.start_with?('image/jpeg') &&
  a.filename.match(GOOD_FILENAME)
end


def next_filename(dir)
  (Dir.entries(dir).grep(GOOD_FILENAME).sort.last.to_i + 1).to_s
end


def save_potd(fn, dir)
  n = next_filename(dir) # TODO: race
  IMAGES.keys.each do |wxh|
    img = MiniMagick::Image.open(fn)
    img.resize(wxh)
    newfn = n + IMAGES[wxh] + '.jpg'
    img.write([dir, n + IMAGES[wxh] + '.jpg'].join(File::SEPARATOR))
  end
  return n
end


def process_file(fn, description)
  exif = EXIFR::JPEG.new(fn)
  d = exif.date_time || Time.parse(File.basename(fn, '.jpg'))
  dir = [IMG_BASE_DIR, d.year, "%02d" % d.month, "%02d" % d.day].join(File::SEPARATOR)
  FileUtils.mkpath(dir)
  n = save_potd(fn, dir)

  File.open(dir + "/#{n}.yml", "w+b", 0644) { |f| f.write(description + "\nsource_filename: #{fn}") }
  FileUtils.mv(fn, [IMG_ARCHIVE_DIR, File.basename(fn)].join(File::SEPARATOR))
end


def process_attachment(attachment, description)
  LOGGER.info("processing '#{attachment.filename}'")

  fn = a.filename
  if File.exists?([IMG_ARCHIVE_DIR, fn]*File::SEPARATOR)
    LOGGER.warn("file '#{fn}' found in the archive. possible duplicate, skipping.")
    return nil
  end

  dfn = [TMP_DIR, fn]*File::SEPARATOR
  begin
    File.open(dfn, "w+b", 0644) { |f| f.write a.body.decoded }
    process_file(dfn, description)

  rescue Exception => e
    LOGGER.error("Error saving #{dfn}: #{e.message}")
    return nil
  end
  
end


def process_mail
  Gmail.new(CONFIG['gmail_login'], CONFIG['gmail_pw']) do |gmail|
    gmail.inbox.emails.each do |email|
      LOGGER.info("new mail from #{email.message.from}")

      if email.multipart?
        description = ''
        email.parts.each do |part|
          if part.content_type.start_with?('text/plain')
            description += part.decoded.sub(/--.*/m, '').strip
            if !description.size.zero?
              if !description.match(/^\w+:/) #not in yml format already
                description = 'description: ' + description 
              end
            end
            description += "\nemail_from: #{email.message.from}"

          elsif part.content_type.start_with?('image/jpeg')
            process_attachment(part, description)
          else
            LOGGER.info("ignoring part '#{part.content_type}'")
          end
        end
      else
        LOGGER.info("no attachments found. skipping this email.")
      end
      #email.delete!
    end
  end
end


def process_folder(dir)
  Dir.entries(dir).grep(GOOD_FILENAME).each do |f|
    dfn = [dir, f]*File::SEPARATOR
    process_file(dfn, '')
  end
end


############################################
process_mail() rescue LOGGER.error(__LINE__.to_s + ": error processing mail for #{CONFIG['gmail_login']}")
process_folder(IMG_SRC_DIR) rescue LOGGER.error(__LINE__.to_s + ": error processing '#{IMG_SRC_DIR}'")
