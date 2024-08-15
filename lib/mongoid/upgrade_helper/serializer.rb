require 'json'

module Mongoid
  module UpgradeHelper
    # We need a serializer implementation that is stable between Ruby versions,
    # and which can be adapted to work for different Mongoid, driver, and BSON
    # versions. The Marshal utilities won't work for us here, so we write our
    # own framework.
    module Serializer
      extend self

      # A trivial serializer for atomic types.
      module Atomic
        # Simply inspects the type, so it can be eval'd
        def _mongoid_upgrade_helper_serialize
          inspect
        end
      end

      # A serializer for Hashes
      module Hash
        # Recursively serializes keys and values for the hash. Note that this
        # does not attempt to detect cycles in the graph!
        def _mongoid_upgrade_helper_serialize
          "".tap do |s|
            s << '{'
            each do |key, value|
              s << Serializer.serialize(key) << '=>'
              s << Serializer.serialize(value) << ','
            end
            s << '}'
          end
        end
      end

      # A serializer for Arrays
      module Array
        # Recursively serializes entries for the array. Note that this
        # does not attempt to detect cycles in the graph!
        def _mongoid_upgrade_helper_serialize
          "".tap do |s|
            s << '['
            each do |entry|
              s << Serializer.serialize(entry) << ','
            end
            s << ']'
          end
        end
      end

      # A serializer (and deserializer) for Mongoid::Criteria
      module Criteria
        extend ActiveSupport::Concern

        # Emits an "eval"-able string that will reconstruct the Mongoid::Criteria
        # instance::Criteria.
        def _mongoid_upgrade_helper_serialize
          "".tap do |s|
            s << 'Criteria._mongoid_upgrade_helper_deserialize('
            s << klass.name << ','
            s << embedded?.inspect << ','
            s << empty_and_chainable?.inspect << ','
            s << Serializer.serialize(options) << ','
            s << Serializer.serialize(selector) << ','
            s << Serializer.serialize(pipeline) << ','
            s << Serializer.serialize(documents)
            s << ')'
          end
        end

        class_methods do
          # Reconstructs a Mongoid::Criteria instance from the given state.
          def _mongoid_upgrade_helper_deserialize(klass, embedded, none, options, selector, pipeline, documents)
            Mongoid::Criteria.new(klass).tap do |criteria|
              criteria.embedded = embedded
              criteria.none if none
              criteria.options.replace(options)
              criteria.selector.replace(selector)
              criteria.pipeline.replace(pipeline)
              criteria.documents.replace(documents)
            end
          end
        end
      end

      # A serializer for Mongoid::Contextual::Mongo instances.
      module MongoContext
        # Returns an "eval"-able string that will recreate the context instance
        # with its current criteria.
        def _mongoid_upgrade_helper_serialize
          'Mongoid::Contextual::Mongo.new(' <<
            Serializer.serialize(criteria) <<
            ')'
        end
      end

      module EmbeddedMany
        def _mongoid_upgrade_helper_serialize
          'Mongoid::Relations::Embedded::Many.new(' <<
            Serializer.serialize(base) << ',' <<
            Serializer.serialize(target) << ',' <<
            Serializer.serialize(__metadata) <<
          ')'
        end
      end

      # A serializer for Mongoid::Document instances.
      module Document
        # Returns an "eval"-able string that will instantiate a new model and
        # populate it with the current attributes.
        def _mongoid_upgrade_helper_serialize
          "#{self.class.name}.new(#{as_document.inspect})"
        end
      end

      # A helper method for calling _mongoid_upgrade_helper_serialize on the
      # argument.
      def serialize(object)
        object._mongoid_upgrade_helper_serialize
      end
    end
  end
end

Numeric.include(Mongoid::UpgradeHelper::Serializer::Atomic)
String.include(Mongoid::UpgradeHelper::Serializer::Atomic)
Symbol.include(Mongoid::UpgradeHelper::Serializer::Atomic)
TrueClass.include(Mongoid::UpgradeHelper::Serializer::Atomic)
FalseClass.include(Mongoid::UpgradeHelper::Serializer::Atomic)
NilClass.include(Mongoid::UpgradeHelper::Serializer::Atomic)
Range.include(Mongoid::UpgradeHelper::Serializer::Atomic)
Class.include(Mongoid::UpgradeHelper::Serializer::Atomic)

Hash.include(Mongoid::UpgradeHelper::Serializer::Hash)
Array.include(Mongoid::UpgradeHelper::Serializer::Array)

BSON::ObjectId.include(Mongoid::UpgradeHelper::Serializer::Atomic)
Mongoid::Document.include(Mongoid::UpgradeHelper::Serializer::Document)
Mongoid::Criteria.include(Mongoid::UpgradeHelper::Serializer::Criteria)
Mongoid::Contextual::Mongo.include(Mongoid::UpgradeHelper::Serializer::MongoContext)
Mongoid::Relations::Embedded::Many.include(Mongoid::UpgradeHelper::Serializer::EmbeddedMany)
