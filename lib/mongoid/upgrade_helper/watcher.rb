# frozen_string_literal: true

require 'base64'
require_relative 'serializer'
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

          Mongoid::UpgradeHelper::Watcher::Setup.apply!

          @watcher_is_setup = true
        end

        # delegate to the singleton instance for convenience
        def_delegators :instance, :watch, :suppress, :with_watch
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
        # 
        # @param [ :all | nil ] mode if nil (the default), suppress only the
        #   current active watcher. If :all, suppress any watcher for the
        #   duration of the block.
        def suppress(mode = nil)
          new_watch = (mode == :all) ? :none : nil
          current_watch, Thread.current[WATCHER_THREAD_KEY] = Thread.current[WATCHER_THREAD_KEY], new_watch
          yield
        ensure
          Thread.current[WATCHER_THREAD_KEY] = current_watch
        end

        # Executes a block with the given watch identifier. Note that this will
        # suppress `start` and `stop` actions; only `command` actions will be
        # emitted, and will all be tagged with the given watch identifier.
        #
        # @param [ String ] watch the identifier of the watch to use
        def with_watch(watch)
          saved, Thread.current[WATCHER_THREAD_KEY] = Thread.current[WATCHER_THREAD_KEY], watch
          yield
        ensure
          Thread.current[WATCHER_THREAD_KEY] = saved
        end

        private

        # Starts listening for commands from the given receiver#message
        # invocation. This will emit a "start" action with the serialized
        # receiver, message, and arguments.
        def start_watching(receiver, message, block_present, *args, **kwargs)
          Thread.current[WATCHER_THREAD_KEY] = next_id

          payload = { receiver: receiver,
                      message: message.to_s,
                      args: args,
                      kwargs: kwargs,
                      block: block_present }

          serialized = Serializer.serialize(payload)

          emit :start, serialized
        end

        # Stops listening for commands from the most recent recever#message
        # invocation. This will emit a "stop" action.
        def stop_watching
          emit :stop
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
          emit :command, event.command if current_watch && current_watch != :none
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
      def emit(action, payload = nil)
        full_payload = "#{action}:#{current_watch}:#{payload.to_json}"

        Mongoid::UpgradeHelper.on_action&.call(full_payload)
      rescue Exception => e
        Mongoid.logger.error("could not emit Mongoid::UpgradeHelper action: #{e.class} #{e.message}")
      end

      def next_id
        @id_mutex.synchronize do
          "#{@uuid}.#{@next_id}".tap { @next_id += 1 }
        end
      end
    end
  end
end
