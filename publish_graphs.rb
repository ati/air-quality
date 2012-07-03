require 'sinatra'
require 'csv'
require 'sequel'
require './lib/models'
require 'sinatra/reloader' if development?

set :public_folder, 'public'
set :static, true

get '/' do
    erb :index
end

get '/tmp' do
    c = City.all.find(6).first
    c.max_year
    
    # res.all #.map{|r| r[:group_id]}
    #(DB["select distinct group_id from measurements where city_id = #{@default_city_id}"]).map {|r| r[:group_id]}
end

get '/cities' do
    default_city = 6 #TODO: geoip

    active_cities = (params[:city] || [default_city]).map{ |i| i.to_i }
    @cities = City.order(:id).all {|c| c.is_active = true if active_cities.index(c.id) }

    @max_year = 0;
    @min_year = 9999;
    @cities.each do |c| 
        @max_year = c.max_year if c.max_year > @max_year
        @min_year = c.min_year if c.min_year < @min_year
    end

    active_groups = (params[:group]|| []).map{ |i| i.to_i } 
    @agroups = Group.order(:id).all {|g| g.is_active = true if active_groups.empty? || active_groups.index(g.id) }

    @years = (2001 .. Time.now.year).to_a
    @cur_year = Time.now.utc.year
    erb :allergen
end


get '/data/cities/:year' do
    # render csv data
    cities = (params[:city] || []).map {|i| i.to_i } 
    agroups = (params[:group] || []).map {|i| i.to_i }
    from_d = Time.mktime(params[:year]).utc.to_i
    mms = {}
    ts = []

    cities.each do |c_id|
        mms[c_id] = {}
        agroups.each do |g_id|
            mms[c_id][g_id] = {}
            DB["select measured_at, sum(cnt) as cnt from measurements
                where city_id = #{c_id} 
                and group_id = #{g_id}
                and measured_at between #{from_d} and #{from_d + 365*24*60*60}
                group by measured_at"].all.map {|d| mms[c_id][g_id][d[:measured_at]] = d[:cnt]}
            ts += mms[c_id][g_id].keys
        end
    end

    csv_string = CSV.generate do |csv|
        csv << ["date"] + (1 .. cities.count*agroups.count).to_a

        ts.uniq.each do |ts|
            row = [Time.at(ts).strftime("%Y-%m-%d")]
            mms.each do |c_id, gdata|
                gdata.each do |g_id, mdata|
                    row.push(mdata[ts])
                end
            end
            csv << row
        end
    end

    csv_string
end

helpers do
  def render(*args)
    if args.first.is_a?(Hash) && args.first.keys.include?(:partial)
      return erb "_#{args.first[:partial]}".to_sym, :layout => false
    else
      super
    end
  end
end

