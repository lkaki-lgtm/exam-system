require 'sinatra'
require 'dotenv/load'
require_relative 'database'
require_relative 'database_connection'
require_relative 'db_helper'
require 'json'
require 'date'
require 'time'
require 'securerandom'
require 'rufus-scheduler'

configure do
  enable :sessions
  set :session_secret, ENV.fetch("SESSION_SECRET") { "change-this-in-development-only" }
  set :sessions,
      key: 'exam_system.session',
      httponly: true,
      same_site: :lax
end

set :bind, '0.0.0.0'
set :port, ENV['PORT'] || 4567

set :protection, except: :host_authorization

configure :development do
  set :protection, except: [:host_authorization]
  set :hosts, [
    "localhost",
    "127.0.0.1",
    /.*\.ngrok\.io/,
    /.*\.ngrok-free\.app/,
    /.*\.ngrok\.app/
  ]
end

helpers do
  def protected!
    redirect '/login' unless session[:user_id]
  end

  def admin_only!
    redirect '/login?role=admin' unless session[:user_type] == "admin"
  end

  def teacher_only!
    redirect '/login?role=teacher' unless session[:user_type] == "teacher"
  end

  def student_only!
    redirect '/login?role=student' unless session[:user_type] == "student"
  end
end

db = ExamDatabase.new
scheduler = Rufus::Scheduler.new

scheduler.every '1m' do
  begin
    puts "⏰ Scheduled task: Checking exam statuses..."
    db.update_exam_statuses
  rescue => e
    puts "❌ Error in scheduled task: #{e.message}"
  end
end

before do
  begin
    # Force update exam statuses on every request
    db.update_exam_statuses if db.respond_to?(:update_exam_statuses)
  rescue => e
    puts "❌ Error in before filter: #{e.message}"
    puts e.backtrace
  end
end

# ===== PUBLIC ROUTES =====
get '/' do
  erb :index
end

get '/register' do
  erb :register
end

post '/register' do
  password = params[:password]

  case params[:role]
  when "admin"
    result = db.register_admin(params[:name], params[:email], password)
    if result.nil?
      @error = "Email already exists or registration failed"
      return erb :register
    end
    @message = "Admin Registration Successful! Please login."

  when "teacher"
    @error = "Teacher accounts must be created by an administrator"
    return erb :register

  else
    if params[:reg_number].to_s.strip.empty?
      @error = "Registration number is required for students"
      return erb :register
    end

    result = db.register_student(
      params[:name],
      params[:email],
      params[:reg_number],
      password
    )

    if result.nil?
      @error = "Email or Registration number already exists"
      return erb :register
    end

    @message = "Student Registration Successful! Please login."
  end

  erb :login_new
end

get '/login' do
  @role = params[:role] || "student"
  erb :login_new
end

post '/login' do
  user = db.authenticate_user(params[:email], params[:password])

  if user
    session[:user_id] = user["user"]["id"]
    session[:user_name] = user["user"]["name"]
    session[:user_type] = user["type"]

    case user["type"]
    when "admin"
      redirect '/admin/dashboard'
    when "teacher"
      redirect '/teacher/dashboard'
    else
      redirect '/student/dashboard'
    end
  else
    @error = "Invalid email or password"
    erb :login_new
  end
end

get '/logout' do
  session.clear
  redirect '/'
end

get '/test' do
  begin
    admin_count = db.respond_to?(:get_all_admins) ? db.get_all_admins.count : 0

    @stats = {
      users: db.get_all_students.count + db.get_all_teachers.count + admin_count,
      questions: db.get_all_questions.count,
      exams: db.get_all_schedules.count,
      attempts: db.get_all_attempts.count
    }
  rescue => e
    puts "Error loading stats: #{e.message}"
    @stats = { users: "?", questions: "?", exams: "?", attempts: "?" }
  end

  erb :test
end

# ===== ADMIN ROUTES =====
get '/admin/create-admin' do
  admin_only!
  erb :create_admin
end

post '/admin/create-admin' do
  admin_only!
  result = db.register_admin(params[:name], params[:email], params[:password])

  if result.nil?
    @error = "Email already exists"
    erb :create_admin
  else
    redirect '/admin/dashboard'
  end
