require_relative "database_connection"
require "time"

now = Time.now

users = [
  {
    name: "Admin User",
    email: "admin@example.com",
    reg_number: "ADMIN001",
    password: "admin123",
    role: "admin",
    status: "active",
    created_at: now
  },
  {
    name: "Teacher User",
    email: "teacher@example.com",
    reg_number: "TEACH001",
    password: "teacher123",
    role: "teacher",
    status: "active",
    created_at: now
  },
  {
    name: "Student User",
    email: "student@example.com",
    reg_number: "STUD001",
    password: "student123",
    role: "student",
    status: "active",
    created_at: now
  }
]

users.each do |user|
  existing = DB[:users].where(email: user[:email]).first

  if existing
    puts "Skipped existing user: #{user[:email]}"
  else
    DB[:users].insert(user)
    puts "Inserted user: #{user[:email]}"
  end
end

puts "Seed data inserted successfully."