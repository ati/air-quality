# sequel -m ./migrations postgres://vozduh@localhost/vozduh
# 
Sequel.migration do
  change do
    create_table(:potds) do
      primary_key :id
      String :file_name, :null=>false
      Float :lat
      Float :lon
      DateTime :exif_at
      DateTime :created_at
      DateTime :modified_at
    end
    add_index :potds, :exif_at
  end
end
