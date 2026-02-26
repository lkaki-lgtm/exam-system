require 'sinatra'
require_relative 'database'

enable :sessions

# Initialize database connection
db = ExamDatabase.new

# ===== PUBLIC ROUTES (No Login Required) =====

# Home page
get '/' do
  erb :index
end

# Registration page
get '/register' do
  erb :register
end

post '/register' do
  # Simple password (in production, use bcrypt)
  password = params[:password]
  
  if params[:role] == "admin"
    # Register as admin
    result = db.register_admin(params[:name], params[:email], password)
    
    if result.nil?
      @error = "Email already exists or registration failed"
      return erb :register
    end
    
    @message = "Registration Successful! Please login."
    erb :login_new  # Show login page with success message
  else
    # Register as student - registration number is required
    if params[:reg_number].nil? || params[:reg_number].empty?
      @error = "Registration number is required for students"
      return erb :register
    end
    
    # Call register_student with ALL parameters
    puts "Attempting to register student: #{params[:name]}, #{params[:email]}, #{params[:reg_number]}"
    
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
    
    puts "✅ Student registered successfully: #{result.inspect}"
    @message = "Registration Successful! Please login."
    erb :login_new  # Show login page with success message
  end
end

# Login page
get '/login' do
  @role = params[:role] || "student"
  erb :login_new
end

post '/login' do
  password_hash = params[:password]
  user = db.authenticate_user(params[:email], password_hash)
  
  if user
    session[:user_id] = user["user"]["id"]
    session[:user_name] = user["user"]["name"]
    session[:user_type] = user["type"]
    
    # Redirect based on role
    if user["type"] == "admin"
      redirect '/admin/dashboard'
    else
      redirect '/student/dashboard'
    end
  else
    @error = "Invalid email or password"
    erb :login_new
  end
end

# Logout
get '/logout' do
  session.clear
  redirect '/'
end

# ===== ADMIN ROUTES (Restricted) =====

# Admin dashboard
get '/admin/dashboard' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  @students = db.get_all_students
  @schedules = db.get_all_schedules
  @attempts = db.get_all_attempts
  @questions = db.get_all_questions
  
  erb :admin_dashboard
end

# Admin: Manage questions
get '/admin/questions' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  @questions = db.get_all_questions
  erb :admin_questions
end

# Admin: Add question
post '/admin/questions/add' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  db.add_question(
    params[:text],
    params[:opt1],
    params[:opt2],
    params[:opt3],
    params[:opt4],
    params[:correct]
  )
  
  redirect '/admin/questions'
end

# Admin: Delete question
post '/admin/questions/delete/:id' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  # Add delete functionality if needed
  redirect '/admin/questions'
end

# Admin: Create exam schedule
get '/admin/create-exam' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  @questions = db.get_all_questions
  erb :create_exam
end

post '/admin/create-exam' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  # Get selected question IDs from form
  question_ids = params[:question_ids] || []
  all_questions = db.get_all_questions
  selected_questions = all_questions.select { |q| question_ids.include?(q["id"]) }
  
  db.create_exam_schedule(
    params[:title],
    params[:description],
    params[:duration].to_i,
    params[:date],
    params[:start_time],
    params[:end_time],
    selected_questions
  )
  
  redirect '/admin/dashboard'
end

# Admin: View all students
get '/admin/students' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  @students = db.get_all_students
  erb :admin_students
end

# Admin: Add student manually
post '/admin/students/add' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  password_hash = params[:password]
  db.register_student(
    params[:name], 
    params[:email], 
    params[:reg_number], 
    password_hash
  )
  
  redirect '/admin/students'
end

# Admin: View all results
get '/admin/results' do
  # Check if user is admin
  if session[:user_type] != "admin"
    redirect '/login?role=admin'
  end
  
  @attempts = db.get_all_attempts
  @schedules = db.get_all_schedules
  @students = db.get_all_students
  
  # Calculate percentage for each attempt
  @attempts.each do |attempt|
    schedule = @schedules.find { |s| s["id"] == attempt["schedule_id"] }
    if schedule && attempt["score"]
      total_questions = schedule["questions"].length
      attempt["calculated_percentage"] = total_questions > 0 ? 
        ((attempt["score"].to_f / total_questions) * 100).round(2) : 0
    else
      attempt["calculated_percentage"] = 0
    end
  end
  
  erb :admin_results
end

# ===== STUDENT ROUTES (Restricted) =====

# Student dashboard
get '/student/dashboard' do
  # Check if user is student
  if session[:user_type] != "student"
    redirect '/login?role=student'
  end
  
  @active_exams = db.get_active_schedules
  @upcoming_exams = db.get_upcoming_schedules
  @my_attempts = db.get_student_attempts(session[:user_id])
  @schedules = db.get_all_schedules
  
  erb :student_dashboard
end

