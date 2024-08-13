# frozen_string_literal: true

module Mongoid
  module UpgradeHelper
    # A set of custom serializers so that we can seralize classes in Mongoid
    # which were never intended/designed to be serialized.
    #
    # @api private
    module Serializers
      def self.apply!
        require 'mongoid/contextual/mongo'

        Mongoid::Contextual::Mongo.include(Mongoid::UpgradeHelper::Serializers::Mongo)
      end

      # Serialization mix-in for the Mongoid::Contextual::Mongo class.
      module Mongo
        extend ActiveSupport::Concern

        # A Contextual::Mongo object is entirely defined by the criteria used
        # to initialize it, so when dumping a Contextual::Mongo object, all we
        # need to do is dump the criteria.
        def _dump(level)
          Marshal.dump(criteria)
        end

        class_methods do
          # Reconstruct a serialized Contextual::Mongo object from the given
          # data, which is a serialized version of a Mongo::Criteria object.
          def _load(data)
            criteria = Marshal.load(data)
            new(criteria)
          end
        end
      end
    end
  end
end

Mongoid::UpgradeHelper::Serializers.apply!
