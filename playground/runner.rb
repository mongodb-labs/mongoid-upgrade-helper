# frozen_string_literal: true

require 'mongoid'
require 'mongoid/upgrade_helper'

LOGGER = File.open('watcher-output.log', 'w')
Mongoid::UpgradeHelper.on_action { |action| LOGGER.puts(action) }

Mongoid::UpgradeHelper::Watcher.initialize!

require_relative 'models'
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
  end

  def []=(key, value)
    @results[key] = value
  end

  def [](key)
    @results[key]
  end
  
  feature :count do
    Person.count
  end

  feature :estimated_count do
    Person.estimated_count
  end

  feature :empty? do
    Person.empty?
  end

  feature :exists? do
    Person.exists?
    Person.exists?(name: 'name')
    Person.exists?(BSON::ObjectId.new)
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
end

FeatureRunner.run
