# sequel -m ./migrations postgres://vozduh@localhost/vozduh
# 
Sequel.migration do
  change do
    add_column :dc1100s_stats, :announced_quantile, Integer
  end
end
