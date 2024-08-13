# frozen_string_literal: true

require_relative 'upgrade_helper/analyzer'
require_relative 'upgrade_helper/replayer'
require_relative 'upgrade_helper/setup'
require_relative 'upgrade_helper/watcher'

module Mongoid
  module UpgradeHelper
    class << self
      # If called with a block, this saves that block to be invoked by the other helpers whenever
      # an action occurs. The argument to the block will be a string describing the action.
      #
      # If called without a block, this will return the saved block (if any).
      def on_action(&block)
        @on_action = block if block
        @on_action
      end
    end
  end
end
