require 'json'
require 'date'

class ExamDatabase
  
  def initialize
    initialize_tables
  end
  
  def initialize_tables
    create_users_table
    create_questions_table
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
  
  def create_questions_table
    @questions_file = "questions.json"
    unless File.exist?(@questions_file)
      File.write(@questions_file, JSON.dump([]))
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
    data = JSON.parse(File.read("users.json"))
    
    existing_email = data["students"].find { |s| s["email"].to_s.downcase == email.to_s.downcase }
    return nil if existing_email
    
    existing_reg = data["students"].find { |s| s["reg_number"].to_s == reg_number.to_s }
    return nil if existing_reg
    
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
    student
  end
  
  def register_admin(name, email, password)
    data = JSON.parse(File.read("users.json"))
    
    existing = data["admins"].find { |a| a["email"].to_s.downcase == email.to_s.downcase }
    return nil if existing
    
    admin = {
      "id" => "admin_#{Time.now.to_i}",
      "name" => name,
      "email" => email,
      "password" => password,
      "registered_at" => Time.now.to_s
    }
    
    data["admins"] << admin
    File.write("users.json", JSON.dump(data))
    admin
  end
  
  def authenticate_user(email, password)
    return nil unless File.exist?("users.json")
    
    data = JSON.parse(File.read("users.json"))
    
    student = data["students"].find do |s|
      s["email"].to_s.downcase.strip == email.to_s.downcase.strip && 
      s["password"].to_s == password.to_s
    end
    return {"type" => "student", "user" => student} if student
    
    admin = data["admins"].find do |a|
      a["email"].to_s.downcase.strip == email.to_s.downcase.strip && 
      a["password"].to_s == password.to_s
    end
    return {"type" => "admin", "user" => admin} if admin
    
    nil
  end
  
  def get_all_students
    return [] unless File.exist?("users.json")
    data = JSON.parse(File.read("users.json"))
    data["students"] || []
  end
  
  def get_student(student_id)
    students = get_all_students
    students.find { |s| s["id"] == student_id }
  end
  
  # ===== QUESTION MANAGEMENT =====
  def add_question(question_text, option1, option2, option3, option4, correct_answer)
    questions = JSON.parse(File.read("questions.json"))
    
    question = {
      "id" => "question_#{Time.now.to_i}",
      "text" => question_text,
      "options" => [option1, option2, option3, option4],
      "correct" => correct_answer,
      "created_at" => Time.now.to_s
    }
    
    questions << question
    File.write("questions.json", JSON.dump(questions))
    true
  end
  
  def get_all_questions
    return [] unless File.exist?("questions.json")
    JSON.parse(File.read("questions.json"))
  end
  
  def delete_question(question_id)
    questions = JSON.parse(File.read("questions.json"))
    questions.delete_if { |q| q["id"] == question_id }
    File.write("questions.json", JSON.dump(questions))
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
    
    active = schedules.select do |s|
      # Include exams that are already marked active
      if s["status"] == "active"
        next true
      end
      
      next false unless s["status"] == "scheduled"
      
      begin
        start_time = Time.parse("#{s["scheduled_date"]} #{s["start_time"]}")
        end_time = Time.parse("#{s["scheduled_date"]} #{s["end_time"]}")
        now >= start_time && now <= end_time
      rescue
        false
      end
    end
    
    active
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
  
  def delete_schedule(schedule_id)
    schedules = JSON.parse(File.read("schedules.json"))
    schedules.delete_if { |s| s["id"] == schedule_id }
    File.write("schedules.json", JSON.dump(schedules))
  end

  # ===== AUTO-UPDATE EXAM STATUSES (NEW METHOD) =====
  def update_exam_statuses
    schedules = get_all_schedules
    now = Time.now
    updated = false

    schedules.each do |s|
      begin
        exam_start = Time.parse("#{s["scheduled_date"]} #{s["start_time"]}")
        exam_end = Time.parse("#{s["scheduled_date"]} #{s["end_time"]}")

        if now >= exam_start && now <= exam_end && s["status"] == "scheduled"
          s["status"] = "active"
          # Update in file
          all_schedules = JSON.parse(File.read("schedules.json"))
          index = all_schedules.find_index { |x| x["id"] == s["id"] }
          if index
            all_schedules[index] = s
            File.write("schedules.json", JSON.dump(all_schedules))
            updated = true
            puts "✅ Exam '#{s["title"]}' is now ACTIVE"
          end
        elsif now > exam_end && s["status"] != "completed"
          s["status"] = "completed"
          # Update in file
          all_schedules = JSON.parse(File.read("schedules.json"))
          index = all_schedules.find_index { |x| x["id"] == s["id"] }
          if index
            all_schedules[index] = s
            File.write("schedules.json", JSON.dump(all_schedules))
            updated = true
            puts "✅ Exam '#{s["title"]}' is now COMPLETED"
          end
        end
      rescue => e
        puts "❌ Error updating exam: #{e.message}"
      end
    end

    updated
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
    results = JSON.parse(File.read("results.json"))
    
    result = {
      "id" => "result_#{Time.now.to_i}",
      "student" => student_name,
      "score" => score,
      "total" => total,
      "percentage" => (score.to_f / total * 100).round(2),
      "date" => Time.now.to_s
    }
    
    results << result
    File.write("results.json", JSON.dump(results))
    true
  end
  
  def get_all_results
    return [] unless File.exist?("results.json")
    JSON.parse(File.read("results.json"))
  end
  
  def get_student_results(student_name)
    results = get_all_results
    results.select { |r| r["student"] == student_name }
  end
end