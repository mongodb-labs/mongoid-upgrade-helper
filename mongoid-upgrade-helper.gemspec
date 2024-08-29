# frozen_string_literal: true

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'mongoid/upgrade_helper/version'

p Mongoid::UpgradeHelper::Version::STRING
Gem::Specification.new do |s|
  s.name        = 'mongoid-upgrade-helper'
  s.version     = Mongoid::UpgradeHelper::Version::STRING
  s.platform    = Gem::Platform::RUBY
  s.authors     = [ 'The MongoDB Ruby Team' ]
  s.email       = 'dbx-ruby@mongodb.com'
  s.homepage    = 'https://mongoid.org'
  s.summary     = 'A toolbox for helping developers upgrade older installations of Mongoid'
  s.description = 'A set of tools to help developers evaluate the impact of upgrading ' \
                  'from one version of Mongoid to another'
  s.license     = 'MIT'

  s.metadata = {
    'bug_tracker_uri' => 'https://jira.mongodb.org/projects/MONGOID',
    'changelog_uri' => 'https://github.com/mongodb/mongoid/releases',
    'documentation_uri' => 'https://www.mongodb.com/docs/mongoid/',
    'homepage_uri' => 'https://mongoid.org/',
    'source_code_uri' => 'https://github.com/mongodb/mongoid',
  }

  s.required_ruby_version     = '>= 2.7'
  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency('mongoid', '>= 6.0')

  s.files        = Dir.glob('lib/**/*') + %w[ README.md ]
  s.require_path = 'lib'
end
