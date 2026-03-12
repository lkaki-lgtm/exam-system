require './database_connection'

# USERS
DB.create_table? :users do
  primary_key :id
  String :name
  String :email, unique: true, null: false
  String :password, null: false
  String :role, null: false
  String :reg_number
  String :status
  DateTime :created_at
  DateTime :updated_at
end

# QUESTIONS
DB.create_table? :questions do
  primary_key :id
  Text :text
  String :option1
  String :option2
  String :option3
  String :option4
  String :correct_answer
  String :difficulty
  String :topic
  DateTime :created_at
  DateTime :updated_at
end

# EXAM SCHEDULE
DB.create_table? :schedules do
  primary_key :id
  String :title
  Text :description
  Integer :duration_minutes
  Date :scheduled_date
  String :start_time
  String :end_time
  String :status
  Integer :assigned_teacher_id
  DateTime :created_at
  DateTime :updated_at
end

# STUDENTS ASSIGNED TO EXAMS
DB.create_table? :schedule_students do
  primary_key :id
  Integer :schedule_id
  Integer :student_id
end

# QUESTIONS IN EXAM
DB.create_table? :schedule_questions do
  primary_key :id
  Integer :schedule_id
  Integer :question_id
  Integer :position
end

# EXAM ATTEMPTS
DB.create_table? :attempts do
  primary_key :id
  Integer :student_id
  Integer :schedule_id
  DateTime :start_time
  DateTime :end_time
  String :status
  Integer :score
  Integer :violation_count
  Text :removal_reason
  String :removed_by
  DateTime :removed_at
  Text :termination_reason
  DateTime :terminated_at
  TrueClass :completed_by_teacher
  Text :teacher_notes
  Text :feedback_json
  Text :warnings_json
  DateTime :created_at
  DateTime :updated_at
end

# ANSWERS
DB.create_table? :answers do
  primary_key :id
  Integer :attempt_id
  Integer :question_id
  Integer :question_index
  Text :answer
  TrueClass :marked_for_review, default: false
  DateTime :created_at
  DateTime :updated_at
end

# VIOLATIONS
DB.create_table? :violations do
  primary_key :id
  Integer :attempt_id
  String :violation_type
  Text :details_json
  DateTime :created_at
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
  DateTime :updated_at
end

# ---------- INDEXES ----------

DB.run "CREATE UNIQUE INDEX IF NOT EXISTS results_student_id_schedule_id_index 
ON results (student_id, schedule_id);"

DB.run "CREATE UNIQUE INDEX IF NOT EXISTS answers_attempt_id_question_index_index 
ON answers (attempt_id, question_index);"

DB.run "CREATE UNIQUE INDEX IF NOT EXISTS schedule_students_schedule_id_student_id_index 
ON schedule_students (schedule_id, student_id);"

puts "✅ Schema created successfully"