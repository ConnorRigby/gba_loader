defmodule GbaLoader.MixProject do
  use Mix.Project

  @target System.get_env("MIX_TARGET") || "host"

  def project do
    [
      app: :gba_loader,
      version: "0.1.0",
      elixir: "~> 1.4",
      target: @target,
      archives: [nerves_bootstrap: "~> 1.0-rc"],
      deps_path: "deps/#{@target}",
      build_path: "_build/#{@target}",
      lockfile: "mix.lock.#{@target}",
      start_permanent: Mix.env() == :prod,
      aliases: [loadconfig: [&bootstrap/1]],
      compilers: [:elixir_make, :phoenix, :gettext] ++ Mix.compilers,
      make_clean: ["clean"],
      make_env: make_env(),
      deps: deps()
    ]
  end

  defp make_env() do
    case System.get_env("ERL_EI_INCLUDE_DIR") do
      nil ->
        %{
          "ERL_EI_INCLUDE_DIR" => "#{:code.root_dir()}/usr/include",
          "ERL_EI_LIBDIR" => "#{:code.root_dir()}/usr/lib"
        }
      _ ->
        %{}
    end
  end

  # Starting nerves_bootstrap adds the required aliases to Mix.Project.config()
  # Aliases are only added if MIX_TARGET is set.
  def bootstrap(args) do
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {GbaLoader.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nerves, "~> 1.3", runtime: false},
      {:elixir_make, "~> 0.4", runtime: false},
      {:shoehorn, "~> 0.4"},
      {:elixir_ale, "~> 1.0"},
      {:phoenix, "~> 1.3.2"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_html, "~> 2.10"},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"}
    ] ++ deps(@target)
  end

  # Specify target specific dependencies
  defp deps("host"), do: [
    {:phoenix_live_reload, "~> 1.0", only: :dev},
  ]

  defp deps(target) do
    [
      {:nerves_runtime, "~> 0.8"},
      {:nerves_init_gadget, "~> 0.5"},
    ] ++ system(target)
  end

  defp system("rpi0"), do: [{:nerves_system_rpi0, "~> 1.4.0", runtime: false}]
  defp system(target), do: Mix.raise("Unknown MIX_TARGET: #{target}")
end
