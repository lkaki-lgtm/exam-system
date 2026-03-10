require 'dotenv/load'
require "sequel"
require "uri"

DB =
  if ENV["DATABASE_URL"]
    Sequel.connect(ENV["DATABASE_URL"])
  else
    Sequel.connect(
      adapter: "postgres",
      host: "localhost",
      database: "online_exam_system",
      user: "postgres",
      password: "your_password"
    )
  end


puts "✅ Connected to PostgreSQL database"