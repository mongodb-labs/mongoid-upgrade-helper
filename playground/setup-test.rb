# frozen_string_literal: true

require 'mongoid'

Mongoid.connect_to 'mongoid-upgrade-helper-test'
Mongoid.purge!

require_relative 'models'

GIVEN_NAMES = %w[ Salvatore Alan Elmer Charlie Stanley Clyde Keith Roberto Javier Mark
                  Edna Dolores Lois Cathy Lynda Barbara Wendy Adrienne Hope Rebekah
                  Perry Karl Gene Gary Carlos Ronnie Shannon Spencer Abraham Alexander
                  Celia Margie Janice Grace Monica Kelly Kari Megan Kylie Natasha
                  Edward Lyle Francis Phillip Matthew Roy Wayne Ian Brent Mario
                  Sophia Thelma Jessie Ruby Jamie April Jodi Heidi Jayla Serenity ]

SURNAMES = %w[ Ryan McLeod Peters Owens Foster Sanders Petersen Holmes Robbins
               Tillman Crawford Olson Horton Bean Huber Howe Douglas Whitaker Barron
               Everett Higgins Foley Boyer Flores Stephens Goodwin Coffey Cherry Cline
               Walter Hart Copeland Dickson Reyes Steele Drake Maxwell Foster Blevins
               Pickett McMillan Evans Day Preston David Singleton Herman Mullen Pearson
               Lynch Goff Hull Walter Stuart Ferguson Shepherd Alston Kirby Potts ]

PRONOUNS = %w[ he/him she/her they/them ]

mdb = Company.create(name: 'MongoDB, Inc.', industry: 'tech')

exec_dept = mdb.departments.create(name: 'Exec')
engineering = mdb.departments.create(name: 'Engineering')
marketing = mdb.departments.create(name: 'Marketing')
hr = mdb.departments.create(name: 'Human Resources')

exec_team = exec_dept.teams.create(name: 'Exec')

dbx = engineering.teams.create(name: 'DBX')
server = engineering.teams.create(name: 'Server')
cloud = engineering.teams.create(name: 'Cloud')

devrel = marketing.teams.create(name: 'Developer Relations')
pr = marketing.teams.create(name: 'Public Relations')
enterprise = marketing.teams.create(name: 'Enterprise')

employee_experience = hr.teams.create(name: 'Employee Experience')
talent = hr.teams.create(name: 'Talent Acquisition')
ctd = hr.teams.create(name: 'Culture, Talent, & Development')

def next_person(attrs)
  name = Name.new(given: GIVEN_NAMES.sample, surname: SURNAMES.sample)
  Person.create(attrs.merge(pronouns: PRONOUNS.sample, name: name)).tap do |person|
    yield person if block_given?
  end
end

next_person(team: exec_team) do |person|
  Position.create(organization: mdb, title: 'CEO', person: person)
end

next_person(team: exec_team) do |person|
  Position.create(organization: exec_dept, title: 'Chief of Staff', person: person)
  Position.create(organization: exec_team, title: 'Chief of Staff', person: person)
end

next_person(team: exec_team) do |person|
  Position.create(organization: engineering, title: 'VP Engineering', person: person)
end

next_person(team: exec_team) do |person|
  Position.create(organization: marketing, title: 'VP Marketing', person: person)
end

next_person(team: exec_team) do |person|
  Position.create(organization: hr, title: 'VP Human Resources', person: person)
end

[ dbx, server, cloud, devrel, pr, enterprise, employee_experience, talent, ctd ].each do |team|
  next_person(team: team) do |person|
    Position.create(organization: team, title: "Head of #{team.name}", person: person)
  end

  5.times { next_person(team: team) }
end

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
