# frozen_string_literal: true

module Mongoid
  module UpgradeHelper
    class Analyzer
      def initialize(log1, log2)
        @log1 = parse_log(log1)
        @log2 = parse_log(log2)
      end

      def differences
        [].tap do |diff|
          (@log1.keys - @log2.keys).each do |watch|
            diff << report_lone_command(@log1, watch, 'first run')
          end

          (@log2.keys - @log1.keys).each do |watch|
            diff << report_lone_command(@log2, watch, 'second run')
          end

          (@log1.keys | @log2.keys).each do |watch|
            if @log1[watch].length != @log2[watch].length
              diff << report_different_command_counts(watch)
            else
              @log1[watch].zip(@log2[watch]) do |cmd_a, cmd_b|
                cmd_a = normalize(cmd_a)
                cmd_b = normalize(cmd_b)

                if cmd_a != cmd_b
                  diff << report_different_comands(watch, cmd_a, cmd_b)
                end
              end
            end
          end
        end
      end

      private

      def parse_log(log)
        {}.tap do |watches|
          File.open(log) do |file|
            file.each_line do |line|
              action, watch, payload = line.split(':', 3)
              next unless action == 'command'

              (watches[watch] ||= []) << payload
            end
          end
        end
      end

      def normalize(cmd)
        cmd = JSON.parse(cmd)

        cmd.delete('signature')
        cmd.delete('lsid')
        cmd.delete('$db')
        cmd.delete('$clusterTime')
        cmd.delete('txnNumber')

        normalize_hash(cmd)
      end

      def normalize_hash(cmd)
        cmd.keys.each do |key|
          cmd[key] = normalize_value(cmd[key])
        end

        cmd
      end

      def normalize_value(value)
        case value
        when Hash then
          if value['$oid'] then 
            '<object-id>'
          else
            normalize_hash(value)
          end
        when Array then
          value.map { |v| normalize_value(v) }
        else
          value
        end
      end

      def report_lone_command(log, watch, phrase)
        { msg: "watch #{watch} only exists in the #{phrase}",
          watch: log[watch] }
      end

      def report_different_command_counts(watch)
        { msg: "watch #{watch} has different command counts #{@log1[watch].count} vs #{@log2[watch].count}",
          watch: [ @log1[watch], @log2[watch] ] }
      end

      def report_different_commands(watch, cmd1, cmd2)
        { msg: "watch #{watch} has different commands",
          watch: [ cmd1, cmd2 ] }
      end
    end
  end
end
