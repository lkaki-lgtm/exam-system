require 'dotenv/load'
require './database_connection'

alter_queries = [
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS violation_count INTEGER DEFAULT 0;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS removal_reason TEXT;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS removed_by VARCHAR(255);",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS removed_at TIMESTAMP;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS termination_reason TEXT;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS terminated_at TIMESTAMP;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS completed_by_teacher BOOLEAN DEFAULT FALSE;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS teacher_notes TEXT;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS feedback_json TEXT;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS warnings_json TEXT;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS created_at TIMESTAMP;",
  "ALTER TABLE attempts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP;"
]

alter_queries.each do |sql|
  DB.run(sql)
end

DB.run("UPDATE attempts SET violation_count = 0 WHERE violation_count IS NULL;")

puts "✅ attempts table updated successfully"