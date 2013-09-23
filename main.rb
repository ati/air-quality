# encoding: utf-8

BASE_DIR = File.dirname(__FILE__)
$LOAD_PATH << BASE_DIR + '/lib'

require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'sinatra/form_helpers'
require 'rack/csrf'
require 'logger'

require 'csv'
require 'json'
require 'sequel'
require 'parseconfig'
require 'exifr'

require 'core'
require 'potd'
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

      @potds = []
      (0..2).each do |d|
        p = Potd.new
        @potds << p if p.find(Time.now - d.days, :day, true)
      end

      erb :index
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


  get '/data/dust.csv' do
    to = Time.now.utc.to_i
    from = to - 2.days

    air = Dc1100.deviations_range(from, to)

    csv_string = CSV.generate do |csv|
      csv << ['Дата', 'пыль &lt; 2.5µm','пыль &gt; 2.5 µm'] #,'дождь мм.']
      air.reverse.each_with_index do |a,i|
        csv << [Time.at(a[:measured_at] + TIME_OFFSET).utc.strftime('%Y-%m-%d %H:%M'), 
          a[:d1].join(';'), a[:d2].join(';') ]#, a[:rc].size.eql?(3)? a[:rc].map{|v| v+10}.join(';') : nil]
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


  def render_date(date, span)
    @date = date
    @span = span

    if !@date.nil?
      @potd = Potd.new
      @potd.find(date, span)
    end

    response['Access-Control-Allow-Origin'] = 'http://disqus.com'
    erb :date
  end


  get '/date/today' do
    redirect '/date/' + Time.at(Time.now.utc + TIME_OFFSET).date_path
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


  #get '/cities' do
  #    defaul'_city = 6 #TODO: geoip
  #    default_group = 1 #or session?
  #
  #    active_cities = (params[:city] || [default_city]).map{ |i| i.to_i }
  #    @cities = City.order(:id).all {|c| c.is_active = true if active_cities.index(c.id) }
  #
  #    @max_year = 0;
  #    @min_year = 9999;
  #    @cities.each do |c| 
  #        @max_year = c.max_year if c.max_year > @max_year
  #        @min_year = c.min_year if c.min_year < @min_year
  #    end
  #
  #    active_groups = (params[:group]|| [default_group]).map{ |i| i.to_i } 
  #    @agroups = Group.order(:id).all {|g| g.is_active = true if active_groups.empty? || active_groups.index(g.id) }
  #
  #    @years = (2001 .. Time.now.year).to_a
  #    @cur_year = Time.now.utc.year
  #    erb :allergen
  #end
  #
  #
  #get '/data/cities/:year' do
  #    # render csv data
  #    cities = (params[:city] || []).map {|i| i.to_i } 
  #    agroups = (params[:group] || []).map {|i| i.to_i }
  #    from_d = Time.mktime(params[:year]).utc.to_i
  #    mms = {}
  #    ts = []
  #
  #    cities.each do |c_id|
  #        mms[c_id] = {}
  #        agroups.each do |g_id|
  #            mms[c_id][g_id] = {}
  #            DB["select measured_at, sum(cnt) as cnt from measurements
  #                where city_id = #{c_id} 
  #                and group_id = #{g_id}
  #                and measured_at between #{from_d} and #{from_d + 365*24*60*60}
  #                group by measured_at"].all.map {|d| mms[c_id][g_id][d[:measured_at]] = d[:cnt]}
  #            ts += mms[c_id][g_id].keys
  #        end
  #    end
  #
  #    csv_string = CSV.generate do |csv|
  #        ts.uniq.each do |ts|
  #            row = [Time.at(ts).strftime("%Y-%m-%d")]
  #            mms.each do |c_id, gdata|
  #                gdata.each do |g_id, mdata|
  #                    row.push(mdata[ts])
  #                end
  #            end
  #            csv << row
  #        end
  #    end
  #
  #    csv_string
  #end


  configure do
    set :config, ParseConfig.new(BASE_DIR + '/db/dust.config')

    Dir.mkdir('logs') unless File.exist?('logs')
    $logger = Logger.new('logs/common.log','weekly')

    use Rack::Session::Cookie, secret: settings.config['csrf_entropy']
    use Rack::Csrf, skip: %w(POST:/data/dc1100)
    set :clean_trace, true
    set :environment, settings.config['VOZDUH_ENV'].to_sym
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
      date = (y.between?(1900, Time.now.year) && m.between?(1, 12) && d.between?(1,31))? Time.mktime(y,m,d) : nil
      return nil if date.nil?
      return date.between?(Time.mktime(1900, 1, 1), Time.now.utc + TIME_OFFSET)? date : nil # interested in more or less recent dates
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

  end
end
