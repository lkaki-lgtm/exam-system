require 'sequel'
require './database_connection'
require './db_helper'
require 'date'
require 'set'
require 'json'
require 'time'

class ExamDatabase
  def initialize
  end

  # =========================
  # HELPERS
  # =========================
  def stringify_hash(hash)
    return nil unless hash
    hash.transform_keys(&:to_s)
  end

  def stringify_array(arr)
    (arr || []).map { |h| stringify_hash(h) }
  end

  def parse_json_field(value, default = nil)
    return default if value.nil? || value == ""
    JSON.parse(value)
  rescue
    default
  end

  def question_row_to_hash(row)
    return nil unless row

    {
      "id" => row[:id],
      "text" => row[:text],
      "options" => [row[:option1], row[:option2], row[:option3], row[:option4]],
      "correct" => row[:correct_answer],
      "difficulty" => row[:difficulty] || "medium",
      "topic" => row[:topic] || "general",
      "created_at" => row[:created_at]&.to_s
    }
  end

  def schedule_questions(schedule_id)
    DB[:schedule_questions]
      .where(schedule_id: schedule_id)
      .order(:position)
      .all
      .map do |sq|
        q = DB[:questions].where(id: sq[:question_id]).first
        question_row_to_hash(q)
      end
      .compact
  end

  def schedule_student_ids(schedule_id)
    DB[:schedule_students]
      .where(schedule_id: schedule_id)
      .all
      .map { |row| row[:student_id] }
  end

  def schedule_row_to_hash(row)
  return nil unless row

  {
    "id" => row[:id],
    "title" => row[:title],
    "description" => row[:description],
    "duration_minutes" => row[:duration_minutes],
    "scheduled_date" => row[:scheduled_date].to_s,
    "start_time" => row[:start_time],
    "end_time" => row[:end_time],
    "status" => row[:status],
    "teacher_id" => row[:teacher_id],
    "assigned_teacher_id" => row[:teacher_id],
    "assigned_students" => schedule_student_ids(row[:id]),
    "questions" => schedule_questions(row[:id]),
    "created_at" => row[:created_at]&.to_s
  }
end

  def attempt_answers(attempt_id)
    DB[:answers]
      .where(attempt_id: attempt_id)
      .order(:question_index)
      .all
      .map do |a|
        {
          "question_index" => a[:question_index],
          "question_id" => a[:question_id],
          "answer" => a[:answer]
        }
      end
  end

  def attempt_marked_questions(attempt_id)
    DB[:answers]
      .where(attempt_id: attempt_id, marked_for_review: true)
      .order(:question_index)
      .all
      .map { |a| a[:question_index] }
  end

  def attempt_violations(attempt_id)
    DB[:violations]
      .where(attempt_id: attempt_id)
      .order(:created_at)
      .all
      .map do |v|
        {
          "id" => v[:id],
          "attempt_id" => v[:attempt_id],
          "type" => v[:violation_type],
          "details" => parse_json_field(v[:details_json], {}),
          "timestamp" => v[:created_at]&.to_s
        }
      end
  end

  def attempt_row_to_hash(row)
    return nil unless row

    violations = attempt_violations(row[:id])

    {
      "id" => row[:id],
      "student_id" => row[:student_id],
      "schedule_id" => row[:schedule_id],
      "start_time" => row[:start_time]&.to_s,
      "end_time" => row[:end_time]&.to_s,
      "status" => row[:status],
      "answers" => attempt_answers(row[:id]),
      "score" => row[:score] || 0,
      "marked_questions" => attempt_marked_questions(row[:id]),
      "violations" => violations,
      "violation_count" => row[:violation_count] || violations.count,
      "feedback" => parse_json_field(row[:feedback_json], nil),
      "warnings" => parse_json_field(row[:warnings_json], []),
      "removal_reason" => row[:removal_reason],
      "removed_by" => row[:removed_by],
      "removed_at" => row[:removed_at]&.to_s,
      "termination_reason" => row[:termination_reason],
      "terminated_at" => row[:terminated_at]&.to_s,
      "completed_by_teacher" => row[:completed_by_teacher],
      "teacher_notes" => row[:teacher_notes]
    }
  end

  # =========================
  # USER MANAGEMENT
  # =========================
  def register_student(name, email, reg_number, password)
    existing_email = DB[:users].where(Sequel.function(:lower, :email) => email.to_s.downcase).first
    return nil if existing_email

    existing_reg = DB[:users].where(reg_number: reg_number).first
    return nil if existing_reg

    now = Time.now
    id = DB[:users].insert(
      name: name,
      email: email,
      reg_number: reg_number,
      password: password,
      role: "student",
      status: "active",
      created_at: now,
      updated_at: now
    )

    get_student(id)
  end

  def register_teacher(name, email, password)
    existing = DB[:users].where(Sequel.function(:lower, :email) => email.to_s.downcase).first
    return nil if existing

    now = Time.now
    id = DB[:users].insert(
      name: name,
      email: email,
      password: password,
      role: "teacher",
      status: "active",
      created_at: now,
      updated_at: now
    )

    get_teacher(id)
  end

  def register_admin(name, email, password)
    existing = DB[:users].where(Sequel.function(:lower, :email) => email.to_s.downcase).first
    return nil if existing

    now = Time.now
    id = DB[:users].insert(
      name: name,
      email: email,
      password: password,
      role: "admin",
      status: "active",
      created_at: now,
      updated_at: now
    )

    stringify_hash(DB[:users].where(id: id).first)
  end

  def authenticate_user(email, password)
    user = DB[:users].where(Sequel.function(:lower, :email) => email.to_s.downcase.strip).first
    return nil unless user
    return nil unless user[:password].to_s == password.to_s

    {
      "type" => user[:role],
      "user" => stringify_hash(user)
    }
  end

  def get_all_admins
    stringify_array(DB[:users].where(role: "admin").all)
  end

  def get_all_students
    stringify_array(DB[:users].where(role: "student").all)
  end

  def get_all_teachers
    stringify_array(DB[:users].where(role: "teacher").all).compact
  end

  def get_student(student_id)
  stringify_hash(DB[:users].where(id: student_id, role: "student").first)
