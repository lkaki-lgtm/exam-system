require './database_connection'

class UserModel

  def self.register_student(name, email, reg_number, password)

    DB[:users].insert(
      name: name,
      email: email,
      reg_number: reg_number,
      password: password,
      role: "student",
      status: "active",
      created_at: Time.now
    )

  end

  def self.register_teacher(name, email, password)

    DB[:users].insert(
      name: name,
      email: email,
      password: password,
      role: "teacher",
      created_at: Time.now
    )

  end

  def self.authenticate(email, password)

    user = DB[:users]
      .where(email: email)
      .first

    return nil unless user

    return user if user[:password] == password

    nil

  end

  def self.get_students
    DB[:users]
      .where(role: "student")
      .all
  end

  def self.get_teachers
    DB[:users]
      .where(role: "teacher")
      .all
  end

end