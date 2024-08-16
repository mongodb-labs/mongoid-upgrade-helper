# frozen_string_literal: true

require_relative 'watchable'

module Mongoid
  module UpgradeHelper
    class Watcher
      # A set of modules that encapsulate the necessary functionality to watch
      # the standard Mongoid API.
      module Setup
        def self.apply!
          Mongoid::Contextual::Mongo.prepend Mongo

          Mongoid::Criteria.prepend Criteria

          Mongoid::Document.prepend Document
          Mongoid::Persistable::Creatable.prepend Creatable::InstanceMethods
          Mongoid::Persistable::Creatable::ClassMethods.prepend Creatable::ClassMethods
          Mongoid::Persistable::Deletable.prepend Deletable::InstanceMethods
          Mongoid::Persistable::Deletable::ClassMethods.prepend Deletable::ClassMethods
          Mongoid::Persistable::Destroyable.prepend Destroyable::InstanceMethods
          Mongoid::Persistable::Destroyable::ClassMethods.prepend Destroyable::ClassMethods
          Mongoid::Persistable::Incrementable.prepend Incrementable
          Mongoid::Persistable::Logical.prepend Logical
          Mongoid::Persistable::Poppable.prepend Poppable
          Mongoid::Persistable::Pullable.prepend Pullable
          Mongoid::Persistable::Pushable.prepend Pushable
          Mongoid::Persistable::Renamable.prepend Renamable
          Mongoid::Persistable::Savable.prepend Savable
          Mongoid::Persistable::Settable.prepend Settable
          Mongoid::Persistable::Updatable.prepend Updatable
          Mongoid::Persistable::Upsertable.prepend Upsertable
          Mongoid::Persistable::Unsettable.prepend Unsettable
          Mongoid::Findable.prepend Findable
          Mongoid::Reloadable.prepend Reloadable

          if Mongoid::VERSION < '7.0'
            Mongoid::Relations::Embedded::Many.prepend EmbedsMany
          else
            Mongoid::Association::Embedded::EmbedsMany::Proxy.prepend EmbedsMany
          end
        end

        module Mongo
          include Watchable

          watch_method :delete
          watch_method :delete_all
          watch_method :each
        end

        module Criteria
          include Watchable

          watch_method :delete
          watch_method :delete_all
        end

        module Document
          include Watchable

          watch_method :delete
          watch_method :reload
          watch_method :remove
          watch_method :update_document
        end

        module Creatable
          module InstanceMethods
            include Watchable

            watch_method :insert
          end

          module ClassMethods
            include Watchable

            watch_method :create
            watch_method :create!
          end
        end

        module Deletable
          module InstanceMethods
            include Watchable

            watch_method :delete
          end

          module ClassMethods
            include Watchable

            watch_method :delete_all
          end
        end

        module Destroyable
          module InstanceMethods
            include Watchable

            watch_method :destroy
            watch_method :destroy!
          end

          module ClassMethods
            include Watchable

            watch_method :destroy_all
          end
        end

        module Incrementable
          include Watchable

          watch_method :inc
        end

        module Logical
          include Watchable

          watch_method :bit
        end

        module Poppable
          include Watchable

          watch_method :pop
        end

        module Pullable
          include Watchable

          watch_method :pull
          watch_method :pull_all
        end

        module Pushable
          include Watchable

          watch_method :add_to_set
          watch_method :push
        end

        module Renamable
          include Watchable

          watch_method :rename
        end

        module Savable
          include Watchable

          watch_method :save
          watch_method :save!
        end

        module Settable
          include Watchable

          watch_method :set
        end

        module Updatable
          include Watchable

          watch_method :update_attribute
          watch_method :update_attributes
          watch_method :update
          watch_method :update!
        end

        module Upsertable
          include Watchable

          watch_method :upsert
        end
        
        module Unsettable
          include Watchable

          watch_method :unset
        end

        module Findable
          include Watchable

          watch_method :count
          watch_method :empty?
          watch_method :exists?
          watch_method :find
          watch_method :find_by
          watch_method :find_by!
          watch_method :first
          watch_method :last

          if Mongoid::VERSION >= '7.2'
            watch_method :estimated_count
          end
        end

        module Reloadable
          include Watchable

          watch_method :reload
        end

        module EmbedsMany
          include Watchable

          watch_method :delete
          watch_method :delete_all
        end
      end
    end
  end
end