end

def get_teacher(teacher_id)
  stringify_hash(DB[:users].where(id: teacher_id, role: "teacher").first)
end

  # =========================
  # TEACHER METHODS
  # =========================
  def get_teacher_exams(teacher_id)
  get_all_schedules.select do |s|
    s["teacher_id"].to_s == teacher_id.to_s || s["assigned_teacher_id"].to_s == teacher_id.to_s
  end
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
    DB[:attempts]
      .where(schedule_id: exam_id, status: "in_progress")
      .all
      .map { |row| attempt_row_to_hash(row) }
  end

  def get_teacher_exam_attempts(teacher_id)
    teacher_exam_ids = get_teacher_exams(teacher_id).map { |e| e["id"] }
    DB[:attempts]
      .where(schedule_id: teacher_exam_ids)
      .all
      .map { |row| attempt_row_to_hash(row) }
  end

  def assign_students_to_exam(exam_id, student_ids)
  DB[:schedule_students].where(schedule_id: exam_id.to_i).delete

  (student_ids || []).each do |student_id|
    DB[:schedule_students].insert(
      schedule_id: exam_id.to_i,
      student_id: student_id.to_i
    )
  end

  true
end

  def get_exam_students(exam_id)
    schedule_student_ids(exam_id)
  end

  def student_assigned_to_exam?(student_id, exam_id)
    get_exam_students(exam_id).map(&:to_s).include?(student_id.to_s)
  end

  def student_can_take_exam?(student_id, schedule_id)
    attempts = get_student_attempts(student_id)
    existing = attempts.find { |a| a["schedule_id"].to_s == schedule_id.to_s }
    return true if existing.nil?

    return false if existing["answers"] && existing["answers"].any?
    return false if ["completed", "terminated_for_malpractice", "removed_for_malpractice"].include?(existing["status"])

    true
  end

  def get_student_assigned_exams(student_id)
    schedule_ids = DB[:schedule_students].where(student_id: student_id).all.map { |r| r[:schedule_id] }
    DB[:schedules].where(id: schedule_ids).all.map { |row| schedule_row_to_hash(row) }
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
    attempt = DB[:attempts].where(id: attempt_id).first
    return false unless attempt

    DB[:attempts].where(id: attempt_id).update(
      status: "removed_for_malpractice",
      removal_reason: reason,
      removed_by: removed_by,
      removed_at: Time.now,
      end_time: Time.now,
      score: 0,
      updated_at: Time.now
    )

    log_proctoring_violation(attempt_id, "teacher_removal", { reason: reason, removed_by: removed_by })
    true
  end

  def validate_attempt_access(student_id, schedule_id)
    attempts = get_student_attempts(student_id)
    existing = attempts.find { |a| a["schedule_id"].to_s == schedule_id.to_s }
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

  # =========================
  # PROCTORING METHODS
  # =========================
  def log_proctoring_violation(attempt_id, violation_type, details = {})
  DB[:violations].insert(
    attempt_id: attempt_id,
    violation_type: violation_type,
    details_json: details.to_json,
    created_at: Time.now
  )

  violation_count = DB[:violations].where(attempt_id: attempt_id).count

  DB[:attempts].where(id: attempt_id).update(
    violation_count: violation_count,
    updated_at: Time.now
  )

  if violation_count >= 3
    DB[:attempts].where(id: attempt_id).update(
      status: "terminated_for_malpractice",
      termination_reason: "Multiple proctoring violations",
      terminated_at: Time.now,
      end_time: Time.now,
      score: 0,
      updated_at: Time.now
    )
    puts "⚠️ Exam TERMINATED for attempt #{attempt_id} due to multiple violations"
  end

  {
    "attempt_id" => attempt_id,
    "type" => violation_type,
    "details" => details,
    "timestamp" => Time.now.to_s
  }