end

get '/admin/create-teacher' do
  admin_only!
  erb :create_teacher
end

post '/admin/create-teacher' do
  admin_only!
  result = db.register_teacher(params[:name], params[:email], params[:password])

  if result.nil?
    @error = "Email already exists"
    erb :create_teacher
  else
    redirect '/admin/dashboard'
  end
end

get '/admin/dashboard' do
  admin_only!
  @students = db.get_all_students || []
  @teachers = db.get_all_teachers || []
  @schedules = db.get_all_schedules || []
  @attempts = db.get_all_attempts || []
  @questions = db.get_all_questions || []
  erb :admin_dashboard
end

get '/admin/analytics' do
  admin_only!
  @analytics = db.get_system_analytics
  erb :admin_analytics
end

get '/admin/analytics/enhanced' do
  admin_only!
  @questions = db.get_all_questions
  @question_stats = db.get_question_analytics
  @topic_performance = db.get_topic_performance
  days = params[:days] ? params[:days].to_i : 30
  @trends = db.get_student_performance_trends(days)
  erb :admin_analytics_enhanced
end

get '/admin/questions' do
  admin_only!
  @questions = db.get_all_questions
  erb :admin_questions
end

post '/admin/questions/add' do
  admin_only!
  db.add_question(
    params[:text],
    params[:opt1],
    params[:opt2],
    params[:opt3],
    params[:opt4],
    params[:correct],
    params[:difficulty],
    params[:topic]
  )
  redirect '/admin/questions'
end

get '/admin/create-exam' do
  admin_only!
  @questions = db.get_all_questions
  @teachers = db.get_all_teachers || []
  erb :create_exam
end

post '/admin/create-exam' do
  admin_only!

  begin
    question_ids = (params[:question_ids] || []).map(&:to_i)

    all_questions = db.get_all_questions
    selected_questions = all_questions.select { |q| question_ids.include?(q["id"].to_i) }

    duration = params[:duration].to_i
    assigned_teacher_id = params[:assigned_teacher_id]
    assigned_teacher_id = nil if assigned_teacher_id.nil? || assigned_teacher_id.strip.empty?

    if params[:date].nil? || params[:date].strip == ""
      halt 400, "Date is required"
    end

    db.create_exam_schedule(
      params[:title],
      params[:description],
      duration,
      params[:date],
      params[:start_time],
      params[:end_time],
      selected_questions,
      assigned_teacher_id
    )

    redirect '/admin/dashboard'

  rescue => e
    puts "❌ ERROR creating exam: #{e.message}"
    puts e.backtrace
    halt 500, "Exam creation failed"
  end
end

get '/admin/students' do
  admin_only!
  @students = db.get_all_students
  @attempts = db.get_all_attempts
  erb :admin_students
end

get '/admin/teachers' do
  admin_only!
  @teachers = db.get_all_teachers
  @schedules = db.get_all_schedules
  @teacher_students = {}

  @teachers.each do |teacher|
    teacher_exams = @schedules.select { |s| s["assigned_teacher_id"].to_i == teacher["id"].to_i }
    student_ids = teacher_exams.flat_map { |e| e["assigned_students"] || [] }.uniq
    @teacher_students[teacher["id"]] = student_ids.map { |id| db.get_student(id) }.compact
  end

  erb :admin_teachers
end

get '/admin/force-update-exams' do
  admin_only!
  result = db.update_exam_statuses
  "Exam statuses updated: #{result ? 'Changes made' : 'No changes needed'}"
end

get '/admin/setup-database' do
  admin_only!
  db.setup_database_schema
  "Database schema updated successfully! Check the console for details."
end

get '/admin/results' do
  admin_only!
  @attempts = db.get_all_attempts
  @schedules = db.get_all_schedules
  @students = db.get_all_students
  @teachers = db.get_all_teachers

  @attempts.each do |attempt|
    schedule = @schedules.find { |s| s["id"].to_i == attempt["schedule_id"].to_i }
    if schedule && attempt["score"]
      total_questions = (schedule["questions"] || []).length
      attempt["calculated_percentage"] = total_questions > 0 ? ((attempt["score"].to_f / total_questions) * 100).round(2) : 0
    else
      attempt["calculated_percentage"] = 0
    end
  end

  erb :admin_results
