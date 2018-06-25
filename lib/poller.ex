defmodule Poller do
  defstruct [:url, :receiver, :proxy, :username, :password, :topics]

  use GenServer

  # API

  def start_link() do
    url = Application.get_env(:service_watcher_sup, :commands_poll_url)
    identity = Service.Watcher.identity()
    receiver = "#{identity}"
    GenServer.start_link(__MODULE__, {url, receiver}, name: __MODULE__)
  end

  def poll_for_commands do
    __MODULE__ |> GenServer.call(:poll_for_commands)
  end

  # Callbacks
  def init({url, receiver}) do
    proxy = Application.get_env(:service_watcher_sup, :proxy, nil)
    username = Application.get_env(:service_watcher_sup, :username, nil)
    password = Application.get_env(:service_watcher_sup, :password, nil)
    registration_url = Application.get_env(:service_watcher_sup, :registration_url)
    identity = Service.Watcher.identity()
    topics = ["commands", "commands.#{identity}"]
    payload = %{identity: identity, topics: topics} |> Poison.encode!
    registration_result = HTTPHelper.post registration_url, payload # , proxy, username, password
    IO.puts "Registration result: #{inspect registration_result}"
    {:ok, %__MODULE__{url: url, receiver: receiver, proxy: proxy, username: username, password: password, topics: topics}}
  end

  def handle_call(:poll_for_commands, _from, %__MODULE__{url: url, receiver: receiver, proxy: proxy, username: username, password: password, topics: topics} = state) do
    payload = %{identity: receiver, topics: topics} |> Poison.encode!
    commands_raw = HTTPHelper.post url, payload #, proxy, username, password
    IO.puts "Raw commands: #{inspect commands_raw}"
    commands = commands_raw |> Poison.decode!
    IO.puts "Commands: #{inspect commands}"
    command_messages = commands["messages"]
    IO.puts "Command messages: #{inspect command_messages}"
    command_messages |> Enum.each(fn command -> command |> Poison.decode! |> ManagementCommandsProcessor.execute_command() end)
    {:reply, commands, state}
  end

  defp build_headers(proxy, username, password) do
    [{"Content-Type", "application/json"}]
      |> Helpers.enrich_options(proxy, username, password)
  end

  defp post(url, payload, proxy, username, password) do
    headers = build_headers proxy, username, password
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.post! url, payload, headers
    body
  end
end
