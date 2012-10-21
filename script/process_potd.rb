require 'fileutils'
require 'time'
require 'logger'
require 'digest/md5'
require 'yaml'
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

  File.open(dir + "/#{n}.yml", "w+b", 0644) { |f| f.write(description.to_yaml) }
  FileUtils.mv(fn, [IMG_ARCHIVE_DIR, File.basename(fn)].join(File::SEPARATOR))
end


def process_attachment(attachment, description)
  LOGGER.info("processing message_id='#{description[:message_id]}', #{attachment.filename}'")

  fn = Digest::MD5.hexdigest(description[:message_id] + attachment.filename)
  if File.exists?([IMG_ARCHIVE_DIR, fn]*File::SEPARATOR)
    LOGGER.warn("file '#{fn}' found in the archive. possible duplicate, skipping.")
    return nil
  end

  dfn = [TMP_DIR, fn]*File::SEPARATOR
  begin
    File.open(dfn, "w+b", 0644) { |f| f.write attachment.body.decoded }
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
        description = {:email_from => email.message.from, :message_id => email.message.message_id}
        email.parts.each do |part|
          if part.content_type.start_with?('text/plain')
            description[:description] = part.decoded.sub(/--.*/m, '').strip

          elsif part.content_type.start_with?('image/jpeg')
            process_attachment(part, description)
          else
            LOGGER.info("ignoring part '#{part.content_type}'")
          end
        end
      else
        LOGGER.info("no attachments found. skipping this email.")
      end
      email.delete!
    end
  end
end


def process_folder(dir)
  Dir.entries(dir).grep(GOOD_FILENAME).each do |f|
    dfn = [dir, f]*File::SEPARATOR
    process_file(dfn, {:source_filename => dfn})
  end
end


############################################
begin
	LOGGER.info("starting...")
	process_mail()
	process_folder(IMG_SRC_DIR)
rescue Exception => e
	LOGGER.error("caught exception processing potd: #{e.message}\n" + e.backtrace.join("\n"))
end
