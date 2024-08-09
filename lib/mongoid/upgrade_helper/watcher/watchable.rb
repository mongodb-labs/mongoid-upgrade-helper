# frozen_string_literal: true

module Mongoid
  module UpgradeHelper
    class Watcher
      # Behavior for watchable modules and classes.
      module Watchable
        extend ActiveSupport::Concern

        class_methods do
          # Wraps the given method within a watcher, so that any MongoDB database commands that are
          # issued during that call can be captured (via the `on_action` block).
          def watch_method(name)
            name = name.to_sym

            class_eval <<-DEFN, __FILE__, __LINE__ + 1
              def #{name}(*args, **kwargs, &block)
                Mongoid::UpgradeHelper::Watcher.watch(self, #{name.inspect}, block_given?, *args, **kwargs) do
                  if block_given?
                    super(*args, **kwargs) { |*a| Mongoid::UpgradeHelper::Watcher.suppress { block.call(*a) } }
                  else
                    super(*args, **kwargs)
                  end
                end
              end
            DEFN
          end
        end
      end
    end
  end
end