end

get '/admin/edit-questions' do
  admin_only!
  @questions = db.get_all_questions
  erb :admin_edit_questions
end

post '/admin/questions/update/:id' do
  admin_only!

  db.update_question(
    params[:id].to_i,
    params[:text],
    params[:opt1],
    params[:opt2],
    params[:opt3],
    params[:opt4],
    params[:correct],
    params[:difficulty],
    params[:topic]
  )

  redirect '/admin/edit-questions'
end

get '/admin/edit-exams' do
  admin_only!
  @schedules = db.get_all_schedules
  @all_questions = db.get_all_questions
  @all_teachers = db.get_all_teachers
  erb :admin_edit_exams
end

post '/admin/exams/update/:id' do
  admin_only!

  question_ids = (params[:question_ids] || []).map(&:to_i)
  assigned_teacher_id = params[:assigned_teacher_id].to_s.strip.empty? ? nil : params[:assigned_teacher_id].to_i

  db.update_exam(
    params[:id].to_i,
    title: params[:title],
    description: params[:description],
    duration_minutes: params[:duration].to_i,
    scheduled_date: Date.parse(params[:date]),
    start_time: params[:start_time],
    end_time: params[:end_time],
    status: params[:status],
    assigned_teacher_id: assigned_teacher_id,
    question_ids: question_ids
  )

  redirect '/admin/edit-exams'
end

post '/admin/questions/delete/:id' do
  admin_only!
  db.delete_question(params[:id].to_i)
  redirect '/admin/delete-questions'
end

post '/admin/questions/delete-all' do
  admin_only!
  db.delete_all_questions
  redirect '/admin/delete-questions'
end

get '/admin/delete-exams' do
  admin_only!
  @schedules = db.get_all_schedules
  erb :admin_delete_exams
end

post '/admin/exams/delete/:id' do
  admin_only!
  db.delete_exam(params[:id].to_i)
  redirect '/admin/delete-exams'
end

post '/admin/exams/delete-all' do
  admin_only!
  db.delete_all_exams
  redirect '/admin/delete-exams'
end

# ===== TEACHER ROUTES =====
get '/teacher/dashboard' do
  teacher_only!
  @my_exams = db.get_teacher_exams(session[:user_id])
  @my_students = db.get_teacher_students(session[:user_id])
  @active_exams = db.get_active_teacher_exams(session[:user_id])
  @attempts = db.get_teacher_exam_attempts(session[:user_id])
  erb :teacher_dashboard
end

get '/teacher/exam/:exam_id/assign-students' do
  teacher_only!
  @exam = db.get_schedule(params[:exam_id].to_i)
  @available_students = db.get_all_students
  @assigned_students = db.get_exam_students(params[:exam_id].to_i)
  erb :teacher_assign_students
end

post '/teacher/exam/:exam_id/assign-students' do
  teacher_only!
  student_ids = (params[:student_ids] || []).map(&:to_i)
  db.assign_students_to_exam(params[:exam_id].to_i, student_ids)
  redirect "/teacher/exam/#{params[:exam_id]}/control"
end

get '/teacher/exam/:exam_id/proctoring-report' do
  teacher_only!
  @exam = db.get_schedule(params[:exam_id].to_i)

  if @exam["assigned_teacher_id"].to_i != session[:user_id].to_i
    @message = "You don't have permission to view this exam's proctoring report."
    return erb :message
  end

  @report = db.get_proctoring_report(params[:exam_id].to_i)
  erb :teacher_proctoring_report
end

get '/teacher/exam/:exam_id/control' do
  teacher_only!
  @exam = db.get_schedule(params[:exam_id].to_i)
  @active_attempts = db.get_active_exam_attempts(params[:exam_id].to_i)
  @students = db.get_all_students
  erb :teacher_exam_control
end

