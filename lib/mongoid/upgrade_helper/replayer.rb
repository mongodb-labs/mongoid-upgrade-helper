# frozen_string_literal: true

require 'base64'
require 'json'
require_relative 'replayer/setup'
require_relative 'serializer'
require_relative 'watcher'

module Mongoid
  module UpgradeHelper
    class Replayer
      # the identifier used to scope thread-local variables used by the replayer
      # 
      # @api private
      REPLAYER_THREAD_KEY = :__mongoid_upgrade_helper_replayer

      REPLAYER_RESULTS_THREAD_KEY = :__mongoid_upgrade_helper_replayer_results

      class << self
        # Initializes the runtime environment, preparing it so that commands can
        # be replayed. This also initializes the Watcher subsystem.
        #
        # Note that this MUST be invoked before any clients are created, because
        # of how global monitoring subscribers are implemented by the driver.
        def setup!
          return if @replayer_is_ready

          Mongoid::UpgradeHelper::Replayer::Setup.apply!
          Mongoid::UpgradeHelper::Watcher.initialize!

          @replayer_is_ready = true
        end

        # Signals to the watcher that a command with the given `watch` identifier
        # is about to be replayed. It ensures that the watcher uses the given
        # watch identifier for subsequent commands, so that replayed commands
        # can be matched with the original run.
        #
        # @param [ String ] watch the id of the watch to use
        def replaying(watch)
          saved, Thread.current[REPLAYER_THREAD_KEY] = Thread.current[REPLAYER_THREAD_KEY], true
          Mongoid::UpgradeHelper::Watcher.with_watch(watch) do
            yield
          end
        ensure
          Thread.current[REPLAYER_THREAD_KEY] = saved
        end

        # Indicates whether a replayer is active in the current thread.
        def replaying?
          Thread.current[REPLAYER_THREAD_KEY]
        end

        def next_result
          (Thread.current[REPLAYER_RESULTS_THREAD_KEY] || []).shift.tap { |v| p v }
        end
        
        # Creates a new replayer that wraps the contents of the file with the
        # given name. The replayer is yielded to the block.
        #
        # @param [ String ] file_name the name of the file to read.
        def with_file(file_name, &block)
          File.open(file_name) do |file|
            with_io(file, &block)
          end
        end

        # Creates a new replayer that wraps the given IO object. The replayer is
        # yielded to the block.
        #
        # @param [ IO ] io the IO object that the replayer should read from.
        def with_io(io, &block)
          yield new(io.each_line)
        end
      end

      # Create a new replayer with the given source.
      #
      # @param [ Enumerable ] source the enumerable that contains the log of
      #   the actions from a Watcher.
      def initialize(source)
        @source = source
      end
      
      # Steps through each line of the replayer's source, parsing them one at
      # a time and replaying the `start` entries.
      def replay!
        loop do
          # entries will be in the following format
          #   'start' -- describing the API that initiated this
          #   0 or more of
          #     - 1 or more of 'command' followed by 'result'
          #     - 0 or more nested entries
          #   'stop'
          #
          # we read a line, which must be 'start'

          line = @source.next
          action, watch, entry = parse_entry(line)
          abort "expected `start` action, got #{action.inspect}" unless action == 'start'

          # process "command" and "result" up until we read a "stop" action,
          # or the next action is "start".
          enqueue_results!

          replay_entry(entry, watch)
        end
      rescue StopIteration
      end

      def enqueue_results!
        Thread.current[REPLAYER_RESULTS_THREAD_KEY] ||= []

        loop do
          line = @source.peek
          action, * = parse_entry(line)
          if action == 'command'
            @source.next # skip the command

            line = @source.next # read the result
            action, _, result = parse_entry(line)

            if action != 'result'
              raise ArgumentError, "expected result after command, got #{action.inspect}"
            end

            Thread.current[REPLAYER_RESULTS_THREAD_KEY].push Serializer.deserialize(result)
          elsif action == 'stop'
            @source.next # skip the 'stop'
          else
            break
          end
        end
      end

      # Replay a specific entry. Note that the entry must be a 'start' action
      # type, or the results are undefined.
      #
      # @param [ Hash ] entry the Hash of attributes that describe the entry.
      def replay_entry(entry, watch)
        Replayer.replaying(watch) do
          block = entry['block'] ? Proc.new { } : nil

          receiver = Serializer.deserialize(entry['receiver'])
          args = Serializer.deserialize(entry['args']) || []
          kwargs = Serializer.deserialize(entry['kwargs']) || {}

          receiver.send(entry['message'], *args, **kwargs, &block)
        end
      end

      private

      # Parse the entry from the given line. Only `start` entries are considered;
      # anything else will return `nil`.
      #
      # `start` lines are assumed to contain three parts, separated by colons:
      # the action name, the watch, and the payload. The payload itself is a
      # serialized representation of the receiver, message, and arguments.
      #
      # @param [ String ] line the line to parse.
      def parse_entry(line)
        action, watch, payload = line.split(':', 3)
        return [ action, watch, JSON.parse(payload) ]
      end
    end
  end
end
