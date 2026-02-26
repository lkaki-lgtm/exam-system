require 'httparty'
require 'json'
require 'date'

class ExamDatabase
  include HTTParty
  base_uri 'http://localhost:8000'
  
  def initialize
    @auth = {username: "root", password: "root"}
    @namespace = "exam_system"
    @database = "exams"
    initialize_tables
  end
  
  def initialize_tables
    create_users_table
    create_exams_table
    create_schedules_table
    create_attempts_table
    create_results_table
  end
  
  # ===== FILE INITIALIZATION =====
  def create_users_table
    @users_file = "users.json"
    unless File.exist?(@users_file)
      File.write(@users_file, JSON.dump({
        "admins" => [],
        "students" => []
      }))
    end
  end
  
  def create_exams_table
    @exams_file = "exams.json"
    unless File.exist?(@exams_file)
      File.write(@exams_file, JSON.dump([]))
    end
  end
  
  def create_schedules_table
    @schedules_file = "schedules.json"
    unless File.exist?(@schedules_file)
      File.write(@schedules_file, JSON.dump([]))
    end
  end
  
  def create_attempts_table
    @attempts_file = "attempts.json"
    unless File.exist?(@attempts_file)
      File.write(@attempts_file, JSON.dump([]))
    end
  end
  
  def create_results_table
    @results_file = "results.json"
    unless File.exist?(@results_file)
      File.write(@results_file, JSON.dump([]))
    end
  end
  
  # ===== USER MANAGEMENT =====
  def register_student(name, email, reg_number, password)
    begin
      unless File.exist?("users.json")
        File.write("users.json", JSON.dump({"admins" => [], "students" => []}))
      end
      
      data = JSON.parse(File.read("users.json"))
      puts "📂 Current students: #{data["students"].count}"
      
      existing_email = data["students"].find { |s| s["email"].to_s.downcase == email.to_s.downcase }
      if existing_email
        puts "❌ Email already exists: #{email}"
        return nil
      end
      
      existing_reg = data["students"].find { |s| s["reg_number"].to_s == reg_number.to_s }
      if existing_reg
        puts "❌ Reg number already exists: #{reg_number}"
        return nil
      end
      
      student = {
        "id" => "student_#{Time.now.to_i}",
        "name" => name,
        "email" => email,
        "reg_number" => reg_number,
        "password" => password,
        "registered_at" => Time.now.to_s,
        "status" => "active"
      }
      
      data["students"] << student
      File.write("users.json", JSON.dump(data))
      
      puts "✅ Student registered: #{name}"
      student
    rescue => e
      puts "❌ Error: #{e.message}"
      nil
    end
  end
  
  def register_admin(name, email, password)
    begin
      unless File.exist?("users.json")
        File.write("users.json", JSON.dump({"admins" => [], "students" => []}))
      end
      
      data = JSON.parse(File.read("users.json"))
      
      existing = data["admins"].find { |a| a["email"].to_s.downcase == email.to_s.downcase }
      if existing
        puts "❌ Admin email already exists: #{email}"
        return nil
      end
      
      admin = {
        "id" => "admin_#{Time.now.to_i}",
        "name" => name,
        "email" => email,
        "password" => password,
        "registered_at" => Time.now.to_s
      }
      
      data["admins"] << admin
      File.write("users.json", JSON.dump(data))
      
      puts "✅ Admin registered: #{name}"
      admin
    rescue => e
      puts "❌ Error: #{e.message}"
      nil
    end
  end
  
  # ===== AUTHENTICATION - THIS WAS MISSING =====
  def authenticate_user(email, password)
    return nil unless File.exist?("users.json")
    
    begin
      data = JSON.parse(File.read("users.json"))
    rescue => e
      puts "❌ Error reading users.json: #{e.message}"
      return nil
    end
    
    puts "🔍 Authenticating: #{email}"
    
    # Check students
    if data["students"] && data["students"].any?
      student = data["students"].find do |s|
        s["email"].to_s.downcase.strip == email.to_s.downcase.strip && 
        s["password"].to_s == password.to_s
      end
      
      if student
        puts "✅ Student found: #{student["name"]}"
        return {"type" => "student", "user" => student}
      end
    end
    
    # Check admins
    if data["admins"] && data["admins"].any?
      admin = data["admins"].find do |a|
        a["email"].to_s.downcase.strip == email.to_s.downcase.strip && 
        a["password"].to_s == password.to_s
      end
      
      if admin
        puts "✅ Admin found: #{admin["name"]}"
        return {"type" => "admin", "user" => admin}
      end
    end
    
    puts "❌ No user found"
    nil
  end
  
  # ===== STUDENT MANAGEMENT =====
  def get_all_students
    return [] unless File.exist?("users.json")
    begin
      data = JSON.parse(File.read("users.json"))
      return data["students"] || []
    rescue
      return []
    end
  end
  
  def get_student(student_id)
    students = get_all_students
    students.find { |s| s["id"] == student_id }
  end
  
  def get_student_by_reg(reg_number)
    students = get_all_students
    students.find { |s| s["reg_number"] == reg_number }
  end
  
  def get_student_count
    get_all_students.length
  end
  
  # ===== ADMIN MANAGEMENT =====
  def get_all_admins
    return [] unless File.exist?("users.json")
    begin
      data = JSON.parse(File.read("users.json"))
      return data["admins"] || []
    rescue
      return []
    end
  end
  
  def get_admin(admin_id)
    admins = get_all_admins
    admins.find { |a| a["id"] == admin_id }
  end
  
  # ===== QUESTION MANAGEMENT =====
  def add_question(question_text, option1, option2, option3, option4, correct_answer)
    question_id = "question_#{Time.now.to_i}"
    
    questions_file = "questions.json"
    unless File.exist?(questions_file)
      File.write(questions_file, JSON.dump([]))
    end
    
    questions = JSON.parse(File.read(questions_file))
    
    question = {
      "id" => question_id,
      "text" => question_text,
      "options" => [option1, option2, option3, option4],
      "correct" => correct_answer,
      "created_at" => Time.now.to_s
    }
    
    questions << question
    File.write(questions_file, JSON.dump(questions))
    puts "✅ Question added"
    true
  end
  
  def get_all_questions
    questions_file = "questions.json"
    return [] unless File.exist?(questions_file)
    JSON.parse(File.read(questions_file))
  end
  
  # ===== EXAM SCHEDULING =====
  def create_exam_schedule(title, description, duration_minutes, scheduled_date, start_time, end_time, questions_list)
    schedules = JSON.parse(File.read("schedules.json"))
    
    schedule = {
      "id" => "schedule_#{Time.now.to_i}",
      "title" => title,
      "description" => description,
      "duration_minutes" => duration_minutes,
      "scheduled_date" => scheduled_date,
      "start_time" => start_time,
      "end_time" => end_time,
      "questions" => questions_list,
      "status" => "scheduled",
      "created_at" => Time.now.to_s
    }
    
    schedules << schedule
    File.write("schedules.json", JSON.dump(schedules))
    puts "✅ Exam scheduled"
    schedule
  end
  
  def get_all_schedules
    return [] unless File.exist?("schedules.json")
    JSON.parse(File.read("schedules.json"))
  end
  
  def get_schedule(schedule_id)
    schedules = get_all_schedules
    schedules.find { |s| s["id"] == schedule_id }
  end
  
  def get_active_schedules
    schedules = get_all_schedules
    now = Time.now
    
    schedules.select do |s|
      next unless s["status"] == "scheduled"
      
      begin
        start_time = Time.parse("#{s["scheduled_date"]} #{s["start_time"]}")
        end_time = Time.parse("#{s["scheduled_date"]} #{s["end_time"]}")
        now >= start_time && now <= end_time
      rescue
        false
      end
    end
  end
  
  def get_upcoming_schedules
    schedules = get_all_schedules
    now = Time.now
    
    schedules.select do |s|
      next unless s["status"] == "scheduled"
      
      begin
        start_time = Time.parse("#{s["scheduled_date"]} #{s["start_time"]}")
        start_time > now
      rescue
        false
      end
    end
  end
  
  # ===== EXAM ATTEMPTS =====
  def create_exam_attempt(student_id, schedule_id)
    attempts = JSON.parse(File.read("attempts.json"))
    
    attempt = {
      "id" => "attempt_#{Time.now.to_i}",
      "student_id" => student_id,
      "schedule_id" => schedule_id,
      "start_time" => Time.now.to_s,
      "status" => "in_progress",
      "answers" => [],
      "score" => nil
    }
    
    attempts << attempt
    File.write("attempts.json", JSON.dump(attempts))
    puts "✅ Exam attempt created"
    attempt
  end
  
  def submit_exam_attempt(attempt_id, answers, score)
    attempts = JSON.parse(File.read("attempts.json"))
    attempt = attempts.find { |a| a["id"] == attempt_id }
    
    if attempt
      attempt["answers"] = answers
      attempt["score"] = score
      attempt["status"] = "completed"
      attempt["end_time"] = Time.now.to_s
      File.write("attempts.json", JSON.dump(attempts))
      
      schedule = get_schedule(attempt["schedule_id"])
      student = get_student(attempt["student_id"])
      
      if schedule && student
        save_result(student["name"], score, schedule["questions"].length)
      end
      
      puts "✅ Exam submitted"
      true
    end
  end
  
  def get_student_attempts(student_id)
    return [] unless File.exist?("attempts.json")
    attempts = JSON.parse(File.read("attempts.json"))
    attempts.select { |a| a["student_id"] == student_id }
  end
  
  def get_all_attempts
    return [] unless File.exist?("attempts.json")
    JSON.parse(File.read("attempts.json"))
  end
  
  # ===== RESULTS MANAGEMENT =====
  def save_result(student_name, score, total)
    results_file = "results.json"
    unless File.exist?(results_file)
      File.write(results_file, JSON.dump([]))
    end
    
    results = JSON.parse(File.read(results_file))
    
    result = {
      "id" => "result_#{Time.now.to_i}",
      "student" => student_name,
      "score" => score,
      "total" => total,
      "percentage" => (score.to_f / total * 100).round(2),
      "date" => Time.now.to_s
    }
    
    results << result
    File.write(results_file, JSON.dump(results))
    puts "✅ Result saved"
    true
  end
  
  def get_student_results(student_name)
    return [] unless File.exist?("results.json")
    results = JSON.parse(File.read("results.json"))
    results.select { |r| r["student"] == student_name }
  end
  
  def get_all_results
    return [] unless File.exist?("results.json")
    JSON.parse(File.read("results.json"))
  end
end

# Update question
def update_question(question_id, question_text, options, correct_answer)
  questions = JSON.parse(File.read("questions.json"))
  question = questions.find { |q| q["id"] == question_id }
  
  if question
    question["text"] = question_text
    question["options"] = options
    question["correct"] = correct_answer
    question["updated_at"] = Time.now.to_s
    
    File.write("questions.json", JSON.dump(questions))
    puts "✅ Question updated in database helper"
    return true
  end
  false
end

# Update exam schedule
def update_exam_schedule(schedule_id, title, description, duration, date, start_time, end_time, status, questions)
  schedules = JSON.parse(File.read("schedules.json"))
  schedule = schedules.find { |s| s["id"] == schedule_id }
  
  if schedule
    schedule["title"] = title
    schedule["description"] = description
    schedule["duration_minutes"] = duration
    schedule["scheduled_date"] = date
    schedule["start_time"] = start_time
    schedule["end_time"] = end_time
    schedule["status"] = status
    schedule["questions"] = questions
    schedule["updated_at"] = Time.now.to_s
    
    File.write("schedules.json", JSON.dump(schedules))
    puts "✅ Exam schedule updated in database helper"
    return true
  end
  false
end