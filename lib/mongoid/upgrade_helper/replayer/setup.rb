# frozen_string_literal: true

module Mongoid
  module UpgradeHelper
    class Replayer
      module Setup
        def self.apply!
          Mongo::Server::ConnectionBase.prepend(Setup::ConnectionBase)
        end

        # Monkey-patching so we can prevent sending commands to the server while
        # replaying. Must be mixed in with `prepend`, so that `super` calls
        # work as expected.
        #
        # @api private
        module ConnectionBase
          private

          # Reimplement the deliver method so that it checks to see if a replayer
          # is active on the current thread. If a replayer is active, it simply
          # emits a `command_started` event, and then throws
          # :abort_mongoid_upgrade_helper_replay, thus aborting the rest of the
          # command (and preventing the command from being executed on the server).
          #
          # If a replayer is not active, `deliver` simply calls the original
          # implementation.
          def deliver(message, context, options = {})
            if Mongoid::UpgradeHelper::Replayer.replaying?
              operation_id = Mongo::Monitoring.next_operation_id
              command_started(address, operation_id, message.payload)

              result = Mongoid::UpgradeHelper::Replayer.next_result

              if result && context.decrypt?
                result = result.maybe_decrypt(context)
              end

              return result
            end

            super
          end
        end
      end
    end
  end
end
