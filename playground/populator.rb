# frozen_string_literal: true

require 'mongoid/upgrade_helper/watcher'
require_relative './models'

class Populator
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

  def populate
    %i[ exec_team
        dbx server cloud
        devrel pr enterprise
        employee_experience talent ctd
    ].each do |team|
      silent { send(team) }
    end
  end

  def mdb
    @mdb ||= silent { Company.create(name: 'MongoDB, Inc.', industry: 'tech') }
  end

  def exec_dept
    @exec_dept ||= silent { mdb.departments.create(name: 'Exec') }
  end

  def engineering
    @engineering ||= silent { mdb.departments.create(name: 'Engineering') }
  end

  def marketing
    @marketing ||= silent { mdb.departments.create(name: 'Marketing') }
  end

  def hr
    @hr ||= silent { mdb.departments.create(name: 'Human Resources') }
  end

  def exec_team
    @exec_team ||= silent do
      exec_dept.teams.create(name: 'Exec').tap do |exec_team|
        new_person(team: exec_team) do |person|
          Position.create(organization: mdb, title: 'CEO', person: person)
        end

        new_person(team: exec_team) do |person|
          Position.create(organization: exec_dept, title: 'Chief of Staff', person: person)
          Position.create(organization: exec_team, title: 'Chief of Staff', person: person)
        end

        new_person(team: exec_team) do |person|
          Position.create(organization: engineering, title: 'VP Engineering', person: person)
        end

        new_person(team: exec_team) do |person|
          Position.create(organization: marketing, title: 'VP Marketing', person: person)
        end

        new_person(team: exec_team) do |person|
          Position.create(organization: hr, title: 'VP Human Resources', person: person)
        end
      end
    end
  end

  def dbx
    @dbx ||= silent { engineering.teams.create(name: 'DBX').tap { |team| populate_team(team) } }
  end

  def server
    @server ||= silent { engineering.teams.create(name: 'Server').tap { |team| populate_team(team) } }
  end

  def cloud
    @cloud ||= silent { engineering.teams.create(name: 'Cloud').tap { |team| populate_team(team) } }
  end

  def devrel
    @devrel ||= silent { marketing.teams.create(name: 'Developer Relations').tap { |team| populate_team(team) } }
  end

  def pr
    @pr ||= silent { marketing.teams.create(name: 'Public Relations').tap { |team| populate_team(team) } }
  end

  def enterprise
    @enterprise ||= silent { marketing.teams.create(name: 'Enterprise').tap { |team| populate_team(team) } }
  end

  def employee_experience
    @employee_experience ||= silent { hr.teams.create(name: 'Employee Experience').tap { |team| populate_team(team) } }
  end

  def talent
    @talent ||= silent { hr.teams.create(name: 'Talent Acquisition').tap { |team| populate_team(team) } }
  end

  def ctd
    @ctd ||= silent { hr.teams.create(name: 'Culture, Talent, & Development').tap { |team| populate_team(team) } }
  end

  def new_project(team)
    silent do
      tasks = Array.new(5) { Task.new(label: 'label') }
      team.projects.create(name: 'project', tasks: tasks)
    end
  end

  def new_person(attrs)
    silent do
      name = Name.new(given: GIVEN_NAMES.sample, surname: SURNAMES.sample)
      Person.create(attrs.merge(pronouns: PRONOUNS.sample, name: name)).tap do |person|
        yield person if block_given?
      end
    end
  end

  def populate_team(team)
    silent do
      new_person(team: team) do |person|
        Position.create(organization: team, title: "Head of #{team.name}", person: person)
      end

      5.times { new_person(team: team) }
    end
  end

  def silent
    Mongoid::UpgradeHelper::Watcher.suppress(:all) do
      yield
    end
  end
end
