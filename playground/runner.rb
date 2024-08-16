# frozen_string_literal: true

require 'mongoid'
require 'mongoid/upgrade_helper'

LOGGER = File.open('watcher-output.log', 'w')
Mongoid::UpgradeHelper.on_action { |action| LOGGER.puts(action) }

Mongoid::UpgradeHelper::Watcher.initialize!

require_relative 'populator'
Mongoid.connect_to 'mongoid-upgrade-helper-test'

class FeatureRunner
  class << self
    def run
      runner = new

      Array(@features).each do |feature|
        runner[feature] = runner.send(name_for(feature))
      end
    end

    def feature(feature, &block)
      (@features ||= []) << feature
      define_method(name_for(feature), &block)
    end

    private

    def name_for(feature)
      :"feature__#{feature}"
    end
  end

  def initialize
    @results = {}
    @populator = Populator.new
  end

  def []=(key, value)
    @results[key] = value
  end

  def [](key)
    @results[key]
  end

  def at_least?(version)
    Mongoid::VERSION >= version
  end
  
  feature :count do
    Person.count
    Person.estimated_count if at_least? '7.2'
  end

  feature :empty? do
    Person.empty?
  end

  feature :exists? do
    Person.exists?
    Person.exists?(name: 'name') if at_least? '8.1'
    Person.exists?(BSON::ObjectId.new) if at_least? '8.1'
  end

  feature :find_all do
    Company.all.to_a
  end

  feature :find_one do
    Company.find(self[:find_all].first.id)
  end

  feature :find_by do
    Company.find_by(name: self[:find_one].name)
    Company.find_by!(name: self[:find_one].name)
  end

  feature :first do
    Person.first
  end

  feature :last do
    Person.last
  end

  feature :create do
    Company.create(name: 'Apple Inc.')
    Company.create!(name: 'Microsoft Corporation')
  end

  feature :insert do
    company = Company.new(name: 'Meta Platforms Inc')
    company.insert
  end

  feature :delete do
    self[:insert].delete
    Company.where(:name.ne => self[:find_one].name).delete
    Company.where(:name.ne => self[:find_one].name).delete_all
    Project.delete_all

    project = @populator.new_project(first_team)

    # embedded record deletions
    project.tasks.first.delete
    project.tasks.delete(project.tasks.first)
    project.tasks.delete_all
  end

  feature :destroy do
    self[:insert].destroy
    self[:insert].destroy!
    Company.where(:name.ne => self[:find_one].name).destroy_all
    Project.destroy_all
  end

  feature :inc do
    first_person.inc(kudos: 2)
  end

  feature :bit do
    first_person.bit(kudos: { and: 0x10, or: 0x101 })
  end

  feature :pop do
    first_person.pop(favorites: 1)
    first_person.pop(favorites: -1)
  end

  feature :pull do
    first_person.pull(favorites: 'chocolate')
    first_person.pull_all(favorites: %w[ chocolate running ])
  end

  feature :push do
    first_person.add_to_set(favorites: 'chocolate')
    first_person.add_to_set(favorites: %w[ chocolate running ])
    first_person.push(favorites: 'chocolate')
    first_person.push(favorites: %w[ chocolate running ])
  end

  feature :rename do
    first_person.rename(kudos: 'praise')
  end

  feature :save do
    person = silent { Team.last.members.new(name: Name.new(given: 'Rand', surname: "al'Thor")) }

    # save -> create
    person.save

    # save -> create
    person.kudos = 1000
    person.save
  end

  feature :save! do
    person = silent { Team.last.members.new(name: Name.new(given: 'Rand', surname: "al'Thor")) }

    # save -> create
    person.save!

    # save -> create
    person.kudos = 1000
    person.save!
  end

  feature :set do
    first_person.set kudos: 100, pronouns: 'ze/zir/zirs'
  end

  feature :update do
    first_person.update_attribute :kudos, 50
    first_person.update_attributes kudos: 60, pronouns: 'he/him/his'
    first_person.update kudos: 70, pronouns: 'ze/zir/zirs'
    first_person.update! kudos: 80, pronouns: 'they/them/theirs'
  end

  feature :upsert do
    # new record
    first_team.members.new(name: Name.new(given: 'Bilbo', surname: 'Baggins')).upsert

    # existing record
    first_person.kudos = 90
    first_person.upsert
  end

  feature :unset do
    first_person.unset :bogus1, :bogus2
  end

  feature :reload do
    first_person.reload
  end

  private

  def silent
    Mongoid::UpgradeHelper::Watcher.suppress(:all) do
      yield
    end
  end

  def first_person
    silent { Person.first }
  end

  def first_team
    silent { Team.first }
  end
end

FeatureRunner.run
