defmodule Service.Watcher do
  use GenServer

  defstruct [:services]
  @moduledoc """
  Documentation for Service.Watcher.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Service.Watcher.hello
      :world

  """
  def hello do
    :world
  end

  def start_link(services \\ [], gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, [services], gen_server_options)
  end

  def start_watching(service_name, mode, watch_interval) do
    ok_state = mode |> Services.mode_to_service_state
    notify_destination = Application.get_env(:service_watcher_sup, :notify_destination, "")
    effective_watch_interval = watch_interval || Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)
    JobSupervisor.start_child(service_name, __MODULE__, :watch_service, [service_name, mode, ok_state, nil, notify_destination, effective_watch_interval, :infinity], effective_watch_interval, :infinity, false)
  end

  def watch_service(service_name, mode, expected_state, prev_state, notify_destination, watch_interval \\ 5000, expiration_period \\ :infinity) do
    interim_state = mode |> Services.mode_to_interim_state
    case service_name |> Services.get_service_state do
      ^expected_state ->
        unless !prev_state || prev_state == expected_state do
          send_message "Service *#{service_name}* is now *#{expected_state}*", notify_destination
        end
      ^interim_state ->
        if !prev_state || prev_state != interim_state do
          send_message "Service *#{service_name}* is now *#{ingify interim_state}*", notify_destination
        end
        # TODO: possible use update_interval_period here to adjust interval/period of a TimerJob
        # :timer.apply_after watch_interval, __MODULE__, :watch_service, [service_name, mode, expected_state, interim_state, notify_destination, watch_interval, (if expiration_period == :infinity || !prev_state || prev_state != interim_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)]
      other_state ->
        if !prev_state || prev_state != other_state do
          send_message "Service *#{service_name}* is now *#{ingify other_state}*", notify_destination
          action_verb = mode |> Services.mode_to_action_verb
          send_message "Trying to *#{action_verb}* service *#{service_name}*", notify_destination
          action = "#{action_verb}_service" |> String.to_atom
          res = apply Services, action, [service_name]
          send_message "*#{action}* exited with code *#{res}*", notify_destination
        end
        # TODO: possible use update_interval_period here to adjust interval/period of a TimerJob
        # :timer.apply_after watch_interval, __MODULE__, :watch_service, [service_name, mode, expected_state, other_state, notify_destination, watch_interval, (if expiration_period == :infinity || !prev_state || prev_state != other_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)]
    end
    # debug
    send_message "I'm watching *#{service_name}* to be *#{mode}*", notify_destination
  end

  def service_to_string(service) do
    case service do
      {service_name, mode} ->
        "Watching [#{service_name}] to be #{mode} every #{Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)} ms"
      {service_name, mode, interval} ->
        "Watching [#{service_name}] to be #{mode} every #{interval || Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)} ms"
    end
  end

  #API
  def get_services(server \\ __MODULE__) do
    server |> GenServer.call(:services)
  end

  def add_service(server \\ __MODULE__, service_name, mode, timeout \\ Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)) do
    server |> GenServer.cast({:add_service, service_name, mode, timeout})
  end

  def stop_watching(server \\ __MODULE__, service_name) do
    server |> GenServer.cast({:stop_watching, service_name})
  end

  #Callbacks
  def init([services]) do
    for service <- services do
      case service do
        {service_name, mode} ->
          start_watching service_name, mode, Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)
        {service_name, mode, interval} ->
          start_watching service_name, mode, interval || Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)
      end
    end
    {:ok, %Service.Watcher{services: services}}
  end

  def handle_call(:services, _from, %Service.Watcher{services: services} = state) do
    services_definition_string =
      for service <- services, into: "", do: service_to_string(service)
    {:reply, services_definition_string, state}
  end

  def handle_cast({:add_service, service_name, mode, timeout}, %Service.Watcher{services: services} = state) do
    start_watching service_name, mode, timeout
    {:noreply, %{state|services: [{service_name, mode, timeout}|services]}}
  end

  def handle_cast({:stop_watching, service_name}, %Service.Watcher{services: services} = state) do
    service_name |> stop_timer_job()
    {:noreply, %{state|services: services |> Enum.reject(&(&1 |> elem(0) == service_name))}}
  end

  # Helpers
  def ingify(str), do: unless str |> String.downcase |> String.ends_with?(["ing", "ed"]), do: (if ~r/[^p]{1}p$/ |> Regex.match?(str), do: str <> "p", else: str) <> "ing", else: str
  def send_message(message, destination) do
    bot_queue = Application.get_env(:service_watcher_sup, :bot_queue, "bot_queue")
    RabbitMQSender |> RabbitMQSender.send_message(bot_queue, "#{destination}::#{message}")
  end
  def service_name_alias(service_name) do
    {:via, Registry, {NamesRegistry, service_name}}
  end
  def update_interval_period(service_name, interval, period \\ nil) do
    service_name |> service_name_alias()
      |> TimerJob.update_state(%TimerJob{interval: interval, period: period})
  end
  def stop_timer_job(service_name) do
    service_name |> service_name_alias()
    |> Process.exit(:kill)
  end
end