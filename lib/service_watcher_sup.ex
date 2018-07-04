defmodule Service.Watcher do
  use GenServer

  alias Service.Def

  import Helpers

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

  def start_watching(service_name, computer_name, mode, watch_interval, notify_destination) do
    ok_state = mode |> Services.mode_to_service_state
    # notify_destination = Application.get_env(:service_watcher_sup, :notify_destination, "")
    effective_watch_interval = watch_interval || Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)
    JobSupervisor.start_child(service_name |> job_name(computer_name), __MODULE__, :watch_service, [service_name, computer_name, mode, ok_state, nil, notify_destination, effective_watch_interval, :infinity], effective_watch_interval, :infinity, false)
    # Helpers.sleep(100) # Sleep some 100ms to give the processes some temporal space inbetween
  end

  def watch_service(service_name, computer_name, mode, expected_state, prev_state, notify_destination, watch_interval \\ 5000, expiration_period \\ :infinity) do
    interim_state = mode |> Services.mode_to_interim_state
    service_state = service_name |> Services.get_service_state(computer_name)
    IO.puts "Service state is: #{service_state}"
    case service_state do
      ^expected_state ->
        IO.puts "Expected state"
        unless !prev_state || prev_state == expected_state do
          send_message "Service *#{service_name}* on *#{computer_name}* is now *#{expected_state}*", notify_destination
        end
        # Update args (prev_status in particular) to maintain proper status change handling.
        service_name |> job_name(computer_name) |> update_timer_state(
        %TimerJob
        {
          args:
            [
              service_name,
              computer_name,
              mode,
              expected_state,
              expected_state,
              notify_destination,
              watch_interval,
              (if expiration_period == :infinity || !prev_state || prev_state != interim_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)
            ]
        })
      ^interim_state ->
        IO.puts "Interim state"
        if !prev_state || prev_state != interim_state do
          send_message "Service *#{service_name}* on *#{computer_name}* is now *#{ingify interim_state}*", notify_destination
        end
        # TODO: possible use update_interval_period here to adjust interval/period of a TimerJob
        # Update args list to allow proper handling of status changes (we need to track prev_status and stuff).
        service_name |> job_name(computer_name) |> update_timer_state(
        %TimerJob
        {
          args:
            [
              service_name,
              computer_name,
              mode,
              expected_state,
              interim_state,
              notify_destination,
              watch_interval,
              (if expiration_period == :infinity || !prev_state || prev_state != interim_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)
            ]
        })
        # :timer.apply_after watch_interval, __MODULE__, :watch_service, [service_name, mode, expected_state, interim_state, notify_destination, watch_interval, (if expiration_period == :infinity || !prev_state || prev_state != interim_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)]
      other_state ->
        IO.puts "Other state"
        # if !prev_state || prev_state != other_state do
        #
        # end
        # It seems the watcher should always try to take action on a service that is in this "other state" as once the action is takes and in effect, the service should eitehr turn to "expected status" or to "interim status" otherwise we should constantly try to take action every other iteration.
        send_message "Service *#{service_name}* on *#{computer_name}* is now *#{ingify other_state}*", notify_destination
        action_verb = mode |> Services.mode_to_action_verb
        send_message "Trying to *#{action_verb}* service *#{service_name}* on *#{computer_name}*", notify_destination
        action = "#{action_verb}_service" |> String.to_atom
        res = apply Services, action, [service_name, computer_name]
        send_message "*#{action}* exited with code *#{res}*", notify_destination
        # TODO: possible use update_interval_period here to adjust interval/period of a TimerJob
        # :timer.apply_after watch_interval, __MODULE__, :watch_service, [service_name, mode, expected_state, other_state, notify_destination, watch_interval, (if expiration_period == :infinity || !prev_state || prev_state != other_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)]
        # Update args in order to maintain proper prev_status to handle status changes gracefuly.
        service_name |> job_name(computer_name) |> update_timer_state(
        %TimerJob
        {
          args:
            [
              service_name,
              computer_name,
              mode,
              expected_state,
              other_state,
              notify_destination,
              watch_interval,
              (if expiration_period == :infinity || !prev_state || prev_state != other_state, do: 5 * 60 * 1000, else: expiration_period - watch_interval)
            ]
        })
    end
    # debug
    if Application.get_env(:service_watcher_sup, :debug, false) do
      send_message "I'm watching *#{service_name}* on *#{computer_name}* to be *#{mode}*", notify_destination
    end
  end

  def service_to_string(%Def{service_name: service_name, mode: mode, timeout: interval, computer_name: computer_name}) do
    "Watching [#{service_name}] on *#{computer_name}* to be #{mode} every #{interval || Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)} ms"
    # case service do
    #   {service_name, mode} ->
    #     "Watching [#{service_name}] to be #{mode} every #{Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)} ms"
    #   {service_name, mode, interval} ->
    #     "Watching [#{service_name}] to be #{mode} every #{interval || Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)} ms"
    # end
  end

  #API
  def get_services(server \\ __MODULE__, with_markup \\ false) do
    server |> GenServer.call(:services)
  end

  def get_services_def(server \\ __MODULE__) do
    server |> GenServer.call(:services_def)
  end

  def add_service(server \\ __MODULE__, service_name, computer_name, mode, timeout \\ Application.get_env(:service_watcher_sup, :default_watch_interval, 5000), notify_destination \\ Application.get_env(:service_watcher_sup, :notify_destination)) do
    server |> GenServer.cast({:add_service, service_name, computer_name, mode, timeout, notify_destination})
  end

  def stop_watching(server \\ __MODULE__, service_name, computer_name) do
    server |> GenServer.cast({:stop_watching, service_name, computer_name})
  end

  def pause(server \\ __MODULE__, service_name, computer_name) do
    server |> GenServer.cast({:pause, service_name, computer_name})
  end

  def resume(server \\ __MODULE__, service_name, computer_name) do
    server |> GenServer.cast({:resume, service_name, computer_name})
  end

  def pause_all(server \\ __MODULE__) do
    server |> GenServer.cast(:pause_all)
  end

  def resume_all(server \\ __MODULE__) do
    server |> GenServer.cast(:resume_all)
  end

  #Callbacks
  def init([services]) do
    for %Def{service_name: service_name, mode: mode, timeout: interval, computer_name: computer_name, notify_destination: notify_destination} <- services do
      start_watching service_name, computer_name, mode, interval || Application.get_env(:service_watcher_sup, :default_watch_interval, 5000), notify_destination
      # case service do
      #   {service_name, mode} ->
      #     start_watching service_name, mode, Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)
      #   {service_name, mode, interval} ->
      #     start_watching service_name, mode, interval || Application.get_env(:service_watcher_sup, :default_watch_interval, 5000)
      # end
    end
    # Send a deferred register command to the "supervisor_man_queue" queue.
    command = %{command: "register", args: %{identity: identity()}} |> Poison.encode!
    # :timer.apply_after 3_000, RabbitMQSender, :send_message, [RabbitMQSender, "supervisor_man_queue", command]
    {:ok, %Service.Watcher{services: services}}
  end

  def handle_call(:services, _from, %Service.Watcher{services: services} = state) do
    services_definition_string =
      (for service <- services, do: to_string(service)) #service_to_string(service)
        |> Enum.join("\r\n")
    {:reply, services_definition_string, state}
  end

  def handle_call(:services_def, _from, %Service.Watcher{services: services} = state) do
    {:reply, services, state}
  end

  def handle_cast({:add_service, service_name, computer_name, mode, timeout, notify_destination}, %Service.Watcher{services: services} = state) do
    start_watching service_name, computer_name, to_atom_mode(mode), timeout, notify_destination
    {:noreply, %{state|services: [%Def{service_name: service_name, mode: mode, timeout: timeout, state: :active, computer_name: computer_name, notify_destination: notify_destination}|services]}}
  end

  def handle_cast({:stop_watching, service_name, computer_name}, %Service.Watcher{services: services} = state) do
    service_name |> job_name(computer_name) |> stop_timer_job()
    {:noreply, %{state|services: services |> Enum.reject(fn %Def{service_name: ^service_name, computer_name: ^computer_name} -> true; _ -> false end)}}
  end

  def handle_cast({:pause, service_name, computer_name}, %Service.Watcher{services: services} = state) do
    service_name |> job_name(computer_name) |> pause_timer_job()
    {:noreply, %{state|services: services |> Enum.map(
      fn
        %Def{service_name: ^service_name, computer_name: ^computer_name} = service ->
          %{service|state: :inactive}
        ;
        service -> service
      end
    )}}
  end

  def handle_cast({:resume, service_name, computer_name}, %Service.Watcher{services: services} = state) do
    service_name |> job_name(computer_name) |> resume_timer_job()
    {:noreply, %{state|services: services |> Enum.map(
      fn
        %Def{service_name: ^service_name, computer_name: ^computer_name} = service ->
          %{service|state: :active}
        ;
        service ->
          service
      end
    )}}
  end

  def handle_cast(:pause_all, %Service.Watcher{services: services} = state) do
    upd_services =
      for %Def{service_name: service_name, computer_name: computer_name} = service <- services do
        service_name |> job_name(computer_name) |> pause_timer_job()
        %{service|state: :inactive}
      end
    {:noreply, %{state|services: upd_services}}
  end

  def handle_cast(:resume_all, %Service.Watcher{services: services} = state) do
    upd_services =
      for %Def{service_name: service_name, computer_name: computer_name} = service <- services do
        service_name |> job_name(computer_name) |> resume_timer_job()
        %{service|state: :active}
      end
    {:noreply, %{state|services: upd_services}}
  end

  # Helpers
  def ingify(nil), do: nil
  def ingify(""), do: ""
  def ingify(str), do: unless str |> String.downcase |> String.ends_with?(["ing", "ed"]), do: (if ~r/[^p]{1}p$/ |> Regex.match?(str), do: str <> "p", else: str) <> "ing", else: str
  def send_message(message, [_h|_t] = destinations) do
    destinations |> Enum.reduce(:ok, fn destination, status ->
      case status do
        :ok ->
          send_message(message, destination)
        :failed ->
          MessageQueue.enqueue({message, destination}) #Only enqueue the message in case a previous call to send_message resulted in a :failure
          IO.puts "Enqueued the message #{message} to #{destination}"
          IO.puts "Will not try to send the message as the previous call resulted in a failure"
          Helpers.sleep 1_000
          :failed
      end
    end)
    # # In case of multiple destinations, enqueue the messages first
    # destinations |> Enum.each(fn destination ->
    #   MessageQueue.enqueue({message, destination})
    # end)
    # all_good =
    #   destinations |> Enum.map(fn destination ->
    #     send_message(message, destination, true)
    #   end) |> Enum.all?(&(&1 === :ok))
    # # Then dequeue them in case send succeded
    # if all_good do
    #   destinations |> Enum.each(fn _destination ->
    #     # Worth noting that there could be issues due to a race condition, as we may dequeue an entry added by some other process.
    #     # So we better have a queue per calling process (which should be the TimerJob process watching the particular service) and enqueue and dequeue considering the calling process slice.
    #     MessageQueue.dequeue()
    #   end)
    # end
  end
  def send_message(message, destination, skip_queue \\ false) do
    unless skip_queue do
      # Drain the queue first
      HTTPHelper.do_process_queued_messages()
      MessageQueue.enqueue({message, destination})
      IO.puts "Message #{message} to #{destination} was queueed"
      # Helpers.sleep 1_000
    end
    slack_sender_url = Application.get_env(:service_watcher_sup, :slack_sender_url)
    unless slack_sender_url, do: raise "slack_sender_url is not configured for service_watcher_sup"
    proxy = Application.get_env(:service_watcher_sup, :proxy, nil)
    username = Application.get_env(:service_watcher_sup, :username, nil)
    password = Application.get_env(:service_watcher_sup, :password, nil)
    # IO.puts "Going to submit request with the following options:"
    # IO.puts "proxy: #{proxy}"
    # IO.puts "username: #{username}"
    # IO.puts "password: #{password}"
    headers = [{"Content-Type", "application/json"}]
      |> enrich_options(proxy, username, password)
    IO.puts "Headers before slack_sender call are: #{inspect headers}"
    payload = %{message: "#{destination}::#{message}"} |> Poison.encode!
      # ~s|{"message": "#{destination}::#{message}"}|
    IO.puts "Payload is #{payload}"
    {status, result} =
      try do
        r = HTTPHelper.post slack_sender_url, payload #, proxy, username, password
        unless skip_queue do
          MessageQueue.dequeue() # Dequeue the recently queued message as it must have been successfuly sent to the queue (as we think here).
          IO.puts "Message has been dequeued"
        end
        {:ok, r}
      rescue
        _ ->
          Helpers.sleep 1_000
          IO.puts "Rescured raised during a call to send_message"
          IO.puts "Message #{message} to #{destination} will not be dequeued due to a failure"
          Helpers.sleep 1_000
          {:failed, "An error was raised during a call to HTTPHelper.post"}
      catch
        :exit, _ ->
          Helpers.sleep 1_000
          IO.puts "Rescured exit during a call to send_message"
          IO.puts "Message #{message} to #{destination} will not be dequeued due to a failure"
          Helpers.sleep 1_000
          {:failed, "An error was raised during a call to HTTPHelper.post"}
      end

      # HTTPoison.post!(
      #   slack_sender_url,
      #   payload,
      #   [{"Content-Type", "application/json"}]
      #     |> enrich_options(proxy, username, password)
      #   )
    IO.puts "HTTPHelper.post exited with status: #{status}, result is: #{inspect result}"
    Helpers.sleep 1_500
    # HTTPotion.post! slack_sender_url,
    #   body: ~s|{"message": "#{destination}::#{message}"}|,
    #   headers: [{"Content-Type", "application/json"}]
    # bot_queue = Application.get_env(:service_watcher_sup, :bot_queue, "bot_queue")
    # RabbitMQSender |> RabbitMQSender.send_message(bot_queue, "#{destination}::#{message}")
    status
  end
  def service_name_alias(service_name) do
    {:via, Registry, {NamesRegistry, service_name}}
  end
  def update_timer_state(service_name, new_state = %TimerJob{}) do
    service_name |> service_name_alias()
      |> TimerJob.update_state(new_state)
  end
  def update_interval_period(service_name, interval, period \\ nil) do
    service_name |> service_name_alias()
      |> TimerJob.update_state(%TimerJob{interval: interval, period: period})
  end
  def stop_timer_job(service_name) do
    service_name |> service_name_alias()
      |> GenServer.stop()
  end
  def pause_timer_job(service_name) do
    service_name |> service_name_alias()
      |> TimerJob.stop()
  end
  def resume_timer_job(service_name) do
    service_name |> service_name_alias()
      |> TimerJob.run()
  end
  def job_name(service_name, computer_name) do
    "#{service_name}_on_#{computer_name}"
  end

  defp to_atom_mode(mode) when mode |> is_binary() do
    mode |> String.to_atom()
  end

  defp to_atom_mode(mode) when mode |> is_atom() do
    mode
  end

  def identity do
    Application.get_env(:service_watcher_sup, :identity)
  end

  def ident do
    identity = identity()
    watching_services = unless (services = get_services()) != "", do: "[*no services*]", else: services
    "Supervisor identity *#{identity}*, watching services: #{watching_services}"
  end
end