post '/teacher/exam/remove-student' do
  teacher_only!
  attempt_id = params[:attempt_id].to_i
  reason = params[:reason]

  db.remove_student_for_malpractice(attempt_id, reason, session[:user_name])
  redirect "/teacher/exam/#{params[:exam_id]}/control"
end

post '/teacher/exam/force-submit' do
  teacher_only!
  attempt_id = params[:attempt_id].to_i

  result = db.force_submit_attempt(attempt_id)

  if result.nil?
    session[:error] = "Attempt not found"
    redirect back
  end

  session[:success] = "Student exam stopped and graded. Score: #{result["score"]}/#{result["total"]}"
  redirect "/teacher/exam/#{result["schedule_id"]}/control"
end

get '/teacher/exam/monitor/:attempt_id' do
  teacher_only!
  @attempt = db.get_attempt(params[:attempt_id].to_i)
  @student = db.get_student(@attempt["student_id"])
  @exam = db.get_schedule(@attempt["schedule_id"])
  erb :teacher_live_monitor
end

get '/teacher/results' do
  teacher_only!
  @my_exams = db.get_teacher_exams(session[:user_id])
  @attempts = db.get_teacher_exam_attempts(session[:user_id])
  @schedules = db.get_all_schedules
  @students = db.get_all_students
  erb :teacher_results
end

get '/teacher/students' do
  teacher_only!
  @students = db.get_all_students
  @attempts = db.get_all_attempts
  erb :admin_students
end

# ===== STUDENT ROUTES =====
get '/student/dashboard' do
  student_only!
  db.update_exam_statuses if db.respond_to?(:update_exam_statuses)
  @assigned_exams = db.get_student_assigned_exams(session[:user_id])
  @active_exams = db.get_active_student_exams(session[:user_id])
  @upcoming_exams = db.get_upcoming_student_exams(session[:user_id])
  @my_attempts = db.get_student_attempts(session[:user_id])
  @schedules = db.get_all_schedules
  @analytics = db.get_student_analytics(session[:user_id])
  erb :student_dashboard
end

get '/student/exam/check-status' do
  student_only!
  content_type :json

  attempt_id = params[:attempt_id]
  status = db.check_attempt_status(attempt_id.to_i)
  { status: status }.to_json
end

get '/student/exam/:schedule_id' do
  student_only!

  schedule_id = params[:schedule_id].to_i
  student_id = session[:user_id].to_i

  if db.student_has_final_attempt?(student_id, schedule_id)
    @message = "Your exam attempt is already finished."
    return erb :message
  end

  @schedule_id = schedule_id
  @exam = db.get_schedule(@schedule_id)

  unless db.student_assigned_to_exam?(student_id, @schedule_id)
    @message = "You are not assigned to this exam"
    return erb :message
  end

  if @exam.nil?
    @message = "Exam not found"
    return erb :message
  end

  now = Time.now
  begin
    start_time = Time.parse("#{@exam["scheduled_date"]} #{@exam["start_time"]}")
    end_time = Time.parse("#{@exam["scheduled_date"]} #{@exam["end_time"]}")

    if now < start_time
      @message = "This exam hasn't started yet. It starts at #{@exam["start_time"]} on #{@exam["scheduled_date"]}"
      return erb :message
    elsif now > end_time
      @message = "This exam has already ended. It ended at #{@exam["end_time"]}"
      return erb :message
    end
  rescue => e
    @message = "Error checking exam time: #{e.message}"
    return erb :message
  end

  validation = db.validate_attempt_access(student_id, @schedule_id)
  unless validation[:allowed]
    @message = validation[:message]
    return erb :message
  end

  if validation[:attempt]
    @attempt = validation[:attempt]
  else
    @attempt = db.create_exam_attempt(student_id, @schedule_id)
    if @attempt.nil?
      @message = "Unable to start exam. Please contact your teacher."
      return erb :message
    end
  end

  attempt_start = Time.parse(@attempt["start_time"].to_s) rescue Time.now
  duration_seconds = @exam["duration_minutes"].to_i * 60
  elapsed_seconds = (Time.now - attempt_start).to_i
  @remaining_seconds = [duration_seconds - elapsed_seconds, 0].max

  @answered = []
  if @attempt["answers"]
    @attempt["answers"].each do |ans|
      if ans && ans["answer"] && !ans["question_index"].nil?
        @answered << ans["question_index"]
      end
    end
  end

  @questions = @exam["questions"]
  @marked = @attempt["marked_questions"] || []

  erb :scheduled_exam