# Student: Take exam
get '/student/exam/:schedule_id' do
  # Check if user is student
  if session[:user_type] != "student"
    redirect '/login?role=student'
  end
  
  @schedule_id = params[:schedule_id]
  schedules = db.get_all_schedules
  @exam = schedules.find { |s| s["id"] == @schedule_id }
  
  # Check if exam exists
  if @exam.nil?
    @message = "Exam not found"
    return erb :message
  end
  
  # Check if exam is currently active
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
  
  # Check if student already attempted this exam
  existing_attempt = db.get_student_attempts(session[:user_id]).find { |a| a["schedule_id"] == @schedule_id }
  if existing_attempt && existing_attempt["status"] == "completed"
    @message = "You have already taken this exam. You cannot take it again."
    return erb :message
  end
  
  # Create exam attempt
  @attempt = db.create_exam_attempt(session[:user_id], @schedule_id)
  @questions = @exam["questions"]
  
  erb :scheduled_exam
end

# Student: Submit exam
post '/student/exam/submit' do
  # Check if user is student
  if session[:user_type] != "student"
    redirect '/login?role=student'
  end
  
  attempt_id = params[:attempt_id]
  questions_json = params[:questions]
  
  begin
    questions = JSON.parse(questions_json)
  rescue
    questions = []
  end
  
  # Calculate score
  score = 0
  answers = []
  
  questions.each_with_index do |q, i|
    answer = params["q#{i}"]
    answers << {"question_id" => q["id"], "answer" => answer}
    score += 1 if answer == q["correct"]
  end
  
  db.submit_exam_attempt(attempt_id, answers, score)
  
  redirect '/student/dashboard'
end

# Student: View results
get '/student/results' do
  # Check if user is student
  if session[:user_type] != "student"
    redirect '/login?role=student'
  end
  
  @attempts = db.get_student_attempts(session[:user_id])
  @schedules = db.get_all_schedules
  
  erb :student_results
end

# ===== TEMPORARY REDIRECTS FOR OLD ROUTES =====
# These redirect old URLs to new ones

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
  if session[:user_type] == "admin"
    redirect '/admin/dashboard'
  else
    redirect '/student/dashboard'
  end
end

get '/exams' do
  redirect '/student/dashboard'
end

# ===== EDIT QUESTIONS ROUTES =====

# Edit questions page
get '/admin/edit-questions' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  @questions = db.get_all_questions
  erb :admin_edit_questions
end

# Update question
post '/admin/questions/update/:id' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  
  questions = JSON.parse(File.read("questions.json"))
  question = questions.find { |q| q["id"] == params[:id] }
  
  if question
    question["text"] = params[:text]
    question["options"] = [params[:opt1], params[:opt2], params[:opt3], params[:opt4]]
    question["correct"] = params[:correct]
    question["updated_at"] = Time.now.to_s
    
    File.write("questions.json", JSON.dump(questions))
    puts "✅ Question updated: #{params[:id]}"
  end
  
  redirect '/admin/edit-questions'
end

# ===== EDIT EXAMS ROUTES =====

# Edit exams page
get '/admin/edit-exams' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  @schedules = db.get_all_schedules
  @all_questions = db.get_all_questions
  erb :admin_edit_exams
end

# Update exam
post '/admin/exams/update/:id' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  
  schedules = JSON.parse(File.read("schedules.json"))
  schedule = schedules.find { |s| s["id"] == params[:id] }
  
  if schedule
    # Get selected questions
    question_ids = params[:question_ids] || []
    all_questions = db.get_all_questions
    selected_questions = all_questions.select { |q| question_ids.include?(q["id"]) }
    
    # Update schedule
    schedule["title"] = params[:title]
    schedule["description"] = params[:description]
    schedule["duration_minutes"] = params[:duration].to_i
    schedule["scheduled_date"] = params[:date]
    schedule["start_time"] = params[:start_time]
    schedule["end_time"] = params[:end_time]
    schedule["status"] = params[:status]
    schedule["questions"] = selected_questions
    schedule["updated_at"] = Time.now.to_s
    
    File.write("schedules.json", JSON.dump(schedules))
    puts "✅ Exam updated: #{params[:id]}"
  end
  
  redirect '/admin/edit-exams'
end

# ===== DELETE ROUTES =====

# Delete questions page
get '/admin/delete-questions' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  @questions = db.get_all_questions
  erb :admin_delete_questions
end

# Delete single question
post '/admin/questions/delete/:id' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  
  questions = JSON.parse(File.read("questions.json"))
  questions.delete_if { |q| q["id"] == params[:id] }
  File.write("questions.json", JSON.dump(questions))
  
  redirect '/admin/delete-questions'
end

# Delete ALL questions
post '/admin/questions/delete-all' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  
  File.write("questions.json", JSON.dump([]))
  redirect '/admin/delete-questions'
end

# Delete exams page
get '/admin/delete-exams' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  @schedules = db.get_all_schedules
  erb :admin_delete_exams
end

# Delete single exam
post '/admin/exams/delete/:id' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  
  schedules = JSON.parse(File.read("schedules.json"))
  schedules.delete_if { |s| s["id"] == params[:id] }
  File.write("schedules.json", JSON.dump(schedules))
  
  redirect '/admin/delete-exams'
end

# Delete ALL exams
post '/admin/exams/delete-all' do
  redirect '/login?role=admin' unless session[:user_type] == "admin"
  
  File.write("schedules.json", JSON.dump([]))
  redirect '/admin/delete-exams'
end
