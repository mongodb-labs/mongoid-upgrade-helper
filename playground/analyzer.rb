# frozen_string_literal: true

require 'mongoid'
require 'mongoid/upgrade_helper'

BULLET = ' - '
INDENT = ' ' * BULLET.length

analyzer = Mongoid::UpgradeHelper::Analyzer.new(
            'watcher-output.log',
            'replayer-output.log')

puts "Diff:"
analyzer.differences.each do |diff|
  puts BULLET + diff[:msg]
  puts INDENT + 'command: ' + diff[:cmd]

  case diff[:type]
  when :lone_command
    puts INDENT + diff[:info].inspect

  when :different_counts
    puts INDENT + 'original:'
    diff[:info].first.each do |cmd|
      puts INDENT + BULLET + cmd.inspect
    end
    puts INDENT + 'replay:'
    diff[:info].last.each do |cmd|
      puts INDENT + BULLET + cmd.inspect
    end

  when :different_commands
    puts INDENT + 'original:'
    puts INDENT + BULLET + diff[:info].first.inspect
    puts INDENT + 'replay:'
    puts INDENT + BULLET + diff[:info].last.inspect
  end
end
