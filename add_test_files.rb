#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'iBurn.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the iBurnTests target
tests_target = project.targets.find { |t| t.name == 'iBurnTests' }
if tests_target.nil?
  puts "iBurnTests target not found!"
  exit 1
end

# Find the TestData group
test_data_group = project.main_group.find_subpath('iBurnTests/TestData')
if test_data_group.nil?
  puts "TestData group not found!"
  exit 1
end

# Find subgroups
initial_data_group = test_data_group.find_subpath('initial_data')
updated_data_group = test_data_group.find_subpath('updated_data')

# JSON files to add
json_files = [
  'iBurnTests/TestData/initial_data/art.json',
  'iBurnTests/TestData/initial_data/camp.json', 
  'iBurnTests/TestData/initial_data/event.json',
  'iBurnTests/TestData/initial_data/points.json',
  'iBurnTests/TestData/initial_data/update.json',
  'iBurnTests/TestData/updated_data/art.json',
  'iBurnTests/TestData/updated_data/camp.json',
  'iBurnTests/TestData/updated_data/event.json', 
  'iBurnTests/TestData/updated_data/points.json',
  'iBurnTests/TestData/updated_data/update.json'
]

json_files.each do |file_path|
  if File.exist?(file_path)
    # Determine which group to add to
    if file_path.include?('initial_data')
      group = initial_data_group
    else
      group = updated_data_group  
    end
    
    # Add file reference
    file_ref = group.new_reference(File.basename(file_path))
    file_ref.path = File.basename(file_path)
    
    # Add to build phase (Bundle Resources)
    tests_target.add_file_references([file_ref])
    
    puts "Added #{file_path} to iBurnTests target"
  else
    puts "File not found: #{file_path}"
  end
end

# Save the project
project.save
puts "Project saved successfully!"