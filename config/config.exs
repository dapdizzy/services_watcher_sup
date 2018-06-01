# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :rabbitmq_sender,
  rabbit_options:
    [
      host: "localhost",
      username: "hunky",
      virtual_host: "/",
      password: "hunky"
    ]

config :service_watcher_sup,
  bot_queue: "bot_queue",
  notify_destination: "dpyatkov",
  default_watch_interval: 5000,
  scripts_folder: "C:/AX/BuildScripts",
  slack_sender_url: "http://dummy.mediasaturnrussia.ru:17000/api/slack_sender",
  services: [{"AOS60$05", "MOW04DEV014"}, {"AOS60$06", "MOW04DEV014"}, {"aspnet_state", "MOW04DEV014"}, {"AOS60$02", "MOW04DEV014"}],
  proxy: "http://bunny.media-saturn.com:80",
  username: "pyatkov",
  password: "mecko!",
  computer_name: "zeko"

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :service_watcher_sup, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:service_watcher_sup, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
