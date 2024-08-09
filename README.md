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

_TODO_


## `Analyzer`

_TODO_
