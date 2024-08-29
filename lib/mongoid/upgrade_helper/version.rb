# frozen_string_literal: true

module Mongoid
  module UpgradeHelper
    module Version
      MAJOR = 0
      MINOR = 0
      PATCH = 1
      LABEL = 'alpha'

      STRING = [ MAJOR, MINOR, PATCH ].join('.').tap do |version|
                 version << '-' << LABEL if LABEL
               end
    end
  end
end
