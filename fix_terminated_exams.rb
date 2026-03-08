# fix_terminated_exams.rb
require 'json'

puts "🔧 Fixing terminated exams..."

# Load attempts
attempts = JSON.parse(File.read("attempts.json"))

# Find all in_progress attempts
in_progress = attempts.select { |a| a["status"] == "in_progress" }
puts "Found #{in_progress.count} in_progress attempts"

fixed_count = 0

# Check each one
in_progress.each do |attempt|
  # Check if it has violations
  if attempt["violations"] && attempt["violations"].count >= 5
    puts "❌ Terminating attempt #{attempt["id"]} with #{attempt["violations"].count} violations"
    attempt["status"] = "terminated_for_malpractice"
    attempt["termination_reason"] = "Multiple violations (auto-fix)"
    attempt["terminated_at"] = Time.now.to_s
    attempt["end_time"] = Time.now.to_s
    fixed_count += 1
  end
end

# Save back
File.write("attempts.json", JSON.dump(attempts))
puts "✅ Fixed #{fixed_count} terminated exams!"