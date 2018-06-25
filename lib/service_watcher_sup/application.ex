defmodule Service.Watcher.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  import Supervisor.Spec

  use Application

  defp get_cwd do
    Application.get_env(:service_watcher_sup, :cwd) || File.cwd!()
  end

  defp complement_filename(filename) do
    get_cwd() |> Path.join(filename)
  end

  defp read_secure_password do
    "DimaMe1985!"
    # filename = "password" |> Cipher.encrypt() |> complement_filename()
    # encrypted =
    #   if filename |> File.exists? do
    #     filename |> File.read!
    #   else
    #     password_file_name = "password.txt" |> complement_filename()
    #     unless password_file_name |> File.exists? do
    #       raise "Encrypted password file does not exist and an open password (#{password_file_name}) does not exist as well"
    #     end
    #     open_password = password_file_name |> File.read!
    #     secure_pwd = open_password |> Cipher.encrypt
    #     filename |> File.write!(secure_pwd, [:write, :utf8])
    #     password_file_name |> File.rm! # Try to remove the open password file
    #     "password_accepted.info" |> File.open([:write, :utf8], fn _ -> end)
    #     secure_pwd
    #   end
    # password = encrypted |> Cipher.decrypt
  end

  def start(_type, _args) do
    services =
      unless Application.get_env(:service_watcher_sup, :dont_watch_services, false) do
        Application.get_env(:service_watcher_sup, :services, [])
        |> Enum.map(fn {name, computer_name, notify_destination} -> %Service.Def{service_name: name, mode: :on, timeout: 5_000, computer_name: computer_name, notify_destination: notify_destination} end)
      else
        []
      end
    identity = Application.get_env(:service_watcher_sup, :identity)
    unless identity, do: raise ":identity should be specified for :service_watcher_sup app in the config"
    # Handle the stuff with the secire password here...
    password = read_secure_password()
    Application.put_env(:service_watcher_sup, :password, password)
    username = Application.get_env(:service_watcher_sup, :username)
    proxy = Application.get_env(:service_watcher_sup, :proxy)
    uri = proxy |> URI.parse()
    proxy_w_cred = %{uri|host: "#{username}:#{password}@#{uri.host}"} |> URI.to_string() |> String.replace(["[", "]"], "")
    IO.puts "proxy_w_cred: #{proxy_w_cred}"
    System.put_env("http_proxy", proxy_w_cred)
    System.put_env("https_proxy", proxy_w_cred)
    rabbit_connection_options = Application.get_env(:rabbitmq_sender, :rabbit_options)
    # List all child processes to be supervised
    children = [
      # worker(RabbitMQSender, [[], [name: RabbitMQSender]]),
      worker(Registry, [[keys: :unique, name: NamesRegistry]], [name: NamesRegistry]),
      supervisor(JobSupervisor, []),
      worker(HTTPHelper, [proxy, username, password]),
      worker(Service.Watcher, [services, [name: Service.Watcher]]),
      # worker(RabbitMQReceiver, [rabbit_connection_options, "", ManagementCommandsProcessor, :process_command, true, [name: RabbitMQReceiver], [exchange: "supervisors_commands_exchange", exchange_type: :topic, binding_keys: ["commands", "commands.#{identity}"]]]),
      # worker(Poller, [], id: Poller),
      # worker(TimerJob, [Poller, :poll_for_commands, [], 500, :infinity, false, [name: PollJob]], id: PollerJob),
      # worker(RabbitMQSender, [rabbit_connection_options, [name: RabbitMQSender]])
      # Starts a worker by calling: Service.Watcher.Worker.start_link(arg)
      # {Service.Watcher.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Service.Watcher.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
