# encoding: utf-8

BASE_DIR = File.dirname(__FILE__)
$LOAD_PATH << BASE_DIR + '/lib'

require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'sinatra/form_helpers'
require 'rack/csrf'
require 'logger'

require 'digest'
require 'date'
require 'csv'
require 'json'
require 'sequel'
require 'parseconfig'
require 'exifr'
require 'mini_magick'

CONFIG = ParseConfig.new(BASE_DIR + '/db/dust.config')
ENV['TZ'] = "Europe/Moscow"

require 'core'
require 'weather'
require 'models'
require 'prowl'

class Vozduh < Sinatra::Application
  helpers Sinatra::FormHelpers

  get '/' do
      @current = Dc1100.order(:id).last
      @d1_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM25_SENSOR).first
      @d2_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM10_SENSOR).first
      @rain_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::RAIN_SENSOR).first
      @rain = Rain.from_s(@rain_stat.quantiles)
      @rains = Rainsum.where("row_names > '" + (Time.now - 2.days).utc.to_s + "'").rains
      @potds = Potd.exclude(exif_at: nil).order(Sequel.desc(:exif_at)).limit(4)

      erb :index
  end


  get '/informer' do
    @current = Dc1100.order(:id).last
    @d1_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM25_SENSOR).first
    @d2_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM10_SENSOR).first
	erb :informer, :layout => :layout_minimal
  end


  get '/texts/:article' do
    article_file = [BASE_DIR, 'views', 'texts', params[:article].gsub(/\W/, '') + '.erb'].join(File::SEPARATOR)
    # если есть параметры из редиректа, включить их сюда
    if params['status'] && session[:prowl]
      params['prowl'] = eval(session[:prowl]) # хэш сохранен с помощью to_s, десериализуется эвалом
    end

    if File.exists?(article_file)
      erb :"texts/#{params[:article]}"
    else
      [404, 'Статья по имени "' + params[:article] + '" не найдена']
    end
  end


  get '/methodology' do
    erb :methodology
  end


  get '/contacts' do
    erb :contacts
  end


  get '/robots.txt' do
    erb :robots, :layout => false
  end


  get '/data/rain.d3' do
    content_type :json
    start, stop, step = sanitize_rain_d3_params()
    return [].to_json unless start && stop && step
    Rainsum.range(start, stop, step).to_json
  end


  get '/data/dust.csv' do

    to = Time.now.utc.to_i
    from = to - 2.days

    air = Dc1100.deviations_range(from, to)

    csv_string = CSV.generate do |csv|
      csv << ['Дата', 'пыль &lt; 2.5µm','пыль &gt; 2.5 µm'] #,'дождь мм.']
      air.reverse.each do |a|
        res = [Time.at(a[:measured_at]).strftime('%Y-%m-%d %H:%M:%S')]
        if a[:d1][0].nil?
          2.times { res << '1000;1000;1000' }
        else
          res << a[:d1].join(';')
          res << a[:d2].join(';')
        end
        csv << res
      end
    end
    csv_string
  end

  # сохранить настройки оповещений
  post '/actions/notifications' do
    posted_prowl = params['prowl']

    if posted_prowl.nil?
      redirect_url = "/texts/notifications?status=error&message=3"

    else
      prowl = Prowl.find(api_key: posted_prowl['api_key'].to_s) || Prowl.new(api_key: posted_prowl['api_key'].to_s)
      prowl.do_rain = posted_prowl['do_rain'].to_i
      prowl.do_dust = posted_prowl['do_dust'].to_i

      if prowl.valid?
        prowl.save
        status = 'ok'
        message = ''
      else
        status = 'error'
        message = prowl.errors[:api_key].first
      end

      session['prowl'] = posted_prowl.to_s
      redirect_url = "/texts/notifications?status=#{status}&message=#{message}"
    end
    redirect redirect_url
  end


  post '/data/dc1100' do
      protected!
      Dc1100.insert(JSON.parse(params[:data]).merge({:measured_at => params[:measured_at]}))
      "ok"
  end


  get '/data/dc1100.?:format?' do
      if params[:format].eql?('cactus')
          d = Dc1100.reverse_order(:measured_at).first
          "dust1:#{d.d1} dust2:#{d.d2} temp:#{d.t1} hum:#{d.h1} rain:#{d.rc}"
      else
          @data = Dc1100.reverse_order(:measured_at).limit(30).all
          erb :dc1100
      end
  end


  def to_html(p)
    res = ["<#{p[0]}"]
    p[1].keys.each do |pk|
      res << "#{pk}=\"#{p[1][pk]}\""
    end
    res << "/>"
    res.join(' ')
  end

  def to_new_potd(p, direction)
    r404 = [404, 'not found']
    return r404 unless !p.nil? && p =~/^\w{32}$/
    current_potd = Potd.from_file(p)
    return r404 unless current_potd

    new_potd = direction.eql?(:before) ? current_potd.previous : current_potd.next
    return r404 if new_potd.nil?
    to_html ['img', {class: 'rsImg', src: '/potd/medium/' + new_potd.file_name, alt: new_potd.exif_at.strftime('%d.%m.%Y') }]
  end

  get '/potd/before/:img_id' do
    to_new_potd(params[:img_id], :before)
  end

  get '/potd/after/:img_id' do
    to_new_potd(params[:img_id], :after)
  end

  get '/potd/:size/:img_id' do
    content_type 'image/jpeg'
	cache_control :public, :max_age => 7*24*3600

    if (params[:img_id] =~ /^\w{32}$/) && Potd::IMG_SIZE.keys.include?(params[:size].to_sym)
      potd = Potd.from_file(params[:img_id])
    end

	if potd
	  last_modified potd.modified_at unless potd.nil?
	  etag Digest::SHA1.hexdigest(params[:img_id] + params[:size]), :weak
	  img = potd.image(params[:size].to_sym)
	  response.headers["Content-Length"] = Rack::Utils.bytesize(img).to_s
	  img
	else
      [404, 'Такой картинки нет']
	end
  end


  def render_date(date, span)
    @date = date
    @span = span

    if !@date.nil?
      @weather = Weather.new @date
      @potd = Potd.from_date(@date)
    end

    response['Access-Control-Allow-Origin'] = 'http://disqus.com'
    erb :date
  end


  get '/date/today' do
    redirect '/date/' + Time.now.date_path
  end

  get %r{/date/(\d\d)\W(\d\d)\W(\d\d\d\d)} do
    redirect '/date/' + params[:captures].reverse.join('/')
  end


  get '/date/:year/?' do
    render_date(make_date(params[:year], 1, 1), :year)
  end

  get '/date/:year/:month/?' do
    seasons = ['spring', 'summer', 'autumn', 'winter']
    if seasons.include?(params[:month])
      d = make_date(params[:year], seasons.index(params[:month])*3 + 3, 1)
      s = :season
    else
      d = make_date(params[:year], params[:month], 1)
      s = :month
    end
    render_date(d, s)
  end

  get '/date/:year/:month/:day/?' do
    render_date(make_date(params[:year], params[:month], params[:day]), :day)
  end


  configure do
    set :config, CONFIG

    Dir.mkdir('logs') unless File.exist?('logs')
    $logger = Logger.new('logs/common.log','weekly')

    use Rack::Session::Cookie, secret: settings.config['csrf_entropy']
    use Rack::Csrf, skip: %w(POST:/data/dc1100)
    set :clean_trace, true
    set :environment, settings.config['VOZDUH_ENV'].to_sym
    set :protection, except: :session_hijacking
    enable :sessions
    
    if development?
      $logger.level = Logger::DEBUG
      register Sinatra::Reloader
      also_reload BASE_DIR + '/lib/models.rb'
    else
      $logger.level = Logger::WARN
    end

    # Spit stdout and stderr to a file during production
    # in case something goes wrong
    $stdout.reopen("logs/output.log", "w")
    $stdout.sync = true
    $stderr.reopen($stdout)


    # Spit stdout and stderr to a file during production
    # in case something goes wrong
    $stdout.reopen("logs/output.log", "w")
    $stdout.sync = true
    $stderr.reopen($stdout)
  end


  helpers do

    def make_date(y, m, d)
      y = y.to_i
      m = m.to_i
      d = d.to_i
      Time.mktime(y,m,d, 12,0,0)
    end

    def spell_date(d, span)
      return "какая-то неправильная дата: #{d.inspect}" unless d.kind_of?(Time)
      months = %w(padding Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь)
      of_month = %w(padding января февраля марта апреля мая июня июля августа сентября октября ноября декабря)
      seasons = %w(Весна Лето Осень Зима)

      case span
      when :year
        d.year.to_s + " год"
      when :month
        [months[d.month], d.year, "года"].join(' ')
      when :season
        [seasons[(d.month - 1)/3], d.year, 'года'].join(' ')
      else #it should better be :day
        [d.strftime('%d'), of_month[d.month], d.year, "года"].join(' ')
      end
    end

    def render(*args)
      if args.first.is_a?(Hash) && args.first.keys.include?(:partial)
        return erb "_#{args.first[:partial]}".to_sym, :layout => false, :default_encoding => 'utf-8'
      else
        super
      end
    end

    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [settings.config['username'], settings.config['password']]
    end

    def sanitize_rain_d3_params
      res = {}
      [:start, :stop].each do |p|
        res[p] = params[p].nil? ? nil : DateTime.parse(params[p])
        res[p] = res[p].to_time if res[p]
      end
      res[:step] = params[:step].nil? ? nil : params[:step].to_i
      [res[:start], res[:stop], res[:step]]
    end

  end
end
