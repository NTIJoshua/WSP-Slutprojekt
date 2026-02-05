require "sqlite3"

db_path = File.expand_path("rpg.sqlite3", __dir__)
schema_path = File.expand_path("schema.sql", __dir__)
seed_path = File.expand_path("seed.sql", __dir__)

db = SQLite3::Database.new(db_path)
db.execute("PRAGMA foreign_keys = ON;")

schema_sql = File.read(schema_path)
seed_sql = File.read(seed_path)

db.execute_batch(schema_sql)
db.execute_batch(seed_sql)

puts "Database seeded: #{db_path}"