end

post '/student/exam/save-answer' do
  student_only!
  content_type :json

  request.body.rewind
  data = JSON.parse(request.body.read) rescue params

  attempt_id = (data["attempt_id"] || data[:attempt_id]).to_i
  question_index = (data["question_index"] || data[:question_index]).to_i
  answer = data["answer"] || data[:answer]

  db.save_student_answer(attempt_id, question_index, answer)
  { success: true }.to_json
end

post '/student/exam/submit' do
  student_only!

  attempt_id = params[:attempt_id].to_i
  questions_json = params[:questions]
  proctoring_data = params[:proctoring] ? JSON.parse(params[:proctoring]) : {}

  begin
    questions = JSON.parse(questions_json)
  rescue
    questions = []
  end

  score = 0
  answers = []

  questions.each_with_index do |q, i|
    answer = params["q#{i}"]
    answers << { "question_id" => q["id"], "answer" => answer }
    score += 1 if answer == q["correct"]
  end

  feedback = db.generate_feedback(attempt_id, answers, questions)

  db.submit_exam_attempt(
    attempt_id,
    answers,
    score,
    feedback,
    proctoring_data["violations"] || [],
    proctoring_data["warnings"] || []
  )

  redirect '/student/dashboard'
end

post '/student/exam/mark-question' do
  student_only!
  content_type :json

  request.body.rewind
  data = JSON.parse(request.body.read) rescue params

  attempt_id = (data["attempt_id"] || data[:attempt_id]).to_i
  question_index = (data["question_index"] || data[:question_index]).to_i
  marked_value = data["marked"] || data[:marked]
  marked = marked_value == true || marked_value == "true"

  db.mark_question_for_review(attempt_id, question_index, marked)
  { success: true }.to_json
end

post '/student/exam/report-violation' do
  student_only!
  content_type :json

  request.body.rewind
  data = JSON.parse(request.body.read) rescue params

  attempt_id = (data["attempt_id"] || data[:attempt_id]).to_i
  violation_type = data["type"] || data[:type]
  details = data["details"] || data[:details] || data["message"] || data[:message] || data

  db.log_proctoring_violation(attempt_id, violation_type, details)
  { success: true }.to_json
end

post '/student/exam/terminate' do
  student_only!
  content_type :json

  request.body.rewind
  data = JSON.parse(request.body.read) rescue params

  attempt_id = (data["attempt_id"] || data[:attempt_id]).to_i
  reason = data["reason"] || data[:reason] || "Auto-terminated by proctoring system"

  if db.terminate_attempt(attempt_id, reason)
    { success: true, message: "Exam terminated", redirect: "/student/dashboard" }.to_json
  else
    { success: false, message: "Attempt not found" }.to_json
  end
end

get '/student/results' do
  student_only!
  @attempts = db.get_student_attempts(session[:user_id])
  @schedules = db.get_all_schedules
  @analytics = db.get_student_performance_analytics(session[:user_id])
  erb :student_results
end

get '/student/exam/get-answers' do
  student_only!
  content_type :json

  attempt_id = params[:attempt_id].to_i
  { answers: db.get_attempt_answers(attempt_id) }.to_json
end

# ===== TEMPORARY REDIRECTS =====
get '/admin' do
  redirect '/admin/dashboard'
end

get '/admin/add' do
  redirect '/admin/questions'
end

post '/admin/add' do
  redirect '/admin/questions'
end

get '/exam' do
  redirect '/student/dashboard'
end

get '/dashboard' do
  case session[:user_type]
  when "admin"
    redirect '/admin/dashboard'
  when "teacher"
    redirect '/teacher/dashboard'
  else
    redirect '/student/dashboard'
  end
end

get '/exams' do
  redirect '/student/dashboard'
end