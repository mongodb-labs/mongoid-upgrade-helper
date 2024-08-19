# frozen_string_literal: true

require 'mongoid'
require 'mongoid/upgrade_helper'

LOGGER = File.open('replayer-output.log', 'w')
Mongoid::UpgradeHelper.on_action { |action| LOGGER.puts(action) }

Mongoid::UpgradeHelper::Replayer.setup!
Mongoid.connect_to 'mongoid-upgrade-helper-test'

require_relative 'models'

Mongoid::UpgradeHelper::Replayer.with_file('watcher-output.log') do |replayer|
  replayer.replay!
end
