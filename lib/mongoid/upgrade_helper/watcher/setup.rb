# frozen_string_literal: true

require_relative 'watchable'

module Mongoid
  module UpgradeHelper
    class Watcher
      # A set of modules that encapsulate the necessary functionality to watch
      # the standard Mongoid API.
      module Setup
        module Mongo
          include Watchable

          watch_method :each
        end

        module Document
          include Watchable

          watch_method :delete
          watch_method :insert
          watch_method :reload
          watch_method :remove
          watch_method :update_document
        end

        module Findable
          include Watchable

          watch_method :count
          watch_method :estimated_count
          watch_method :empty?
          watch_method :exists?
          watch_method :find
          watch_method :find_by
          watch_method :find_by!
          watch_method :first
          watch_method :last
        end
      end
    end
  end
end

