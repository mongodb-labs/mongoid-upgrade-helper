# frozen_string_literal: true

require 'mongoid'

Mongoid.connect_to 'mongoid-upgrade-helper-test'
Mongoid.purge!

require_relative './populator'

Populator.new.populate

puts "done"
puts "Companies: #{Company.count}"
puts "Departments: #{Department.count}"
puts "Teams: #{Team.count}"
puts "Positions: #{Position.count}"
puts "People: #{Person.count}"
puts '-------'
Person.each do |person|
  puts "#{person.name.full} (#{person.pronouns}) -- #{person.team.name} team"
  person.positions.each do |position|
    puts "  - #{position.title}"
  end
end
