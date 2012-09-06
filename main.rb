# encoding: utf-8
require 'rubygems'
require 'sinatra'
use Rack::CommonLogger
require 'csv'
require 'json'
require 'sequel'
require 'parseconfig'
require File.dirname(__FILE__) + '/lib/models'
require File.dirname(__FILE__) + '/lib/rain'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'

# require 'ipgeobase'
# ip_meta = Ipgeobase.lookup('213.232.243.233')
# #<Ipgeobase::IpMetaData:0x007fe2bb158790 @city="Москва", @country="RU", @region="Москва", @district="Центральный федеральный округ", @lat=55.755787, @lng=37.617634>"

set :public_folder, 'public'
set :static, true
set :config, ParseConfig.new(File.dirname(__FILE__) + '/db/dust.config')
set :clean_trace, true
enable :sessions, :logging

get '/' do
    @current = Dc1100.all.last
    @rain = Rain.new #recent
    @rain.find_last
    @d1_stat = Dc1100s_stat.where(:n_sensor => 1).first
    @d2_stat = Dc1100s_stat.where(:n_sensor => 2).first
    erb :index
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
  rain = Rain.new
  rain.set_range(from, to)

  csv_string = CSV.generate do |csv|
    csv << ['Дата', 'пыль &lt; 2.5µm','пыль &gt; 2.5 µm','дождь мм.']
    air.each_with_index do |a,i|
      #r = rain.data_points[i][:count]
      csv << [Time.at(a[:measured_at] + TIME_OFFSET).utc.strftime('%Y-%m-%d %H:%M'), 
        a[:d1].join(';'), a[:d2].join(';'), a[:rc].size.eql?(3)? a[:rc].map{|v| v+10}.join(';') : nil] #r.eql?(0)? nil : r]
    end
  end

  csv_string
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
        @data = Dc1100.reverse_order(:measured_at).limit(24*60).all
        erb :dc1100
    end
end


#get '/cities' do
#    default_city = 6 #TODO: geoip
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

helpers do
  def render(*args)
    if args.first.is_a?(Hash) && args.first.keys.include?(:partial)
      return erb "_#{args.first[:partial]}".to_sym, :layout => false
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
