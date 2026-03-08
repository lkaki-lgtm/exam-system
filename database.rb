require 'json'
require 'date'
require 'set'

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
    create_violations_table
  end

  # ===== FILE INITIALIZATION =====
  def create_users_table
    @users_file = "users.json"
    unless File.exist?(@users_file)
      File.write(@users_file, JSON.dump({
        "admins" => [],
        "teachers" => [],
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

  def create_violations_table
    @violations_file = "violations.json"
    unless File.exist?(@violations_file)
      File.write(@violations_file, JSON.dump([]))
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
      "status" => "active",
      "assigned_exams" => []
    }
    data["students"] << student
    File.write("users.json", JSON.dump(data))
    student
  end

  def register_teacher(name, email, password)
    data = JSON.parse(File.read("users.json"))
    existing = data["teachers"].find { |t| t["email"].to_s.downcase == email.to_s.downcase }
    return nil if existing
    teacher = {
      "id" => "teacher_#{Time.now.to_i}",
      "name" => name,
      "email" => email,
      "password" => password,
      "registered_at" => Time.now.to_s,
      "assigned_exams" => []
    }
    data["teachers"] << teacher
    File.write("users.json", JSON.dump(data))
    teacher
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
      s["email"].to_s.downcase.strip == email.to_s.downcase.strip && s["password"].to_s == password.to_s
    end
    return { "type" => "student", "user" => student } if student
    teacher = data["teachers"].find do |t|
      t["email"].to_s.downcase.strip == email.to_s.downcase.strip && t["password"].to_s == password.to_s
    end
    return { "type" => "teacher", "user" => teacher } if teacher
    admin = data["admins"].find do |a|
      a["email"].to_s.downcase.strip == email.to_s.downcase.strip && a["password"].to_s == password.to_s
    end
    return { "type" => "admin", "user" => admin } if admin
    nil
  end

  def get_all_students
    return [] unless File.exist?("users.json")
    data = JSON.parse(File.read("users.json"))
    data["students"] || []
  end

  def get_all_teachers
    return [] unless File.exist?("users.json")
    data = JSON.parse(File.read("users.json"))
    data["teachers"] || []
  end

  def get_student(student_id)
    students = get_all_students
    students.find { |s| s["id"] == student_id }
  end

  def get_teacher(teacher_id)
    teachers = get_all_teachers
    teachers.find { |t| t["id"] == teacher_id }
  end

  # ===== TEACHER METHODS =====
  def get_teacher_exams(teacher_id)
    schedules = get_all_schedules
    schedules.select { |s| s["assigned_teacher_id"] == teacher_id }
  end

  def get_teacher_students(teacher_id)
    teacher_exams = get_teacher_exams(teacher_id)
    student_ids = teacher_exams.flat_map { |e| e["assigned_students"] || [] }.uniq
    student_ids.map { |id| get_student(id) }.compact
  end

  def get_active_teacher_exams(teacher_id)
    teacher_exams = get_teacher_exams(teacher_id)
    now = Time.now
    teacher_exams.select do |e|
      begin
        start_time = Time.parse("#{e["scheduled_date"]} #{e["start_time"]}")
        end_time = Time.parse("#{e["scheduled_date"]} #{e["end_time"]}")
        now >= start_time && now <= end_time && e["status"] == "active"
      rescue
        false
      end
    end
  end

  def get_active_exam_attempts(exam_id)
    attempts = get_all_attempts
    attempts.select { |a| a["schedule_id"] == exam_id && a["status"] == "in_progress" }
  end

  def get_teacher_exam_attempts(teacher_id)
    teacher_exams = get_teacher_exams(teacher_id)
    exam_ids = teacher_exams.map { |e| e["id"] }
    attempts = get_all_attempts
    attempts.select { |a| exam_ids.include?(a["schedule_id"]) }
  end

  def assign_students_to_exam(exam_id, student_ids)
    schedules = JSON.parse(File.read("schedules.json"))
    schedule = schedules.find { |s| s["id"] == exam_id }
    if schedule
      schedule["assigned_students"] = student_ids
      File.write("schedules.json", JSON.dump(schedules))
    end
  end

  def get_exam_students(exam_id)
    schedules = get_all_schedules
    exam = schedules.find { |s| s["id"] == exam_id }
    exam ? (exam["assigned_students"] || []) : []
  end

  def student_assigned_to_exam?(student_id, exam_id)
    exam_students = get_exam_students(exam_id)
    exam_students.include?(student_id)
  end

  def student_can_take_exam?(student_id, schedule_id)
    attempts = get_student_attempts(student_id)
    existing = attempts.find { |a| a["schedule_id"] == schedule_id }
    return true if existing.nil?
    if existing["answers"] && existing["answers"].any?
      return false
    end
    if ["completed", "terminated_for_malpractice", "removed_for_malpractice"].include?(existing["status"])
      return false
    end
    true
  end


  def get_student_assigned_exams(student_id)
    schedules = get_all_schedules
    schedules.select { |s| (s["assigned_students"] || []).include?(student_id) }
  end

  def get_active_student_exams(student_id)
  assigned = get_student_assigned_exams(student_id)
  now = Time.now
  attempts = get_student_attempts(student_id)

  final_exam_ids = attempts.select do |a|
    ["completed", "terminated_for_malpractice", "removed_for_malpractice"].include?(a["status"])
  end.map { |a| a["schedule_id"] }.to_set

  assigned.select do |e|
    next false if final_exam_ids.include?(e["id"])

    begin
      start_time = Time.parse("#{e["scheduled_date"]} #{e["start_time"]}")
      end_time = Time.parse("#{e["scheduled_date"]} #{e["end_time"]}")
      now >= start_time && now <= end_time && e["status"] == "active"
    rescue
      false
    end
  end
end

  def get_upcoming_student_exams(student_id)
    assigned = get_student_assigned_exams(student_id)
    now = Time.now
    assigned.select do |e|
      begin
        start_time = Time.parse("#{e["scheduled_date"]} #{e["start_time"]}")
        start_time > now && e["status"] == "scheduled"
      rescue
        false
      end
    end
  end

  def remove_student_for_malpractice(attempt_id, reason, removed_by)
    attempts = JSON.parse(File.read("attempts.json"))
    attempt = attempts.find { |a| a["id"] == attempt_id }
    if attempt
      attempt["status"] = "removed_for_malpractice"
      attempt["removal_reason"] = reason
      attempt["removed_by"] = removed_by
      attempt["removed_at"] = Time.now.to_s
      attempt["end_time"] = Time.now.to_s
      attempt["score"] = 0
      File.write("attempts.json", JSON.dump(attempts))
      log_proctoring_violation(attempt_id, "teacher_removal", { reason: reason, removed_by: removed_by })
      true
    else
      false
    end
  end

  def validate_attempt_access(student_id, schedule_id)
  attempts = get_student_attempts(student_id)
  existing = attempts.find { |a| a["schedule_id"] == schedule_id }
  return { allowed: true, message: nil } if existing.nil?

  case existing["status"]
  when "completed"
    { allowed: false, message: "You have already completed this exam." }
  when "terminated_for_malpractice"
    { allowed: false, message: "Your exam was terminated due to multiple violations. Contact your teacher." }
  when "removed_for_malpractice"
    { allowed: false, message: "You were removed from this exam by your teacher. Contact them for more information." }
  when "in_progress"
    { allowed: true, message: nil, attempt: existing }
  else
    { allowed: true, message: nil }
  end
end

  # ===== PROCTORING METHODS =====
  def log_proctoring_violation(attempt_id, violation_type, details = {})
    violations = JSON.parse(File.read("violations.json")) rescue []
    violation = {
      "id" => "violation_#{Time.now.to_i}",
      "attempt_id" => attempt_id,
      "type" => violation_type,
      "details" => details,
      "timestamp" => Time.now.to_s
    }
    violations << violation
    File.write("violations.json", JSON.dump(violations))
    attempts = JSON.parse(File.read("attempts.json"))
    attempt = attempts.find { |a| a["id"] == attempt_id }
    if attempt
      attempt["violations"] ||= []
      attempt["violations"] << violation
      attempt["violation_count"] = attempt["violations"].count
      if attempt["violations"].count >= 5
        attempt["status"] = "terminated_for_malpractice"
        attempt["termination_reason"] = "Multiple proctoring violations"
        attempt["terminated_at"] = Time.now.to_s
        attempt["end_time"] = Time.now.to_s
        attempt["score"] = 0
        puts "⚠️ Exam TERMINATED for attempt #{attempt_id} due to multiple violations"
      end
      File.write("attempts.json", JSON.dump(attempts))
    end
    violation
  end

  def get_proctoring_report(exam_id)
    schedules = get_all_schedules
    exam = schedules.find { |s| s["id"] == exam_id }
    return {} unless exam
    attempts = get_all_attempts.select { |a| a["schedule_id"] == exam_id }
    violations = JSON.parse(File.read("violations.json")) rescue []
    report = {
      "exam_title" => exam["title"],
      "total_students" => attempts.count,
      "students_with_violations" => 0,
      "total_violations" => 0,
      "violation_types" => {},
      "student_reports" => []
    }
    attempts.each do |attempt|
      student = get_student(attempt["student_id"])
      attempt_violations = violations.select { |v| v["attempt_id"] == attempt["id"] }
      if attempt_violations.any?
        report["students_with_violations"] += 1
        report["total_violations"] += attempt_violations.count
        attempt_violations.each do |v|
          report["violation_types"][v["type"]] ||= 0
          report["violation_types"][v["type"]] += 1
        end
        report["student_reports"] << {
          "student_name" => student ? student["name"] : "Unknown",
          "student_reg" => student ? student["reg_number"] : "Unknown",
          "violation_count" => attempt_violations.count,
          "status" => attempt["status"],
          "violations" => attempt_violations
        }
      end
    end
    report
  end

  def log_tab_switch(attempt_id)
    log_proctoring_violation(attempt_id, "tab_switch", { "message" => "Student switched to another tab", "severity" => "warning" })
  end

  def log_copy_paste(attempt_id, action)
    log_proctoring_violation(attempt_id, "copy_paste", { "action" => action, "message" => "Student attempted to #{action} during exam", "severity" => "warning" })
  end

  def log_window_blur(attempt_id)
    log_proctoring_violation(attempt_id, "window_blur", { "message" => "Student left the exam window", "severity" => "warning" })
  end

  def log_right_click(attempt_id)
    log_proctoring_violation(attempt_id, "right_click", { "message" => "Student attempted to right-click", "severity" => "warning" })
  end

  # ===== QUESTION MANAGEMENT =====
  def add_question(question_text, option1, option2, option3, option4, correct_answer, difficulty = "medium", topic = "general")
    questions = JSON.parse(File.read("questions.json"))
    question = {
      "id" => "question_#{Time.now.to_i}",
      "text" => question_text,
      "options" => [option1, option2, option3, option4],
      "correct" => correct_answer,
      "difficulty" => difficulty,
      "topic" => topic,
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

  def get_smart_questions(questions, count)
    by_difficulty = questions.group_by { |q| q["difficulty"] || "medium" }
    selected = []
    selected += (by_difficulty["easy"] || []).sample((count * 0.3).to_i) || []
    selected += (by_difficulty["medium"] || []).sample((count * 0.5).to_i) || []
    selected += (by_difficulty["hard"] || []).sample((count * 0.2).to_i) || []
    while selected.size < count
      remaining = questions.reject { |q| selected.include?(q) }
      selected << remaining.sample if remaining.any?
    end
    selected.shuffle
  end

  def get_question_analytics
    questions = get_all_questions
    attempts = get_all_attempts
    schedules = get_all_schedules
    question_stats = {}
    questions.each do |q|
      question_stats[q["id"]] = {
        text: q["text"],
        difficulty: q["difficulty"] || "medium",
        topic: q["topic"] || "general",
        times_used: 0,
        times_answered: 0,
        times_correct: 0,
        correct_percentage: 0
      }
    end
    attempts.each do |attempt|
      schedule = schedules.find { |s| s["id"] == attempt["schedule_id"] }
      next unless schedule && attempt["answers"]
      schedule["questions"].each_with_index do |q, i|
        next unless question_stats[q["id"]]
        question_stats[q["id"]][:times_used] += 1
        if attempt["answers"][i] && attempt["answers"][i]["answer"]
          question_stats[q["id"]][:times_answered] += 1
          if attempt["answers"][i]["answer"] == q["correct"]
            question_stats[q["id"]][:times_correct] += 1
          end
        end
      end
    end
    question_stats.each do |id, stats|
      if stats[:times_answered] > 0
        stats[:correct_percentage] = ((stats[:times_correct].to_f / stats[:times_answered]) * 100).round(2)
      end
    end
    question_stats
  end

  def get_student_performance_trends(days = 30)
    attempts = get_all_attempts
    trends = {}
    (0..days-1).each do |i|
      date = (Date.today - i).to_s
      trends[date] = { attempts: 0, avg_score: 0, total_score: 0 }
    end
    attempts.each do |attempt|
      next unless attempt["end_time"]
      date = attempt["end_time"][0..9]
      next unless trends[date]
      trends[date][:attempts] += 1
      trends[date][:total_score] += attempt["score"].to_f
    end
    trends.each do |date, data|
      if data[:attempts] > 0
        data[:avg_score] = (data[:total_score] / data[:attempts]).round(2)
      end
    end
    {
      labels: trends.keys.reverse,
      attempts: trends.values.map { |v| v[:attempts] }.reverse,
      scores: trends.values.map { |v| v[:avg_score] }.reverse
    }
  end

  def get_topic_performance
    questions = get_all_questions
    attempts = get_all_attempts
    schedules = get_all_schedules
    topics = {}
    attempts.each do |attempt|
      schedule = schedules.find { |s| s["id"] == attempt["schedule_id"] }
      next unless schedule && attempt["answers"]
      schedule["questions"].each_with_index do |q, i|
        topic = q["topic"] || "general"
        topics[topic] ||= { correct: 0, total: 0 }
        topics[topic][:total] += 1
        if attempt["answers"][i] && attempt["answers"][i]["answer"] == q["correct"]
          topics[topic][:correct] += 1
        end
      end
    end
    result = {}
    topics.each do |topic, data|
      result[topic] = {
        total: data[:total],
        correct: data[:correct],
        percentage: data[:total] > 0 ? ((data[:correct].to_f / data[:total]) * 100).round(2) : 0
      }
    end
    result
  end

  # ===== EXAM SCHEDULING =====
  def create_exam_schedule(title, description, duration_minutes, scheduled_date, start_time, end_time, questions_list, assigned_teacher_id = nil)
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
      "assigned_teacher_id" => assigned_teacher_id,
      "assigned_students" => [],
      "created_at" => Time.now.to_s
    }
    schedules << schedule
    File.write("schedules.json", JSON.dump(schedules))
    schedule
  end

  def get_all_schedules
    return [] unless File.exist?("schedules.json")
    JSON.parse(File.read("schedules.json"))
  rescue
    []
  end

  def get_schedule(schedule_id)
    schedules = get_all_schedules
    schedules.find { |s| s["id"] == schedule_id }
  end

  def get_active_schedules
    schedules = get_all_schedules
    now = Time.now
    active = schedules.select do |s|
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

  def get_student_performance_analytics(student_id)
    attempts = get_student_attempts(student_id)
    schedules = get_all_schedules
    topic_performance = {}
    attempts.each do |attempt|
      schedule = schedules.find { |s| s["id"] == attempt["schedule_id"] }
      next unless schedule
      schedule["questions"].each_with_index do |q, i|
        topic = q["topic"] || "general"
        topic_performance[topic] ||= { correct: 0, total: 0 }
        topic_performance[topic][:total] += 1
        if attempt["answers"] && attempt["answers"][i] && attempt["answers"][i]["answer"] == q["correct"]
          topic_performance[topic][:correct] += 1
        end
      end
    end
    progress_labels = []
    progress_data = []
    completed_attempts = attempts.select { |a| a["status"] == "completed" && a["end_time"] }
    completed_attempts.sort_by { |a| a["end_time"] }.each do |attempt|
      schedule = schedules.find { |s| s["id"] == attempt["schedule_id"] }
      next unless schedule
      progress_labels << (attempt["end_time"] ? attempt["end_time"][0..9] : attempt["start_time"][0..9])
      percentage = schedule["questions"].count > 0 ? ((attempt["score"].to_f / schedule["questions"].count) * 100).round(2) : 0
      progress_data << percentage
    end
    {
      "total_attempts" => attempts.count,
      "average_score" => attempts.any? ? (attempts.sum { |a| a["score"].to_f } / attempts.count).round(2) : 0,
      "highest_score" => attempts.map { |a| a["score"].to_f }.max || 0,
      "topic_performance" => topic_performance,
      "progress_labels" => progress_labels,
      "progress_data" => progress_data
    }
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
          all_schedules = JSON.parse(File.read("schedules.json"))
          index = all_schedules.find_index { |x| x["id"] == s["id"] }
          if index
            all_schedules[index] = s
            File.write("schedules.json", JSON.dump(all_schedules))
            updated = true
            puts "✅ Exam '#{s["title"]}' is now COMPLETED"
          end
          attempts = get_all_attempts
          attempts_updated = false
          attempts.each do |att|
            if att["schedule_id"] == s["id"] && att["status"] == "in_progress"
              att["status"] = "completed"
              att["end_time"] = Time.now.to_s
              if att["answers"] && att["answers"].any?
                score = 0
                s["questions"].each_with_index do |q, i|
                  score += 1 if att["answers"][i] && att["answers"][i]["answer"] == q["correct"]
                end
                att["score"] = score
              else
                att["score"] = 0
              end
              attempts_updated = true
            end
          end
          File.write("attempts.json", JSON.dump(attempts)) if attempts_updated
        end
      rescue => e
        puts "❌ Error updating exam: #{e.message}"
      end
    end
    updated
  end

  # ===== EXAM ATTEMPTS =====
  def create_exam_attempt(student_id, schedule_id)
  attempts = JSON.parse(File.read("attempts.json")) rescue []

  existing_attempts = attempts.select do |a|
    a["student_id"] == student_id && a["schedule_id"] == schedule_id
  end

  if existing_attempts.any?
    latest_attempt = existing_attempts.max_by { |a| a["start_time"].to_s }

    if ["completed", "terminated_for_malpractice", "removed_for_malpractice"].include?(latest_attempt["status"])
      puts "⛔ Blocked new attempt - final attempt exists: #{latest_attempt['status']}"
      return nil
    end

    if latest_attempt["status"] == "in_progress"
      puts "↩️ Returning existing in_progress attempt"
      return latest_attempt
    end
  end

  puts "✅ Creating new attempt for student #{student_id}"

  attempt = {
    "id" => "attempt_#{Time.now.to_i}_#{rand(1000)}",
    "student_id" => student_id,
    "schedule_id" => schedule_id,
    "start_time" => Time.now.to_s,
    "status" => "in_progress",
    "answers" => [],
    "score" => 0,
    "marked_questions" => [],
    "violations" => [],
    "violation_count" => 0
  }

  attempts << attempt
  File.write("attempts.json", JSON.pretty_generate(attempts))
  attempt
end

  def submit_exam_attempt(attempt_id, answers, score, feedback = nil, violations = [], warnings = [])
    attempts = JSON.parse(File.read("attempts.json"))
    attempt = attempts.find { |a| a["id"] == attempt_id }
    if attempt
      attempt["answers"] = answers
      attempt["score"] = score
      attempt["status"] = "completed"
      attempt["end_time"] = Time.now.to_s
      attempt["feedback"] = feedback if feedback
      attempt["violations"] = violations if violations.any?
      attempt["warnings"] = warnings if warnings.any?
      File.write("attempts.json", JSON.dump(attempts))
      schedule = get_schedule(attempt["schedule_id"])
      student = get_student(attempt["student_id"])
      if schedule && student
        save_result(student["name"], score, schedule["questions"].length)
      end
      true
    else
      false
    end
  end

  # ===== CHECK IF STUDENT HAS FINAL ATTEMPT =====
def student_has_final_attempt?(student_id, schedule_id)
  attempts = JSON.parse(File.read("attempts.json")) rescue []

  attempts.any? do |a|
    a["student_id"] == student_id &&
    a["schedule_id"] == schedule_id &&
    ["completed", "terminated_for_malpractice", "removed_for_malpractice"].include?(a["status"])
  end
end

  def mark_question_for_review(attempt_id, question_index, marked)
    attempts = JSON.parse(File.read("attempts.json"))
    attempt = attempts.find { |a| a["id"] == attempt_id }
    if attempt
      attempt["marked_questions"] ||= []
      if marked
        attempt["marked_questions"] << question_index unless attempt["marked_questions"].include?(question_index)
      else
        attempt["marked_questions"].delete(question_index)
      end
      File.write("attempts.json", JSON.dump(attempts))
    end
  end

  # ===== SAVE STUDENT ANSWER (AUTO SAVE) =====
def save_student_answer(attempt_id, question_index, answer)
  attempts = JSON.parse(File.read("attempts.json"))

  attempt = attempts.find { |a| a["id"] == attempt_id }

  return unless attempt

  attempt["answers"] ||= []

  existing = attempt["answers"].find { |a| a["question_index"] == question_index }

  if existing
    existing["answer"] = answer
  else
    attempt["answers"] << {
      "question_index" => question_index,
      "answer" => answer
    }
  end

  File.write("attempts.json", JSON.pretty_generate(attempts))
end

  def get_student_attempts(student_id)
  return [] unless File.exist?("attempts.json")

  begin
    attempts = JSON.parse(File.read("attempts.json"))
  rescue
    attempts = []
  end

  attempts.select { |a| a["student_id"] == student_id }
end

  def get_attempt(attempt_id)
    attempts = get_all_attempts
    attempts.find { |a| a["id"] == attempt_id }
  end

  def get_all_attempts
  return [] unless File.exist?("attempts.json")

  begin
    JSON.parse(File.read("attempts.json"))
  rescue
    []
  end
end

  # ===== ANALYTICS =====
  def get_system_analytics
    students = get_all_students
    teachers = get_all_teachers
    admins = JSON.parse(File.read("users.json"))["admins"] || []
    questions = get_all_questions
    schedules = get_all_schedules
    attempts = get_all_attempts
    violations = JSON.parse(File.read("violations.json")) rescue []
    easy_questions = questions.count { |q| q["difficulty"] == "easy" }
    medium_questions = questions.count { |q| q["difficulty"] == "medium" }
    hard_questions = questions.count { |q| q["difficulty"] == "hard" }
    completed_exams = attempts.count { |a| a["status"] == "completed" }
    in_progress = attempts.count { |a| a["status"] == "in_progress" }
    terminated = attempts.count { |a| a["status"] == "terminated_for_malpractice" }
    scheduled = schedules.count { |s| s["status"] == "scheduled" }
    scores = attempts.map { |a| a["score"].to_f }
    avg_score = scores.any? ? (scores.sum / scores.count).round(2) : 0
    recent = []
    attempts.last(5).each do |a|
      student = get_student(a["student_id"])
      recent << {
        "icon" => "📝",
        "message" => "#{student["name"]} completed an exam",
        "time" => a["end_time"] ? a["end_time"][0..9] : a["start_time"][0..9]
      }
    end
    performance_labels = (0..6).map { |i| (Date.today - i).to_s }
    performance_data = performance_labels.map do |date|
      day_attempts = attempts.select { |a| a["end_time"] && a["end_time"][0..9] == date }
      day_scores = day_attempts.map { |a| a["score"].to_f }
      day_scores.any? ? (day_scores.sum / day_scores.count).round(2) : nil
    end.reverse
    {
      "total_users" => students.count + teachers.count + admins.count,
      "admin_count" => admins.count,
      "teacher_count" => teachers.count,
      "student_count" => students.count,
      "active_students" => students.count { |s| s["status"] == "active" },
      "total_questions" => questions.count,
      "easy_questions" => easy_questions,
      "medium_questions" => medium_questions,
      "hard_questions" => hard_questions,
      "total_exams" => schedules.count,
      "total_attempts" => attempts.count,
      "completed_exams" => completed_exams,
      "in_progress" => in_progress,
      "terminated" => terminated,
      "scheduled" => scheduled,
      "average_score" => avg_score,
      "malpractice_cases" => violations.count,
      "recent_activity" => recent,
      "performance_labels" => performance_labels,
      "performance_data" => performance_data
    }
  end

  def get_student_analytics(student_id)
    attempts = get_student_attempts(student_id)
    schedules = get_all_schedules
    topic_performance = {}
    attempts.each do |attempt|
      schedule = schedules.find { |s| s["id"] == attempt["schedule_id"] }
      next unless schedule
      schedule["questions"].each_with_index do |q, i|
        topic = q["topic"] || "general"
        topic_performance[topic] ||= { correct: 0, total: 0 }
        topic_performance[topic][:total] += 1
        if attempt["answers"][i] && attempt["answers"][i]["answer"] == q["correct"]
          topic_performance[topic][:correct] += 1
        end
      end
    end
    progress_labels = attempts.map { |a| a["end_time"] ? a["end_time"][0..9] : a["start_time"][0..9] }.uniq
    progress_data = progress_labels.map do |date|
      day_attempts = attempts.select { |a| a["end_time"] && a["end_time"][0..9] == date }
      day_scores = day_attempts.map { |a| a["score"].to_f }
      day_scores.any? ? (day_scores.sum / day_scores.count).round(2) : 0
    end
    {
      "total_attempts" => attempts.count,
      "average_score" => attempts.any? ? (attempts.sum { |a| a["score"].to_f } / attempts.count).round(2) : 0,
      "highest_score" => attempts.map { |a| a["score"].to_f }.max || 0,
      "topic_performance" => topic_performance,
      "progress_labels" => progress_labels,
      "progress_data" => progress_data
    }
  end

  def generate_feedback(attempt_id, answers, questions)
    score = 0
    weak_areas = []
    answers.each_with_index do |ans, i|
      if ans["answer"] == questions[i]["correct"]
        score += 1
      else
        topic = questions[i]["topic"] || "general"
        weak_areas << topic
      end
    end
    percentage = (score.to_f / questions.length * 100).round(2)
    feedback = {
      "score" => score,
      "total" => questions.length,
      "percentage" => percentage,
      "message" => percentage >= 80 ? "🌟 Excellent work!" : percentage >= 60 ? "📚 Good job! Keep practicing." : "💪 Keep learning! You'll do better next time.",
      "weak_areas" => weak_areas.uniq.first(3),
      "suggestions" => generate_suggestions(weak_areas)
    }
    feedback
  end

  def generate_suggestions(weak_areas)
    suggestions = []
    weak_areas.uniq.first(3).each do |area|
      suggestions << "Focus on #{area} topics"
    end
    suggestions << "Review your answers and try again" if suggestions.empty?
    suggestions
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


