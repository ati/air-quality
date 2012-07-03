require 'csv'
require 'sequel'

cities = %w( astrakhan barnaul ekaterinburg irkutsk krasnodar moscow nizhni-novgorod perm pyatigorsk rostov-on-don smolensk spb stavropol )

DB = Sequel.sqlite(Dir.pwd + '/db/air_quality.sqlite3')

class City < Sequel::Model
end

class Group < Sequel::Model
end

class Allergen < Sequel::Model
end

class Measurement < Sequel::Model
end

def put_row(city, row)
    (dd,mm,yy) = row[0].split('.')
    ds = Time.mktime('20' + yy, mm, dd).utc.to_i
    agroup = Group.find_or_create(:title => row[1])
    allergen = Allergen.find_or_create(:title => row[2])
    Measurement.find_or_create(:city_id => city.id, :group_id => agroup.id, :allergen_id => allergen.id, :measured_at => ds, :cnt => row[3].to_f, :note => row[4])
end


cities.each do |c|
    filename = "source_data/#{c}.csv"
    next unless File.exists?(filename)

    puts "processing #{c}"

    city = City.find_or_create(:shortname => c)
    csv = CSV.open(filename, 'r')
    r = 0
    csv.each do |row|
        r += 1
        next if r == 1 # skip header
        put_row(city, row)
    end
    puts "processed #{r} rows"
end

puts "done."
