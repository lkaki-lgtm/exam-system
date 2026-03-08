# cleanup_attempts.rb
require 'json'

puts "🧹 Cleaning up duplicate exam attempts..."

# Load attempts
attempts = JSON.parse(File.read("attempts.json"))

# Group by student_id and schedule_id
grouped = {}
attempts.each do |attempt|
  key = "#{attempt['student_id']}_#{attempt['schedule_id']}"
  grouped[key] ||= []
  grouped[key] << attempt
end

# Keep only the most recent attempt for each student+exam
clean_attempts = []
grouped.each do |key, student_attempts|
  if student_attempts.size > 1
    puts "Found #{student_attempts.size} attempts for #{key}"
    
    # Sort by start_time (newest first)
    sorted = student_attempts.sort_by { |a| a['start_time'] }.reverse
    
    # Keep the newest one
    clean_attempts << sorted.first
    
    # Log what happened to the others
    sorted[1..-1].each do |old|
      puts "  - Removing old attempt #{old['id']} from #{old['start_time']}"
    end
  else
    clean_attempts << student_attempts.first
  end
end

# Save cleaned attempts
File.write("attempts.json", JSON.dump(clean_attempts))
puts "✅ Cleanup complete! Kept #{clean_attempts.count} attempts."