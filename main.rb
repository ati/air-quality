# encoding: utf-8
# encoding: utf-8


BASE_DIR = File.dirname(__FILE__)
BASE_DIR = File.dirname(__FILE__)
$LOAD_PATH << BASE_DIR + '/lib'
$LOAD_PATH << BASE_DIR + '/lib'


require 'sinatra/reloader' if development?
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'sinatra/content_for'
require 'sinatra/form_helpers'
require 'sinatra/form_helpers'
require 'rack/csrf'
require 'rack/csrf'
require 'logger'
require 'logger'


require 'csv'
require 'csv'
require 'json'
require 'json'
require 'sequel'
require 'sequel'
require 'parseconfig'
require 'parseconfig'
require 'exifr'
require 'exifr'


require 'core'
require 'core'
require 'potd'
require 'potd'
require 'models'
require 'models'
require 'prowl'
require 'prowl'


class Vozduh < Sinatra::Application
class Vozduh < Sinatra::Application
  helpers Sinatra::FormHelpers
  helpers Sinatra::FormHelpers


  get '/' do
  get '/' do
      @current = Dc1100.order(:id).last
      @current = Dc1100.order(:id).last
      @d1_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM25_SENSOR).first
      @d1_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM25_SENSOR).first
      @d2_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM10_SENSOR).first
      @d2_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::PM10_SENSOR).first
      @rain_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::RAIN_SENSOR).first
      @rain_stat = Dc1100s_stat.where(n_sensor: Dc1100s_stat::RAIN_SENSOR).first
      @rain = Rain.from_s(@rain_stat.quantiles)
      @rain = Rain.from_s(@rain_stat.quantiles)


      @potds = []
      @potds = []
      (0..2).each do |d|
      (0..2).each do |d|
        p = Potd.new
        p = Potd.new
        @potds << p if p.find(Time.now - d.days, :day, true)
        @potds << p if p.find(Time.now - d.days, :day, true)
      end
      end


      erb :index
      erb :index
  end
  end




  get '/texts/:article' do
  get '/texts/:article' do
    article_file = [BASE_DIR, 'views', 'texts', params[:article].gsub(/\W/, '') + '.erb'].join(File::SEPARATOR)
    article_file = [BASE_DIR, 'views', 'texts', params[:article].gsub(/\W/, '') + '.erb'].join(File::SEPARATOR)
    # если есть параметры из редиректа, включить их сюда
    # если есть параметры из редиректа, включить их сюда
    if params['status'] && session[:prowl]
    if params['status'] && session[:prowl]
      params['prowl'] = eval(session[:prowl]) # хэш сохранен с помощью to_s, десериализуется эвалом
      params['prowl'] = eval(session[:prowl]) # хэш сохранен с помощью to_s, десериализуется эвалом
    end
    end


    if File.exists?(article_file)
    if File.exists?(article_file)
      erb :"texts/#{params[:article]}"
      erb :"texts/#{params[:article]}"
    else
    else
      [404, 'Статья по имени "' + params[:article] + '" не найдена']
      [404, 'Статья по имени "' + params[:article] + '" не найдена']
    end
    end
  end
  end




  get '/methodology' do
  get '/methodology' do
    erb :methodology
    erb :methodology
  end
  end




  get '/contacts' do
  get '/contacts' do
    erb :contacts
    erb :contacts
  end
  end




  get '/robots.txt' do
  get '/robots.txt' do
    erb :robots, :layout => false
    erb :robots, :layout => false
  end
  end




  get '/data/dust.csv' do
  get '/data/dust.csv' do
    to = Time.now.utc.to_i
    to = Time.now.utc.to_i
    from = to - 2.days
    from = to - 2.days


    air = Dc1100.deviations_range(from, to)
    air = Dc1100.deviations_range(from, to)


    csv_string = CSV.generate do |csv|
    csv_string = CSV.generate do |csv|
      csv << ['Дата', 'пыль &lt; 2.5µm','пыль &gt; 2.5 µm'] #,'дождь мм.']
      csv << ['Дата', 'пыль &lt; 2.5µm','пыль &gt; 2.5 µm'] #,'дождь мм.']
      air.reverse.each_with_index do |a,i|
      air.reverse.each_with_index do |a,i|
        csv << [Time.at(a[:measured_at] + TIME_OFFSET).utc.strftime('%Y-%m-%d %H:%M'), 
        csv << [Time.at(a[:measured_at] + TIME_OFFSET).utc.strftime('%Y-%m-%d %H:%M'), 
          a[:d1].join(';'), a[:d2].join(';') ]#, a[:rc].size.eql?(3)? a[:rc].map{|v| v+10}.join(';') : nil]
          a[:d1].join(';'), a[:d2].join(';') ]#, a[:rc].size.eql?(3)? a[:rc].map{|v| v+10}.join(';') : nil]
      end
      end
    end
    end


    csv_string
    csv_string
  end
  end


  # сохранить настройки оповещений
  # сохранить настройки оповещений
  post '/actions/notifications' do
  post '/actions/notifications' do
    posted_prowl = params['prowl']
    posted_prowl = params['prowl']


    if posted_prowl.nil?
    if posted_prowl.nil?
      redirect_url = "/texts/notifications?status=error&message=3"
      redirect_url = "/texts/notifications?status=error&message=3"


    else
    else
      prowl = Prowl.find(api_key: posted_prowl['api_key'].to_s) || Prowl.new(api_key: posted_prowl['api_key'].to_s)
      prowl = Prowl.find(api_key: posted_prowl['api_key'].to_s) || Prowl.new(api_key: posted_prowl['api_key'].to_s)
      prowl.do_rain = posted_prowl['do_rain'].to_i
      prowl.do_rain = posted_prowl['do_rain'].to_i
      prowl.do_dust = posted_prowl['do_dust'].to_i
      prowl.do_dust = posted_prowl['do_dust'].to_i


      if prowl.valid?
      if prowl.valid?
        prowl.save
        prowl.save
        status = 'ok'
        status = 'ok'
        message = ''
        message = ''
      else
      else
        status = 'error'
        status = 'error'
        message = prowl.errors[:api_key].first
        message = prowl.errors[:api_key].first
      end
      end


      session['prowl'] = posted_prowl.to_s
      session['prowl'] = posted_prowl.to_s
      redirect_url = "/texts/notifications?status=#{status}&message=#{message}"
      redirect_url = "/texts/notifications?status=#{status}&message=#{message}"
    end
    end
    redirect redirect_url
    redirect redirect_url
  end
  end




  post '/data/dc1100' do
  post '/data/dc1100' do
      protected!
      protected!
      Dc1100.insert(JSON.parse(params[:data]).merge({:measured_at => params[:measured_at]}))
      Dc1100.insert(JSON.parse(params[:data]).merge({:measured_at => params[:measured_at]}))
      "ok"
      "ok"
  end
  end




  get '/data/dc1100.?:format?' do
  get '/data/dc1100.?:format?' do
      if params[:format].eql?('cactus')
      if params[:format].eql?('cactus')
          d = Dc1100.reverse_order(:measured_at).first
          d = Dc1100.reverse_order(:measured_at).first
          "dust1:#{d.d1} dust2:#{d.d2} temp:#{d.t1} hum:#{d.h1} rain:#{d.rc}"
          "dust1:#{d.d1} dust2:#{d.d2} temp:#{d.t1} hum:#{d.h1} rain:#{d.rc}"
      else
      else
          @data = Dc1100.reverse_order(:measured_at).limit(30).all
          @data = Dc1100.reverse_order(:measured_at).limit(30).all
          erb :dc1100
          erb :dc1100
      end
      end
  end
  end




  def render_date(date, span)
  def render_date(date, span)
    @date = date
    @date = date
    @span = span
    @span = span


    if !@date.nil?
    if !@date.nil?
      @potd = Potd.new
      @potd = Potd.new
      @potd.find(date, span)
      @potd.find(date, span)
    end
    end


    response['Access-Control-Allow-Origin'] = 'http://disqus.com'
    response['Access-Control-Allow-Origin'] = 'http://disqus.com'
    erb :date
    erb :date
  end
  end




  get '/date/today' do
  get '/date/today' do
    redirect '/date/' + Time.at(Time.now.utc + TIME_OFFSET).date_path
    redirect '/date/' + Time.at(Time.now.utc + TIME_OFFSET).date_path
  end
  end




  get '/date/:year/?' do
  get '/date/:year/?' do
    render_date(make_date(params[:year], 1, 1), :year)
    render_date(make_date(params[:year], 1, 1), :year)
  end
  end


  get '/date/:year/:month/?' do
  get '/date/:year/:month/?' do
    seasons = ['spring', 'summer', 'autumn', 'winter']
    seasons = ['spring', 'summer', 'autumn', 'winter']
    if seasons.include?(params[:month])
    if seasons.include?(params[:month])
      d = make_date(params[:year], seasons.index(params[:month])*3 + 3, 1)
      d = make_date(params[:year], seasons.index(params[:month])*3 + 3, 1)
      s = :season
      s = :season
    else
    else
      d = make_date(params[:year], params[:month], 1)
      d = make_date(params[:year], params[:month], 1)
      s = :month
      s = :month
    end
    end
    render_date(d, s)
    render_date(d, s)
  end
  end


  get '/date/:year/:month/:day/?' do
  get '/date/:year/:month/:day/?' do
    render_date(make_date(params[:year], params[:month], params[:day]), :day)
    render_date(make_date(params[:year], params[:month], params[:day]), :day)
  end
  end




  #get '/cities' do
  #get '/cities' do
  #    defaul'_city = 6 #TODO: geoip
  #    defaul'_city = 6 #TODO: geoip
  #    default_group = 1 #or session?
  #    default_group = 1 #or session?
  #
  #
  #    active_cities = (params[:city] || [default_city]).map{ |i| i.to_i }
  #    active_cities = (params[:city] || [default_city]).map{ |i| i.to_i }
  #    @cities = City.order(:id).all {|c| c.is_active = true if active_cities.index(c.id) }
  #    @cities = City.order(:id).all {|c| c.is_active = true if active_cities.index(c.id) }
  #
  #
  #    @max_year = 0;
  #    @max_year = 0;
  #    @min_year = 9999;
  #    @min_year = 9999;
  #    @cities.each do |c| 
  #    @cities.each do |c| 
  #        @max_year = c.max_year if c.max_year > @max_year
  #        @max_year = c.max_year if c.max_year > @max_year
  #        @min_year = c.min_year if c.min_year < @min_year
  #        @min_year = c.min_year if c.min_year < @min_year
  #    end
  #    end
  #
  #
  #    active_groups = (params[:group]|| [default_group]).map{ |i| i.to_i } 
  #    active_groups = (params[:group]|| [default_group]).map{ |i| i.to_i } 
  #    @agroups = Group.order(:id).all {|g| g.is_active = true if active_groups.empty? || active_groups.index(g.id) }
  #    @agroups = Group.order(:id).all {|g| g.is_active = true if active_groups.empty? || active_groups.index(g.id) }
  #
  #
  #    @years = (2001 .. Time.now.year).to_a
  #    @years = (2001 .. Time.now.year).to_a
  #    @cur_year = Time.now.utc.year
  #    @cur_year = Time.now.utc.year
  #    erb :allergen
  #    erb :allergen
  #end
  #end
  #
  #
  #
  #
  #get '/data/cities/:year' do
  #get '/data/cities/:year' do
  #    # render csv data
  #    # render csv data
  #    cities = (params[:city] || []).map {|i| i.to_i } 
  #    cities = (params[:city] || []).map {|i| i.to_i } 
  #    agroups = (params[:group] || []).map {|i| i.to_i }
  #    agroups = (params[:group] || []).map {|i| i.to_i }
  #    from_d = Time.mktime(params[:year]).utc.to_i
  #    from_d = Time.mktime(params[:year]).utc.to_i
  #    mms = {}
  #    mms = {}
  #    ts = []
  #    ts = []
  #
  #
  #    cities.each do |c_id|
  #    cities.each do |c_id|
  #        mms[c_id] = {}
  #        mms[c_id] = {}
  #        agroups.each do |g_id|
  #        agroups.each do |g_id|
  #            mms[c_id][g_id] = {}
  #            mms[c_id][g_id] = {}
  #            DB["select measured_at, sum(cnt) as cnt from measurements
  #            DB["select measured_at, sum(cnt) as cnt from measurements
  #                where city_id = #{c_id} 
  #                where city_id = #{c_id} 
  #                and group_id = #{g_id}
  #                and group_id = #{g_id}
  #                and measured_at between #{from_d} and #{from_d + 365*24*60*60}
  #                and measured_at between #{from_d} and #{from_d + 365*24*60*60}
  #                group by measured_at"].all.map {|d| mms[c_id][g_id][d[:measured_at]] = d[:cnt]}
  #                group by measured_at"].all.map {|d| mms[c_id][g_id][d[:measured_at]] = d[:cnt]}
  #            ts += mms[c_id][g_id].keys
  #            ts += mms[c_id][g_id].keys
  #        end
  #        end
  #    end
  #    end
  #
  #
  #    csv_string = CSV.generate do |csv|
  #    csv_string = CSV.generate do |csv|
  #        ts.uniq.each do |ts|
  #        ts.uniq.each do |ts|
  #            row = [Time.at(ts).strftime("%Y-%m-%d")]
  #            row = [Time.at(ts).strftime("%Y-%m-%d")]
  #            mms.each do |c_id, gdata|
  #            mms.each do |c_id, gdata|
  #                gdata.each do |g_id, mdata|
  #                gdata.each do |g_id, mdata|
  #                    row.push(mdata[ts])
  #                    row.push(mdata[ts])
  #                end
  #                end
  #            end
  #            end
  #            csv << row
  #            csv << row
  #        end
  #        end
  #    end
  #    end
  #
  #
  #    csv_string
  #    csv_string
  #end
  #end




  configure do
  configure do
    set :config, ParseConfig.new(BASE_DIR + '/db/dust.config')
    set :config, ParseConfig.new(BASE_DIR + '/db/dust.config')


    Dir.mkdir('logs') unless File.exist?('logs')
    Dir.mkdir('logs') unless File.exist?('logs')
    $logger = Logger.new('logs/common.log','weekly')
    $logger = Logger.new('logs/common.log','weekly')
    $logger.level = Logger::DEBUG
    $logger.level = Logger::DEBUG


    use Rack::Session::Cookie, secret: settings.config['csrf_entropy']
    use Rack::Session::Cookie, secret: settings.config['csrf_entropy']
    use Rack::Csrf, skip: %w(POST:/data/dc1100)
    use Rack::Csrf, skip: %w(POST:/data/dc1100)
    set :clean_trace, true
    set :clean_trace, true
    set :environment, settings.config['VOZDUH_ENV'].to_sym
    set :environment, settings.config['VOZDUH_ENV'].to_sym
    enable :sessions
    enable :sessions
    
    
    if development?
    if development?
      register Sinatra::Reloader
      register Sinatra::Reloader
      also_reload BASE_DIR + '/lib/models.rb'
      also_reload BASE_DIR + '/lib/models.rb'
    end
    end


    # Spit stdout and stderr to a file during production
    # Spit stdout and stderr to a file during production
    # in case something goes wrong
    # in case something goes wrong
    $stdout.reopen("logs/output.log", "w")
    $stdout.reopen("logs/output.log", "w")
    $stdout.sync = true
    $stdout.sync = true
    $stderr.reopen($stdout)
    $stderr.reopen($stdout)


    Dir.mkdir('logs') unless File.exist?('logs')
    Dir.mkdir('logs') unless File.exist?('logs')


    $logger = Logger.new('logs/common.log','weekly')
    $logger = Logger.new('logs/common.log','weekly')
    $logger.level = development? ? Logger::DEBUG : Logger.WARN
    $logger.level = development? ? Logger::DEBUG : Logger.WARN


    # Spit stdout and stderr to a file during production
    # Spit stdout and stderr to a file during production
    # in case something goes wrong
    # in case something goes wrong
    $stdout.reopen("logs/output.log", "w")
    $stdout.reopen("logs/output.log", "w")
    $stdout.sync = true
    $stdout.sync = true
    $stderr.reopen($stdout)
    $stderr.reopen($stdout)
  end
  end




  helpers do
  helpers do


    def make_date(y, m, d)
    def make_date(y, m, d)
      y = y.to_i
      y = y.to_i
      m = m.to_i
      m = m.to_i
      d = d.to_i
      d = d.to_i
      date = (y.between?(1900, Time.now.year) && m.between?(1, 12) && d.between?(1,31))? Time.mktime(y,m,d) : nil
      date = (y.between?(1900, Time.now.year) && m.between?(1, 12) && d.between?(1,31))? Time.mktime(y,m,d) : nil
      return nil if date.nil?
      return nil if date.nil?
      return date.between?(Time.mktime(1900, 1, 1), Time.now.utc + TIME_OFFSET)? date : nil # interested in more or less recent dates
      return date.between?(Time.mktime(1900, 1, 1), Time.now.utc + TIME_OFFSET)? date : nil # interested in more or less recent dates
    end
    end


    def spell_date(d, span)
    def spell_date(d, span)
      return "какая-то неправильная дата: #{d.inspect}" unless d.kind_of?(Time)
      return "какая-то неправильная дата: #{d.inspect}" unless d.kind_of?(Time)
      months = %w(padding Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь)
      months = %w(padding Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь)
      of_month = %w(padding января февраля марта апреля мая июня июля августа сентября октября ноября декабря)
      of_month = %w(padding января февраля марта апреля мая июня июля августа сентября октября ноября декабря)
      seasons = %w(Весна Лето Осень Зима)
      seasons = %w(Весна Лето Осень Зима)


      case span
      case span
      when :year
      when :year
        d.year.to_s + " год"
        d.year.to_s + " год"
      when :month
      when :month
        [months[d.month], d.year, "года"].join(' ')
        [months[d.month], d.year, "года"].join(' ')
      when :season
      when :season
        [seasons[(d.month - 1)/3], d.year, 'года'].join(' ')
        [seasons[(d.month - 1)/3], d.year, 'года'].join(' ')
      else #it should better be :day
      else #it should better be :day
        [d.strftime('%d'), of_month[d.month], d.year, "года"].join(' ')
        [d.strftime('%d'), of_month[d.month], d.year, "года"].join(' ')
      end
      end
    end
    end


    def render(*args)
    def render(*args)
      if args.first.is_a?(Hash) && args.first.keys.include?(:partial)
      if args.first.is_a?(Hash) && args.first.keys.include?(:partial)
        return erb "_#{args.first[:partial]}".to_sym, :layout => false, :default_encoding => 'utf-8'
        return erb "_#{args.first[:partial]}".to_sym, :layout => false, :default_encoding => 'utf-8'
      else
      else
        super
        super
      end
      end
    end
    end


    def protected!
    def protected!
      unless authorized?
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
        throw(:halt, [401, "Not authorized\n"])
      end
      end
    end
    end


    def authorized?
    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [settings.config['username'], settings.config['password']]
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [settings.config['username'], settings.config['password']]
    end
    end


  end
  end
end
end