end

  def get_proctoring_report(exam_id)
    exam = get_schedule(exam_id)
    return {} unless exam

    attempts = get_all_attempts.select { |a| a["schedule_id"].to_s == exam_id.to_s }

    report = {
      "exam_title" => exam["title"],
      "total_students" => attempts.count,
      "students_with_violations" => 0,
      "total_violations" => 0,
      "violation_types" => {},
      "student_reports" => []
    }

    attempts.each do |attempt|
      violations_for_attempt = attempt_violations(attempt["id"])
      student = get_student(attempt["student_id"])

      if violations_for_attempt.any?
        report["students_with_violations"] += 1
        report["total_violations"] += violations_for_attempt.count

        violations_for_attempt.each do |v|
          report["violation_types"][v["type"]] ||= 0
          report["violation_types"][v["type"]] += 1
        end

        report["student_reports"] << {
          "student_name" => student ? student["name"] : "Unknown",
          "student_reg" => student ? student["reg_number"] : "Unknown",
          "violation_count" => violations_for_attempt.count,
          "status" => attempt["status"],
          "violations" => violations_for_attempt
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

  # =========================
  # QUESTION MANAGEMENT
  # =========================
  def add_question(question_text, option1, option2, option3, option4, correct_answer, difficulty = "medium", topic = "general")
  now = Time.now
  DB[:questions].insert(
    text: question_text,
    option1: option1,
    option2: option2,
    option3: option3,
    option4: option4,
    correct_answer: correct_answer,
    difficulty: difficulty,
    topic: topic,
    created_at: now
  )
  true
end

  def get_all_questions
    DB[:questions].all.map { |q| question_row_to_hash(q) }
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

    selected.compact.shuffle
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
      schedule = schedules.find { |s| s["id"].to_s == attempt["schedule_id"].to_s }
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

    question_stats.each do |_id, stats|
      if stats[:times_answered] > 0
        stats[:correct_percentage] = ((stats[:times_correct].to_f / stats[:times_answered]) * 100).round(2)
      end
    end

    question_stats
  end

  def get_student_performance_trends(days = 30)
    attempts = get_all_attempts
    trends = {}

    (0..days - 1).each do |i|
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

    trends.each do |_date, data|
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
    attempts = get_all_attempts
    schedules = get_all_schedules
    topics = {}

    attempts.each do |attempt|
      schedule = schedules.find { |s| s["id"].to_s == attempt["schedule_id"].to_s }
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

  # =========================
  # EXAM SCHEDULING
  # =========================
  def create_exam_schedule(title, description, duration_minutes, scheduled_date, start_time, end_time, questions_list, assigned_teacher_id = nil)
  now = Time.now

  schedule_id = DB[:schedules].insert(
    title: title,
    description: description,
    duration_minutes: duration_minutes.to_i,
    scheduled_date: Date.parse(scheduled_date.to_s),
    start_time: start_time,
    end_time: end_time,
    status: "scheduled",
    teacher_id: assigned_teacher_id,
    created_at: now
  )

  (questions_list || []).each_with_index do |question, index|
    question_id =
      if question.is_a?(Hash)
        question["id"] || question[:id]
      else
        question
      end

    DB[:schedule_questions].insert(
      schedule_id: schedule_id,
      question_id: question_id.to_i,
      position: index
    )
  end

  get_schedule(schedule_id)
end

  def get_all_schedules
    DB[:schedules].all.map { |row| schedule_row_to_hash(row) }
  rescue
    []
  end

  def get_schedule(schedule_id)
  row = DB[:schedules].where(id: schedule_id.to_i).first
  schedule_row_to_hash(row)
end

  def get_active_schedules
    schedules = get_all_schedules
    now = Time.now

    schedules.select do |s|
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
  end

  def get_student_performance_analytics(student_id)
    attempts = get_student_attempts(student_id)
    schedules = get_all_schedules
    topic_performance = {}

    attempts.each do |attempt|
      schedule = schedules.find { |s| s["id"].to_s == attempt["schedule_id"].to_s }
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
      schedule = schedules.find { |s| s["id"].to_s == attempt["schedule_id"].to_s }
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
    schedules = DB[:schedules].all
    now = Time.now
    updated = false

    schedules.each do |s|
      begin
        exam_start = Time.parse("#{s[:scheduled_date]} #{s[:start_time]}")
        exam_end = Time.parse("#{s[:scheduled_date]} #{s[:end_time]}")

        if now >= exam_start && now <= exam_end && s[:status] == "scheduled"
          DB[:schedules].where(id: s[:id]).update(status: "active", updated_at: Time.now)
          updated = true
          puts "✅ Exam '#{s[:title]}' is now ACTIVE"

        elsif now > exam_end && s[:status] != "completed"
          DB[:schedules].where(id: s[:id]).update(status: "completed", updated_at: Time.now)
          updated = true
          puts "✅ Exam '#{s[:title]}' is now COMPLETED"

          DB[:attempts].where(schedule_id: s[:id], status: "in_progress").all.each do |att|
            schedule = get_schedule(s[:id])
            answers = attempt_answers(att[:id])
            score = 0

            if answers.any?
              schedule["questions"].each_with_index do |q, i|
                score += 1 if answers[i] && answers[i]["answer"] == q["correct"]
              end
            end

            DB[:attempts].where(id: att[:id]).update(
              status: "completed",
              end_time: Time.now,
              score: score,
              updated_at: Time.now
            )
          end
        end
      rescue => e
        puts "❌ Error updating exam: #{e.message}"
      end
    end

    updated
  end

  # =========================
  # EXAM ATTEMPTS
  # =========================
  def create_exam_attempt(student_id, schedule_id)
    existing_attempts = DB[:attempts]
      .where(student_id: student_id, schedule_id: schedule_id)
      .order(Sequel.desc(:start_time))
      .all

    if existing_attempts.any?
      latest_attempt = attempt_row_to_hash(existing_attempts.first)

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

    now = Time.now
    attempt_id = DB[:attempts].insert(
      student_id: student_id,
      schedule_id: schedule_id,
      start_time: Time.now,
      status: "in_progress",
      score: 0,
      violation_count: 0,
      created_at: now,
      updated_at: now
    )

    get_attempt(attempt_id)
  end

  def submit_exam_attempt(attempt_id, answers, score, feedback = nil, violations = [], warnings = [])
  attempt = DB[:attempts].where(id: attempt_id).first
  return false unless attempt

  DB[:answers].where(attempt_id: attempt_id).delete

  (answers || []).each_with_index do |ans, index|
    question_id = ans["question_id"] || ans[:question_id]
    answer_value = ans["answer"] || ans[:answer]

    DB[:answers].insert(
      attempt_id: attempt_id,
      question_id: question_id,
      question_index: index,
      answer: answer_value,
      marked_for_review: false,
      created_at: Time.now,
      updated_at: Time.now
    )
  end

  DB[:attempts].where(id: attempt_id).update(
    score: score,
    status: "completed",
    end_time: Time.now,
    feedback_json: feedback ? feedback.to_json : nil,
    warnings_json: warnings.to_json,
    updated_at: Time.now
  )

  (violations || []).each do |v|
    log_proctoring_violation(
      attempt_id,
      v["type"] || v[:type] || "client_violation",
      v
    )
  end

  updated_attempt = get_attempt(attempt_id)
  schedule = get_schedule(updated_attempt["schedule_id"])
  return false unless schedule

  final_score =
    if ["terminated_for_malpractice", "removed_for_malpractice"].include?(updated_attempt["status"])
      0
    else
      score
    end

  save_result(
    updated_attempt["student_id"],
    updated_attempt["schedule_id"],
    final_score,
    schedule["questions"].length
  )

  if ["terminated_for_malpractice", "removed_for_malpractice"].include?(updated_attempt["status"])
    DB[:attempts].where(id: attempt_id).update(score: 0, updated_at: Time.now)
  end

  true
end

  def student_has_final_attempt?(student_id, schedule_id)
    DB[:attempts]
      .where(student_id: student_id, schedule_id: schedule_id)
      .where(status: ["completed", "terminated_for_malpractice", "removed_for_malpractice"])
      .count > 0
  end

  def mark_question_for_review(attempt_id, question_index, marked)
    answer = DB[:answers].where(attempt_id: attempt_id, question_index: question_index).first

    if answer
      DB[:answers].where(id: answer[:id]).update(
        marked_for_review: marked,
        updated_at: Time.now
      )
    else
      attempt = get_attempt(attempt_id)
      schedule = get_schedule(attempt["schedule_id"])
      question = schedule && schedule["questions"] ? schedule["questions"][question_index] : nil

      DB[:answers].insert(
        attempt_id: attempt_id,
        question_id: question ? question["id"] : nil,
        question_index: question_index,
        answer: nil,
        marked_for_review: marked,
        created_at: Time.now,
        updated_at: Time.now
      )
    end

    true
  end

  def save_student_answer(attempt_id, question_index, answer)
    attempt = get_attempt(attempt_id)
    return unless attempt

    schedule = get_schedule(attempt["schedule_id"])
    question = schedule && schedule["questions"] ? schedule["questions"][question_index] : nil
    existing = DB[:answers].where(attempt_id: attempt_id, question_index: question_index).first

    if existing
      DB[:answers].where(id: existing[:id]).update(
        answer: answer,
        question_id: question ? question["id"] : existing[:question_id],
        updated_at: Time.now
      )
    else
      DB[:answers].insert(
        attempt_id: attempt_id,
        question_id: question ? question["id"] : nil,
        question_index: question_index,
        answer: answer,
        marked_for_review: false,
        created_at: Time.now,
        updated_at: Time.now
      )
    end
  end

  def get_student_attempts(student_id)
    DB[:attempts]
      .where(student_id: student_id)
      .order(:start_time)
      .all
      .map { |row| attempt_row_to_hash(row) }
  end

  def get_attempt(attempt_id)
    row = DB[:attempts].where(id: attempt_id).first
    attempt_row_to_hash(row)
  end

  def get_all_attempts
    DB[:attempts]
      .order(:start_time)
      .all
      .map { |row| attempt_row_to_hash(row) }
  end

  # =========================
  # ANALYTICS
  # =========================
  def get_system_analytics
    students = get_all_students
    teachers = get_all_teachers
    admins = stringify_array(DB[:users].where(role: "admin").all)
    questions = get_all_questions
    schedules = get_all_schedules
    attempts = get_all_attempts
    violations = DB[:violations].all

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
        "message" => "#{student ? student["name"] : 'Unknown'} completed an exam",
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

  def update_question(id, text, opt1, opt2, opt3, opt4, correct, difficulty, topic)
    DB[:questions].where(id: id).update(
      text: text,
      option1: opt1,
      option2: opt2,
      option3: opt3,
      option4: opt4,
      correct_answer: correct,
      difficulty: difficulty,
      topic: topic
    )
  end

def delete_question(id)
  DB[:schedule_questions].where(question_id: id).delete
  DB[:answers].where(question_id: id).delete
  DB[:questions].where(id: id).delete
end

def delete_all_questions
  DB[:answers].delete
  DB[:schedule_questions].delete
  DB[:questions].delete
end

def update_exam(schedule_id, attrs = {})
  DB[:schedules].where(id: schedule_id).update(
    title: attrs[:title],
    description: attrs[:description],
    duration_minutes: attrs[:duration_minutes],
    scheduled_date: attrs[:scheduled_date],
    start_time: attrs[:start_time],
    end_time: attrs[:end_time],
    status: attrs[:status],
    teacher_id: attrs[:assigned_teacher_id],
    updated_at: Time.now
  )

  if attrs[:question_ids]
    DB[:schedule_questions].where(schedule_id: schedule_id).delete

    attrs[:question_ids].each_with_index do |qid, index|
      DB[:schedule_questions].insert(
        schedule_id: schedule_id,
        question_id: qid,
        position: index
      )
    end
  end
end

def delete_exam(schedule_id)
  attempt_ids = DB[:attempts].where(schedule_id: schedule_id).select_map(:id)

  DB[:answers].where(attempt_id: attempt_ids).delete unless attempt_ids.empty?
  DB[:violations].where(attempt_id: attempt_ids).delete unless attempt_ids.empty?
  DB[:attempts].where(schedule_id: schedule_id).delete
  DB[:results].where(schedule_id: schedule_id).delete
  DB[:schedule_students].where(schedule_id: schedule_id).delete
  DB[:schedule_questions].where(schedule_id: schedule_id).delete
  DB[:schedules].where(id: schedule_id).delete
end

def delete_all_exams
  DB[:answers].delete
  DB[:violations].delete
  DB[:attempts].delete
  DB[:results].delete
  DB[:schedule_students].delete
  DB[:schedule_questions].delete
  DB[:schedules].delete
end

def check_attempt_status(attempt_id)
  attempt = DB[:attempts].where(id: attempt_id).first
  attempt ? attempt[:status] : "not_found"
end

def terminate_attempt(attempt_id, reason)
  attempt = DB[:attempts].where(id: attempt_id).first
  return false unless attempt

  DB[:attempts].where(id: attempt_id).update(
    status: "terminated_for_malpractice",
    termination_reason: reason,
    terminated_at: Time.now,
    end_time: Time.now,
    score: 0,
    updated_at: Time.now
  )

  DB[:violations].insert(
    attempt_id: attempt_id,
    violation_type: "exam_terminated",
    details_json: { reason: reason }.to_json,
    created_at: Time.now
  )

  true
end

def get_attempt_answers(attempt_id)
  DB[:answers]
    .where(attempt_id: attempt_id)
    .order(:question_index)
    .all
    .map do |a|
      {
        "question_index" => a[:question_index],
        "question_id" => a[:question_id],
        "answer" => a[:answer]
      }
    end
end

def force_submit_attempt(attempt_id)
  attempt = get_attempt(attempt_id)
  return nil unless attempt

  return nil if ["terminated_for_malpractice", "removed_for_malpractice"].include?(attempt["status"])

  schedule = get_schedule(attempt["schedule_id"])
  return nil unless schedule

  questions = schedule["questions"] || []
  answers = attempt["answers"] || []

  score = 0
  answers.each_with_index do |ans, i|
    if ans && ans["answer"] && i < questions.length
      score += 1 if ans["answer"] == questions[i]["correct"]
    end
  end

  DB[:attempts].where(id: attempt_id).update(
    status: "completed",
    score: score,
    end_time: Time.now,
    completed_by_teacher: true,
    teacher_notes: "Exam stopped by teacher",
    updated_at: Time.now
  )

  save_result(attempt["student_id"], attempt["schedule_id"], score, questions.length)

  {
    "score" => score,
    "total" => questions.length,
    "schedule_id" => attempt["schedule_id"]
  }
end

  def get_student_analytics(student_id)
    attempts = get_student_attempts(student_id)
    schedules = get_all_schedules
    topic_performance = {}

    attempts.each do |attempt|
      schedule = schedules.find { |s| s["id"].to_s == attempt["schedule_id"].to_s }
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

  

  def generate_feedback(_attempt_id, answers, questions)
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

    {
      "score" => score,
      "total" => questions.length,
      "percentage" => percentage,
      "message" => percentage >= 80 ? "🌟 Excellent work!" : percentage >= 60 ? "📚 Good job! Keep practicing." : "💪 Keep learning! You'll do better next time.",
      "weak_areas" => weak_areas.uniq.first(3),
      "suggestions" => generate_suggestions(weak_areas)
    }
  end

  def generate_suggestions(weak_areas)
    suggestions = []
    weak_areas.uniq.first(3).each do |area|
      suggestions << "Focus on #{area} topics"
    end
    suggestions << "Review your answers and try again" if suggestions.empty?
    suggestions
  end

  # =========================
  # RESULTS MANAGEMENT
  # =========================
  def save_result(student_id, schedule_id, score, total)
  percentage = total.to_i > 0 ? (score.to_f / total * 100).round(2) : 0

  existing = DB[:results].where(student_id: student_id, schedule_id: schedule_id).first

  if existing
    DB[:results].where(id: existing[:id]).update(
      score: score,
      total: total,
      percentage: percentage,
      updated_at: Time.now
    )
  else
    now = Time.now
    DB[:results].insert(
      student_id: student_id,
      schedule_id: schedule_id,
      score: score,
      total: total,
      percentage: percentage,
      created_at: now,
      updated_at: now
    )
  end

  true
end

def get_all_results
  stringify_array(DB[:results].all)
end

def get_student_results(student_id)
  stringify_array(DB[:results].where(student_id: student_id).all)
end

end