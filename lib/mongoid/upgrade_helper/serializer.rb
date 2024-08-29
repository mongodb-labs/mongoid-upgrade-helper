require 'json'

module Mongoid
  module UpgradeHelper
    # We need a serializer implementation that is stable between Ruby versions,
    # and which can be adapted to work for different Mongoid, driver, and BSON
    # versions. The Marshal utilities won't work for us here, so we write our
    # own framework.
    module Serializer
      extend self

      # Represents the serialized invocation of a method
      module Invocation
        def self._mongoid_upgrade_helper_deserialize(data, env = {})
          receiver = Serializer.deserialize(data['receiver'], env)
          args = Serializer.deserialize(data['args'], env)
          kwargs = Serializer.deserialize(data['kwargs'], env)

          receiver.send(data['message'], *args, **kwargs)
        end
      end

      module Array
        extend ActiveSupport::Concern

        def _mongoid_upgrade_helper_serialize(env = {})
          map { |entry| Serializer.serialize(entry, env) }
        end
        
        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, env = {})
            data.map { |item| Serializer.deserialize(item, env) }
          end
        end
      end

      module Class
        extend ActiveSupport::Concern

        def _mongoid_upgrade_helper_serialize(_env = {})
          { __mongoid_serialized: 'Class', name: name }
        end

        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, _env = {})
            data['name'].constantize
          end
        end
      end

      module Hash
        extend ActiveSupport::Concern

        def _mongoid_upgrade_helper_serialize(env = {})
          ::Hash[map { |k, v|
            [ k.to_s, Serializer.serialize(v, env) ]
          }]
        end

        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, env = {})
            if data.key?('__mongoid_serialized')
              class_name = data['__mongoid_serialized']
              class_name.constantize._mongoid_upgrade_helper_deserialize(data, env)
            else
              ::Hash[data.map { |k, v|
                [ k, Serializer.deserialize(v, env) ]
              }]
            end
          end
        end
      end

      module Range
        extend ActiveSupport::Concern

        def _mongoid_upgrade_helper_serialize(_env = {})
          { __mongoid_serialized: 'Range',
            first: Serializer.serialize(first, env),
            last: Serializer.serialize(last, env), 
            exclude_end: exclude_end?
          }
        end

        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, env = {})
            first = Serializer.deserialize(data['first'])
            last = Serializer.deserialize(data['last'])

            Range.new(first, last, data['exclude_end'])
          end
        end
      end

      module Symbol
        extend ActiveSupport::Concern

        def _mongoid_upgrade_helper_serialize(_env = {})
          { __mongoid_serialized: 'Symbol', name: self.name }
        end

        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, _env = {})
            data['name'].to_sym
          end
        end
      end

      module ObjectId
        extend ActiveSupport::Concern

        def _mongoid_upgrade_helper_serialize(_env = {})
          { __mongoid_serialized: 'BSON::ObjectId',
            id: to_s }
        end

        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, _env = {})
            BSON::ObjectId.from_string(data['id'])
          end
        end
      end

      # A serializer (and deserializer) for Mongoid::Criteria
      module Criteria
        extend ActiveSupport::Concern

        # Emits a hash with sufficient info to reconstitute a Criteria object.
        def _mongoid_upgrade_helper_serialize(env = {})
          { __mongoid_serialized: 'Mongoid::Criteria',
            class_name: klass.name,
            embedded: embedded?,
            none: empty_and_chainable?,
            options: Serializer.serialize(options, env),
            selector: Serializer.serialize(selector, env),
            pipeline: Serializer.serialize(pipeline, env),
            documents: Serializer.serialize(documents, env) }
        end

        class_methods do
          # Reconstructs a Mongoid::Criteria instance from the given state.
          def _mongoid_upgrade_helper_deserialize(data, env = {})
            klass = data['class_name'].constantize
            embedded = data['embedded']
            none = data['none']
            options = Serializer.deserialize(data['options'], env)
            selector = Serializer.deserialize(data['selector'], env)
            pipeline = Serializer.deserialize(data['pipeline'], env)
            documents = Serializer.deserialize(data['documents'], env)

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
        extend ActiveSupport::Concern

        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, env = {})
            criteria = Serializer.deserialize(data['criteria'], env)
            Mongoid::Contextual::Mongo.new(criteria)
          end
        end

        # Returns an "eval"-able string that will recreate the context instance
        # with its current criteria.
        def _mongoid_upgrade_helper_serialize(env = {})
          { __mongoid_serialized: 'Mongoid::Contextual::Mongo',
            criteria: Serializer.serialize(criteria, env) }
        end
      end

      module EmbeddedMany
        def _mongoid_upgrade_helper_serialize(env = {})
          name = if Mongoid::VERSION < '7.0'
                   __metadata.name
                 else
                   _association.name
                 end

          { __mongoid_serialized: 'Mongoid::UpgradeHelper::Serializer::Invocation',
            receiver: Serializer.serialize(base, env),
            message: name,
            args: [],
            kwargs: {} }
        end
      end

      # A serializer for Mongoid::Document instances.
      module Document
        extend ActiveSupport::Concern

        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, env = {})
            if env.present? && data['env'].present?
              raise ArgumentError, 'found invalid nested serialized document'
            end

            _mongoid_upgrade_helper_deserialize_ref(data, data['env'] || env)
          end

          private

          def _mongoid_upgrade_helper_deserialize_ref(ref, env)
            klass = ref['__mongoid_serialized']
            id = Serializer.deserialize(ref['id'])
            key = id.to_s

            object = env[klass][key]

            if object.is_a?(Hash)
              _mongoid_upgrade_helper_hydrate(klass, object, key, env)
            else
              object
            end
          end

          def _mongoid_upgrade_helper_hydrate(class_name, defn, key, env)
            klass = class_name.constantize
            attrs = defn['attrs'].merge(new_record: defn['new_record'])

            klass.new(attrs).tap do |record|
              env[class_name][key] = record

              defn['relations'].each do |name, target|
                target = Serializer.deserialize(target, env)
                association = klass.relations[name]
                proxy = association.relation.new(record, target, association)
                record.set_relation(name, proxy)
              end
            end
          end
        end

        def _mongoid_upgrade_helper_serialize(env = {})
          if env.blank?
            _mongoid_upgrade_helper_serialize_start
          else
            _mongoid_upgrade_helper_serialize_recursive(env)
          end
        end

        def _mongoid_upgrade_helper_serialize_start
          env = ::Hash.new { |h, v| h[v] = ::Hash.new }

          # populate the environment
          _root._mongoid_upgrade_helper_serialize_recursive(env)

          { __mongoid_serialized: self.class.name,
            env: env,
            id: Serializer.serialize(id, env) }
        end

        def _mongoid_upgrade_helper_serialize_target(proxy, env)
          target = if proxy.respond_to?(:_target)
                     # 7.0 and later
                     proxy._target
                   else
                     # 6.4 and earlier
                     proxy.target
                   end

          Serializer.serialize(target, env)
        end

        def _mongoid_upgrade_helper_serialize_recursive(env)
          collection = env[self.class.name]
          key = _id.to_s

          unless collection.key?(key)
            # the object has not yet been emitted, so we add it
            # to the environment
            collection[key] = record = { attrs: attributes.dup,
                                         new_record: new_record?,
                                         relations: {} }

            # walk the entire graph, embedded and otherwise.
            self.class.relations.values.each do |relation|
              # don't include embedded relations in the attributes list
              # (avoids duplicate info bloating the serialization output)
              record[:attrs].delete(relation.name.to_s)

              value = ivar(relation.name)
              next unless value.present?

              record[:relations][relation.name] = _mongoid_upgrade_helper_serialize_target(value, env)
            end
          end

          { __mongoid_serialized: self.class.name, id: Serializer.serialize(_id, env) }
        end
      end

      module ProtocolMsg
        extend ActiveSupport::Concern

        class_methods do
          def _mongoid_upgrade_helper_deserialize(data, env = {})
            allocate.tap do |object|
              data['ivars'].each do |name, value|
                value = Serializer.deserialize(value, env)
                object.instance_variable_set(name, value)
              end
            end
          end
        end

        def _mongoid_upgrade_helper_serialize(env = {})
          ivars = instance_variables.each_with_object({}) do |ivar, hash|
                    hash[ivar] = Serializer.serialize(instance_variable_get(ivar), env)
                  end

          { __mongoid_serialized: self.class.name,
            ivars: ivars }
        end
      end

      # A helper method for calling _mongoid_upgrade_helper_serialize on the
      # argument.
      def serialize(object, env = {})
        if object.respond_to?(:_mongoid_upgrade_helper_serialize)
          object._mongoid_upgrade_helper_serialize(env)
        else
          object
        end
      end

      def deserialize(data, env = {})
        if data.class.respond_to?(:_mongoid_upgrade_helper_deserialize)
          data.class._mongoid_upgrade_helper_deserialize(data, env)
        else
          data
        end
      end
    end
  end
end

Array.include(Mongoid::UpgradeHelper::Serializer::Array)
Class.include(Mongoid::UpgradeHelper::Serializer::Class)
Hash.include(Mongoid::UpgradeHelper::Serializer::Hash)
Range.include(Mongoid::UpgradeHelper::Serializer::Range)
Symbol.include(Mongoid::UpgradeHelper::Serializer::Symbol)

BSON::ObjectId.include(Mongoid::UpgradeHelper::Serializer::ObjectId)

Mongo::Protocol::Msg.include(Mongoid::UpgradeHelper::Serializer::ProtocolMsg)

Mongoid::Criteria.include(Mongoid::UpgradeHelper::Serializer::Criteria)
Mongoid::Contextual::Mongo.include(Mongoid::UpgradeHelper::Serializer::MongoContext)
Mongoid::Document.include(Mongoid::UpgradeHelper::Serializer::Document)

if Mongoid::VERSION < '7.0'
  Mongoid::Relations::Embedded::Many.include(Mongoid::UpgradeHelper::Serializer::EmbeddedMany)
else
  Mongoid::Association::Embedded::EmbedsMany::Proxy.include(Mongoid::UpgradeHelper::Serializer::EmbeddedMany)
end
