# sequel -m ./db/migrations sqlite://db/air_quality.sqlite3
# 
Sequel.migration do
  change do
    create_table(:prowls) do
      primary_key :id
      String :api_key, :null=>false
      Integer :do_rain, :default => 0
      Integer :do_dust, :default => 0
      DateTime :rain_at
      DateTime :dust_at
    end
    add_index :prowls, :api_key
  end
end
