# Mongoid Upgrade Helper

This repository contains tools for helping developers upgrade the Mongoid
version in their applications, including:

* `Watcher`. A system for instructing your application to look for and log
  database commands and queries.
* `Replayer`. A system for taking a record of commands invoked by an application
  (as reported by `Watcher`) and replaying them with a newer version of Mongoid.
* `Analyzer`. A system for taking the output for a `Watcher`, and the output of
  a `Replayer`, and comparing the two, looking for instances where query shapes
  have changed (which may indicate where performance will be impacted after
  upgrading).


## `Watcher`

The `Watcher` system installs wrappers around many core Mongoid APIs, and will
then detect when those APIs are called. It will then allow the programmer to
log those calls, as well as any subsequent and related driver API calls.

This tool is intended to be used in conjunction with the `Replayer` and the
`Analyzer`.

To set up the watcher:

```ruby
require 'mongoid'
require 'mongoid/upgrade_helper'

# This MUST be called before any clients have been created.
Mongoid::UpgradeHelper::Watcher.initialize!

COMMAND_LOG = File.open('commands.log', 'a')
Mongoid::UpgradeHelper.on_action { |action| COMMAND_LOG.puts(action) }

# ...
```

At this point, CRUD operations on your models will be written to the log that
was configured, ready to be replayed by the `Replayer` and analyzed by the
`Analyzer`.


## `Replayer`

The `Replayer` system depends on the `Watcher`, and also installs wrappers
around some core Mongoid APIs. It is given the output of a previous `Watcher`
run, and is run in a separate (non-production) process, with a newer version
of Mongoid. It replays the commands from the `Watcher` log, and the resulting
commands are then logged to a new location (distinct from the original log).

This tool is intended to be used in conjunction with the `Watcher` and the
`Analyzer`.

To set up the replayer:

```ruby
require 'mongoid'
require 'mongoid/upgrade_helper'

# This MUST be called before any clients have been created.
Mongoid::UpgradeHelper::Replayer.setup!

COMMAND_LOG = File.open('commands-replayed.log', 'a')
Mongoid::UpgradeHelper.on_action { |action| COMMAND_LOG.puts(action) }

# ...

Mongoid::UpgradeHelper::Replayer.with_file('commands.log') do |replayer|
  replayer.replay!
end
```

Note that the replayer process must have access to the same models as the
watcher process, as unmodified as possible.


## `Analyzer`

Once you have both logs (from the `Watcher` and the `Replayer`), you can feed
them into an `Analyzer` and have it tell you the differences:

```ruby
require 'mongoid'
require 'mongoid/upgrade_helper'

analyzer = Mongoid::UpgradeHelper::Analyzer.new('commands.log',
                                                'commands-replayed.log')

puts "Differences:"
puts analyzer.differences
```
