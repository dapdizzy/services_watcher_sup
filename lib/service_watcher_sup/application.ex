defmodule Service.Watcher.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  import Supervisor.Spec

  use Application

  def start(_type, _args) do
    services = Application.get_env(:service_watcher_sup, :services, [])
      |> Enum.map(fn {name, computer_name} -> %Service.Def{service_name: name, mode: :on, timeout: 5_000, computer_name: computer_name} end)
    # List all child processes to be supervised
    children = [
      # worker(RabbitMQSender, [[], [name: RabbitMQSender]]),
      worker(Registry, [[keys: :unique, name: NamesRegistry]], [name: NamesRegistry]),
      supervisor(JobSupervisor, []),
      worker(Service.Watcher, [services, [name: Service.Watcher]])
      # Starts a worker by calling: Service.Watcher.Worker.start_link(arg)
      # {Service.Watcher.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Service.Watcher.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
