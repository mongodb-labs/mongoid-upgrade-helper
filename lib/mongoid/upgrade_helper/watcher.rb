# frozen_string_literal: true

require 'json'
require_relative 'watcher/watchable'
require_relative 'watcher/setup'

module Mongoid
  module UpgradeHelper
    # A singleton class that looks for database commands issued during a
    # monitored block.
    class Watcher
      # the identifier used to scope thread-local variables used by the watcher
      # 
      # @api private
      WATCHER_THREAD_KEY = :__mongoid_upgrade_helper_watcher

      # the Mutex used to protect the singleton Watcher instance
      #
      # @api private
      INSTANCE_MUTEX = Mutex.new

      class << self
        extend Forwardable

        # Return the singleton Watcher instance.
        def instance
          @instance ||= INSTANCE_MUTEX.synchronize { @instance ||= new }
        end

        # Prepares the core Mongoid API so that appropriate API calls are watched.
        def initialize!
          return if @watcher_is_setup

          instance # force the singleton instance to be instantiated

          Mongoid::Contextual::Mongo.prepend Mongoid::UpgradeHelper::Watcher::Setup::Mongo
          Mongoid::Document.prepend Mongoid::UpgradeHelper::Watcher::Setup::Document

          @watcher_is_setup = true
        end

        # delegate to the singleton instance for convenience
        def_delegators :instance, :watch, :suppress
      end

      # Create a new Watcher instance. This will attempt to subscribe globally to all
      # MongoDB clients, and thus MUST be called before any clients are created.
      def initialize
        @id_mutex = Mutex.new
        @next_id = 1
        @uuid = SecureRandom.uuid

        Mongo::Monitoring::Global.subscribe(Mongo::Monitoring::COMMAND, self)
      end

      concerning :Observation do
        # If a watch is already active on the current thread, this will simply
        # yield to the block.
        #
        # If no watch is active on the current thread, this will start one
        # before yielding to the block. Once the block terminates, the watch
        # will be terminated as well.
        #
        # Starting a watch will emit a "start" action with the serialized
        # receiver, message, and arguments.
        # 
        # Stopping a watch will emit a corresponding "stop" action.
        def watch(receiver, message, block_present, *args, **kwargs)
          active_watch = Thread.current[WATCHER_THREAD_KEY]
          start_watching(receiver, message, block_present, *args, **kwargs) unless active_watch

          yield
        ensure
          stop_watching unless active_watch
        end

        # Temporarily disables the currently active watcher in the current
        # thread, for the duration of the block.
        def suppress
          current_watch, Thread.current[WATCHER_THREAD_KEY] = Thread.current[WATCHER_THREAD_KEY], nil
          yield
        ensure
          Thread.current[WATCHER_THREAD_KEY] = current_watch
        end

        private

        # Starts listening for commands from the given receiver#message
        # invocation. This will emit a "start" action with the serialized
        # receiver, message, and arguments.
        def start_watching(receiver, message, block_present, *args, **kwargs)
          Thread.current[WATCHER_THREAD_KEY] = next_id

          emit action: :start,
               receiver: serialize(receiver),
               message: message,
               args: args,
               kwargs: kwargs,
               block: block_present
        end

        # Stops listening for commands from the most recent recever#message
        # invocation. This will emit a "stop" action.
        def stop_watching
          emit action: :stop
          Thread.current[WATCHER_THREAD_KEY] = nil
        end

        # Returns the id of the current watch, or nil if no watch is active.
        def current_watch
          Thread.current[WATCHER_THREAD_KEY]
        end
      end
      
      concerning :Monitoring do
        # Invoked by the driver when a database command is issued.
        def started(event)
          # we only emit the command if there is a current invocation active,
          # as that means we're within the scope of an observed API call.
          emit action: :command, command: event.command if current_watch
        end

        # Invoked by the driver when a database command succeeds.
        def succeeded(event)
          # we don't actually care whether the command succeeded or not
        end

        # Invoked by the driver when a database command fails..
        def failed(event)
          # we don't actually care whether the command succeeded or not
        end
      end

      private

      # Serializes (via JSON) the given payload, and then passes the result to
      # the registered `on_action` handler.
      def emit(payload)
        full_payload = prepare_payload(payload)
        Mongoid::UpgradeHelper.on_action&.call(full_payload)
      rescue Exception => e
        Mongoid.logger.error("could not emit Mongoid::UpgradeHelper action: #{e.class} #{e.message}")
      end

      def prepare_payload(payload)
        payload.merge(id: current_watch).to_json
      rescue Exception => e
        { id: current_watch, action: payload[:action], error: "#{e.class}: #{e.message}" }.to_json
      end

      def next_id
        @id_mutex.synchronize do
          "#{@uuid}:#{@next_id}".tap { @next_id += 1 }
        end
      end

      def serialize(object)
        case object
        when Mongoid::Document
          { type: :document,
            class: object.class.name,
            attrs: object.as_document }
        when Criteria
          { type: :criteria,
            class: object.klass.name,
            selector: object.selector,
            options: object.options,
            inclusions: object.inclusions,
            scoping_options: object.scoping_options,
            documents: object.documents }
        when Mongoid::Contextual::Mongo
          # probably will need to save some additional state, too...maybe?
          { type: :context, criteria: serialize(object.criteria) }
        when Class
          { type: :class, class: object.name }
        else
          { type: :object, object: object }
        end
      end
    end
  end
end
