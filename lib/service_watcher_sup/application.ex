defmodule Service.Watcher.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  import Supervisor.Spec

  use Application

  defp read_secure_password do
    filename = "password" |> Cipher.encrypt
    encrypted =
      if filename |> File.exists? do
        filename |> File.read!
      else
        password_file_name = "password.txt"
        unless password_file_name |> File.exists? do
          raise "Encrypted password file does not exist and an open password (#{password_file_name}) does not exist as well"
        end
        open_password = password_file_name |> File.read!
        secure_pwd = open_password |> Cipher.encrypt
        filename |> File.write!(secure_pwd, [:write, :utf8])
        password_file_name |> File.rm! # Try to remove the open password file
        "password_accepted.info" |> File.open([:write, :utf8], fn _ -> end)
        secure_pwd
      end
    password = encrypted |> Cipher.decrypt
  end

  def start(_type, _args) do
    services = Application.get_env(:service_watcher_sup, :services, [])
      |> Enum.map(fn {name, computer_name} -> %Service.Def{service_name: name, mode: :on, timeout: 5_000, computer_name: computer_name} end)
    # Handle the stuff with the secire password here...
    password = read_secure_password()
    Application.put_env(:service_watcher_sup, :password, password)
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
