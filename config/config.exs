# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :cipher,
  keyphrase: "testiekeyphraseforcipher",
  ivphrase: "testieivphraseforcipher",
  magic_token: "magictoken"

config :rabbitmq_sender,
  rabbit_options:
    [
      host: "localhost",
      username: "hunky",
      virtual_host: "/",
      password: "hunky"
    ]

comp_name = "ax" <> "stage" <> "0" <> "1"

config :service_watcher_sup,
  cwd: "",
  bot_queue: "bot_queue",
  notify_destination: ["dpyatkov", "zheleznov", "laputin"],
  default_watch_interval: 5000,
  scripts_folder: "C:/AX/BuildScripts",
  slack_sender_url: "http://#{comp_name}.mediasaturnrussia.ru:17000/api/slack_sender",
  # {"aspnet_state", "MOW04DEV014", ["dpyatkov"]}
  services: [{"AOS60$05", "MOW04DEV014", ["dpyatkov"]}, {"AOS60$06", "MOW04DEV014", "dpyatkov"}, {"AOS60$02", "MOW04DEV014", "dpyatkov"}, {"aspnet_state", "MOW04DEV014", ["dpyatkov"]}],
  proxy: "http://bluecoat.media-saturn.com:80",
  username: "pyatkov",
  computer_name: "MOW04APPAX02",
  # dont_watch_services: true,
  identity: :logistics,
  commands_poll_url: "http://#{comp_name}.mediasaturnrussia.ru:17000/api/slack_receiver",
  registration_url: "http://#{comp_name}.mediasaturnrussia.ru:17000/api/supervisor_registration"

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
