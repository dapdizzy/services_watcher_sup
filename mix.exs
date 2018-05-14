defmodule Service.Watcher.MixProject do
  use Mix.Project

  def project do
    [
      app: :service_watcher_sup,
      version: "0.1.4",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
       package: package(),
       name: "ServiceWatcher"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Service.Watcher.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpotion, "~> 3.1"},
      {:rabbitmq_sender, "~> 0.1.4"},
      {:timer_job, "~> 0.1.3"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:distillery, "~> 1.5", runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end

  defp description do
    """
    This is a GenServer-ish implementation of a Service watcher.
    A process that is designed to poll service state every given number of miliseconds and perform due actions in case it is not in designated state.
    The process is also capable of sending notifications to the configured recipient in Slack.
    """
  end

  defp package do
    [
      name: "service_watcher_sup",
      maintainers: ["Dmitry A. Pyatkov"],
      licenses: ["Apache 2.0"],
      files: ["lib", "mix.exs"],
      links: %{"HexDocs.pm" => "https://hexdocs.pm"}
    ]
  end
end
