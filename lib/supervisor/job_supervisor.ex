defmodule JobSupervisor do
  use DynamicSupervisor

  import Service.Watcher, only: [service_name_alias: 1]

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [:one_for_one], name: __MODULE__)
  end

  def start_child(service_name, module, function, args, interval, period \\ :infinity, spawn_on_call \\ false) do
    spec = Supervisor.Spec.worker(
      TimerJob,
      [
        module, function, args, interval, period, spawn_on_call,
        [name: service_name_alias(service_name)]
      ], [restart: :transient])
    child = DynamicSupervisor.start_child(__MODULE__, spec)
    case child do
      {:ok, pid} ->
        pid |> TimerJob.run()
        IO.puts "Started #{service_name} [#{inspect pid}] job right off"
    end
    child
  end

  def init([strategy]) do
    DynamicSupervisor.init(strategy: strategy)
  end

end
