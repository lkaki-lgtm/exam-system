require './database_connection'

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

DB.create_table? :questions do
  primary_key :id
  String :text, text: true
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

DB.create_table? :schedules do
  primary_key :id
  String :title
  String :description, text: true
  Integer :duration_minutes
  Date :scheduled_date
  String :start_time
  String :end_time
  String :status
  Integer :assigned_teacher_id
  DateTime :created_at
  DateTime :updated_at
end

DB.create_table? :schedule_students do
  primary_key :id
  Integer :schedule_id
  Integer :student_id
end

DB.create_table? :schedule_questions do
  primary_key :id
  Integer :schedule_id
  Integer :question_id
  Integer :position
end

DB.create_table? :attempts do
  primary_key :id
  Integer :student_id
  Integer :schedule_id
  DateTime :start_time
  DateTime :end_time
  String :status
  Integer :score
  Integer :violation_count
  String :removal_reason, text: true
  String :removed_by
  DateTime :removed_at
  String :termination_reason, text: true
  DateTime :terminated_at
  TrueClass :completed_by_teacher
  String :teacher_notes, text: true
  String :feedback_json, text: true
  String :warnings_json, text: true
  DateTime :created_at
  DateTime :updated_at
end

DB.create_table? :answers do
  primary_key :id
  Integer :attempt_id
  Integer :question_id
  Integer :question_index
  String :answer, text: true
  TrueClass :marked_for_review, default: false
  DateTime :created_at
  DateTime :updated_at
end

DB.create_table? :violations do
  primary_key :id
  Integer :attempt_id
  String :violation_type
  String :details_json, text: true
  DateTime :created_at
end

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

DB.add_index :results, [:student_id, :schedule_id], unique: true unless DB.indexes(:results).key?(:results_student_id_schedule_id_index)
DB.add_index :answers, [:attempt_id, :question_index], unique: true unless DB.indexes(:answers).key?(:answers_attempt_id_question_index_index)
DB.add_index :schedule_students, [:schedule_id, :student_id], unique: true unless DB.indexes(:schedule_students).key?(:schedule_students_schedule_id_student_id_index)

puts "✅ Schema created successfully"