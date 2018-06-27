defmodule JobSupervisor do
  use DynamicSupervisor

  import Service.Watcher, only: [service_name_alias: 1]

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [:one_for_one], name: __MODULE__)
  end

  def start_child(service_name, module, function, args, interval, period \\ :infinity, spawn_on_call \\ false) do
    name_alias = service_name_alias(service_name)
    spec =
      %{
        id: name_alias,
        start:
          {
            TimerJob,
            :start_link,
            [
              module, function, args, interval, period, spawn_on_call,
              [name: name_alias],
              true
            ]
          },
        restart: :permanent
      }
    # spec = Supervisor.Spec.worker(
    #   TimerJob,
    #   [
    #     module, function, args, interval, period, spawn_on_call,
    #     [name: name_alias]
    #   ], [restart: :permanent])
    IO.puts "spec is: #{inspect spec}"
    spec = spec |> Supervisor.child_spec(id: name_alias)
    IO.puts "updated spec: #{inspect spec}"
    child = DynamicSupervisor.start_child(__MODULE__, spec)
    case child do
      {:ok, pid} ->
        pid |> TimerJob.run()
        IO.puts "Started #{service_name} [#{inspect pid}] job right off"
    end
    child
  end

  def init([strategy]) do
    IO.puts "Initializing the #{__MODULE__}, the strategy is #{strategy}"
    x = DynamicSupervisor.init(strategy: strategy)
    IO.puts "DynamicSupervisor.init(strategy: #{strategy}) returned #{inspect x}"
    x
  end

end
