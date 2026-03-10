require 'dotenv/load'
require 'sequel'

DB = Sequel.connect(ENV['DATABASE_URL'])

puts "✅ Connected to database"

# USERS TABLE
DB.create_table? :users do
  primary_key :id
  String :name
  String :email, unique: true
  String :password
  String :role
  String :reg_number
  String :status
  DateTime :created_at
end

# QUESTIONS TABLE
DB.create_table? :questions do
  primary_key :id
  String :text
  String :option1
  String :option2
  String :option3
  String :option4
  String :correct_answer
  String :difficulty
  String :topic
  DateTime :created_at
end

# EXAM SCHEDULES
DB.create_table? :schedules do
  primary_key :id
  String :title
  String :description
  Integer :duration_minutes
  Date :scheduled_date
  String :start_time
  String :end_time
  String :status
  Integer :teacher_id
  DateTime :created_at
end

# ASSIGNED STUDENTS
DB.create_table? :exam_students do
  primary_key :id
  Integer :schedule_id
  Integer :student_id
end

# EXAM QUESTIONS
DB.create_table? :exam_questions do
  primary_key :id
  Integer :schedule_id
  Integer :question_id
end

# ATTEMPTS
DB.create_table? :attempts do
  primary_key :id
  Integer :student_id
  Integer :schedule_id
  String :status
  Integer :score
  DateTime :start_time
  DateTime :end_time
end

# ANSWERS
DB.create_table? :answers do
  primary_key :id
  Integer :attempt_id
  Integer :question_id
  String :answer
end

# VIOLATIONS
DB.create_table? :violations do
  primary_key :id
  Integer :attempt_id
  String :type
  String :details
  DateTime :timestamp
end

# RESULTS
DB.create_table? :results do
  primary_key :id
  Integer :student_id
  Integer :schedule_id
  Integer :score
  Integer :total
  Float :percentage
  DateTime :created_at
end

puts "🎉 All tables created successfully!"