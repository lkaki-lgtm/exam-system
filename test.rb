# test.rb
require_relative 'database'
db = ExamDatabase.new
puts "Method exists!" if db.respond_to?(:student_assigned_to_exam?)