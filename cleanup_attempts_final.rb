# cleanup_attempts_final.rb
require 'json'

puts "🧹 FINAL CLEANUP - Removing duplicate attempts..."

# Load attempts
attempts = JSON.parse(File.read("attempts.json"))

# Group by student_id and schedule_id
grouped = {}
attempts.each do |attempt|
  key = "#{attempt['student_id']}_#{attempt['schedule_id']}"
  grouped[key] ||= []
  grouped[key] << attempt
end

# Keep ONLY ONE attempt per student per exam
clean_attempts = []
grouped.each do |key, student_attempts|
  if student_attempts.size > 1
    puts "\n⚠️ Found #{student_attempts.size} attempts for #{key}"
    
    # Sort by start_time (newest first)
    sorted = student_attempts.sort_by { |a| a['start_time'] }.reverse
    
    # Check if any are completed/terminated - those take priority
    final_status_attempt = sorted.find { |a| ["completed", "terminated_for_malpractice", "removed_for_malpractice"].include?(a["status"]) }
    
    if final_status_attempt
      # Keep the final status attempt
      clean_attempts << final_status_attempt
      puts "  ✅ Keeping #{final_status_attempt['status']} attempt from #{final_status_attempt['start_time']}"
      
      # Discard others
      (sorted - [final_status_attempt]).each do |old|
        puts "  🗑️ Discarding #{old['status']} attempt from #{old['start_time']}"
      end
    else
      # No final status, keep the most recent
      clean_attempts << sorted.first
      puts "  ✅ Keeping most recent in_progress attempt from #{sorted.first['start_time']}"
      
      # Discard others
      sorted[1..-1].each do |old|
        puts "  🗑️ Discarding older attempt from #{old['start_time']}"
      end
    end
  else
    clean_attempts << student_attempts.first
  end
end

# Save cleaned attempts
File.write("attempts.json", JSON.dump(clean_attempts))
puts "\n✅ Cleanup complete! Kept #{clean_attempts.count} unique attempts."