# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Customize non-Elixir parts of the firmware.  See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.
config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Use shoehorn to start the main application. See the shoehorn
# docs for separating out critical OTP applications such as those
# involved with firmware updates.
config :shoehorn,
  init: [:nerves_runtime, :nerves_init_gadget],
  app: Mix.Project.config()[:app]

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.Project.config[:target]}.exs"
config :nerves_firmware_ssh,
  authorized_keys: [
    File.read!(Path.join(System.user_home!, ".ssh/id_rsa.pub"))
  ]

config :nerves_init_gadget,
  node_name: :gba_loader,
  node_host: :mdns_domain,
  mdns_domain: "gba.local",
  interface: "usb0",
  address_method: :dhcpd

if Mix.Project.config[:target] == "host" do
  config :gba_loader, GbaLoaderWeb.Endpoint,
    url: [host: "localhost"],
    secret_key_base: "UvGrOM15+EqhIlvMpVDIAdcm4oXSb4h5UG9+VvekNaqKhSQakKueTrWIDqGoNH+Y",
    render_errors: [view: GbaLoaderWeb.ErrorView, accepts: ~w(html json)],
    pubsub: [name: GbaLoader.PubSub,
             adapter: Phoenix.PubSub.PG2]

  # Configures Elixir's Logger
  config :logger, :console,
    format: "$time $metadata[$level] $message\n",
    metadata: [:user_id]

  config :gba_loader, GbaLoaderWeb.Endpoint,
    http: [port: 4000],
    debug_errors: true,
    code_reloader: true,
    check_origin: false,
    watchers: []

  # Watch static and templates for browser reloading.
  config :gba_loader, GbaLoaderWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/gba_loader_web/views/.*(ex)$},
      ~r{lib/gba_loader_web/templates/.*(eex)$}
    ]
  ]

  # Do not include metadata nor timestamps in development logs
  config :logger, :console, format: "[$level] $message\n"

  # Set a higher stacktrace during development. Avoid configuring such
  # in production as building large stacktraces may be expensive.
  config :phoenix, :stacktrace_depth, 20
else
  config :logger,
    backends: [RingLogger]

  config :gba_loader, GbaLoaderWeb.Endpoint,
    http: [port: 80],
    url: [host: "gba_loader.local", port: 80],
    secret_key_base: "9w9MI64d1L8mjw+tzTmS3qgJTJqYNGJ1dNfn4S/Zm6BbKAmo2vAyVW7CgfI3CpII",
    root: Path.dirname(__DIR__),
    server: true,
    render_errors: [accepts: ~w(html json)],
    pubsub: [name: GbaLoader.PubSub, adapter: Phoenix.PubSub.PG2]
end

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
