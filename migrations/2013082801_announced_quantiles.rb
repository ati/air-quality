# sequel -m ./db/migrations sqlite://db/air_quality.sqlite3
# 
Sequel.migration do
  change do
    add_column :dc1100s_stats, :announced_quantile, Integer
  end
end
