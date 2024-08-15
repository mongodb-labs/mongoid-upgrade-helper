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

    project = @populator.new_project(silent { Team.first })

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
    person = silent { Person.first }
    person.inc(kudos: 2)
  end

  feature :bit do
    person = silent { Person.first }
    person.bit(kudos: { and: 0x10, or: 0x101 })
  end

  feature :pop do
    person = silent { Person.first }
    person.pop(favorites: 1)
    person.pop(favorites: -1)
  end

  private

  def silent
    Mongoid::UpgradeHelper::Watcher.suppress(:all) do
      yield
    end
  end
end

FeatureRunner.run
