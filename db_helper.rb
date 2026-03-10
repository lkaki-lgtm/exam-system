require './database_connection'

module DBHelper

  def self.insert_user(name, email, password, role, reg_number=nil)

    existing = DB[:users].where(email: email).first
    return nil if existing

    DB[:users].insert(
      name: name,
      email: email,
      password: password,
      role: role,
      reg_number: reg_number,
      status: "active",
      created_at: Time.now
    )

  end

  def self.find_user(email)
    DB[:users].where(email: email).first
  end

  def self.get_students
    DB[:users].where(role: "student").all
  end

  def self.get_teachers
    DB[:users].where(role: "teacher").all
  end

  def self.insert_question(text, o1, o2, o3, o4, correct, difficulty, topic)

    DB[:questions].insert(
      text: text,
      option1: o1,
      option2: o2,
      option3: o3,
      option4: o4,
      correct_answer: correct,
      difficulty: difficulty,
      topic: topic,
      created_at: Time.now
    )

  end

  def self.get_questions
    DB[:questions].all
  end

end