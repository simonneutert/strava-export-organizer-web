#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/clamav_service'

puts '🦠 ClamAV Setup and Test Script'
puts '================================'

# Check if ClamAV is enabled
if ClamAVService.enabled?
  puts '✅ ClamAV is enabled'

  # Test ClamAV connection
  if ClamAVService.ping
    puts '✅ ClamAV daemon is running and responsive'

    # Test with EICAR test file
    puts "\n🧪 Testing with EICAR test virus..."
    # Standard EICAR test virus signature (68 ASCII characters / 70 bytes)
    eicar_content = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

    # Create temporary test file
    require 'tempfile'
    temp_file = Tempfile.new(['eicar_test', '.txt'])
    temp_file.write(eicar_content)
    temp_file.close

    result = ClamAVService.scan_file(temp_file.path)
    temp_file.unlink

    if result[:clean] == false && result[:virus_name]
      puts "✅ Virus detection working! Detected: #{result[:virus_name]}"
    else
      puts '⚠️  Warning: EICAR test file was not detected as a virus'
      puts '   This might indicate ClamAV definitions are not up to date'
    end

    puts "\n🎉 ClamAV setup appears to be working correctly!"

  else
    puts '❌ ClamAV daemon is not responding'
    puts "   Check that ClamAV is running on #{ENV.fetch('CLAMAV_HOST',
                                                         'localhost')}:#{ENV.fetch('CLAMAV_PORT', '3310')}"
    puts "\n📝 To start ClamAV with Docker:"
    puts '   docker run -d --name clamav -p 3310:3310 clamav/clamav:stable'
    puts '   (Wait a few minutes for virus definitions to download)'
  end
else
  puts 'ℹ️  ClamAV is disabled (CLAMAV_ENABLED != true)'
  puts '   Set CLAMAV_ENABLED=true in your environment to enable virus scanning'
end

puts "\n🐳 For production with Docker Compose:"
puts '   docker-compose up -d'
puts '   This will start both the app and ClamAV daemon'
