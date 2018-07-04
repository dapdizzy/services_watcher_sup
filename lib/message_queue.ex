defmodule MessageQueue do
  defstruct [:queue]

  use GenServer

  # API
  def start_link do
    __MODULE__ |> GenServer.start_link(nil, name: __MODULE__)
  end

  def enqueue(value, sync \\ false) do
    if sync do
      __MODULE__ |> GenServer.call({:enqueue, value})
    else
      __MODULE__ |> GenServer.cast({:enqueue, value})
    end
  end

  def dequeue() do
    __MODULE__ |> GenServer.call(:dequeue)
  end

  def peek() do
    __MODULE__ |> GenServer.call(:peek)
  end

  def list() do
    __MODULE__ |> GenServer.call(:list)
  end

  # Callbacks
  def init(nil) do
    queue = :queue.new()
    IO.puts "New queue: #{inspect queue}"
    Helpers.sleep 2_000
    {:ok, %__MODULE__{queue: queue}}
  end

  def handle_cast({:enqueue, value}, %__MODULE__{queue: queue} = state) do
    {:noreply, %{state|queue: value |> :queue.in(queue)}}
  end

  def handle_call({:enqueue, value}, _from, %__MODULE__{queue: queue} = state) do
    {:reply, :ok, %{state|queue: value |> :queue.in(queue)}}
  end

  def handle_call(:dequeue, _from, %__MODULE__{queue: queue} = state) do
    {value, queue} = do_dequeue(queue)
    {:reply, value, %{state|queue: queue}}
  end

  def handle_call(:peek, _from, %__MODULE__{queue: queue} = state) do
    {value, _upd_queue} = do_dequeue(queue)
    {:reply, value, state}
  end

  def handle_call(:list, _from, %__MODULE__{queue: queue} = state) do
    list =
      queue |> Stream.unfold(fn q ->
        case do_dequeue(q) do
          {:empty, _} -> nil
          {_value, _rem_q} = res -> res
        end
      end)
      |> Enum.to_list()
    {:reply, list, state}
  end

  defp do_dequeue(queue) do
    case :queue.out(queue) do
      {{:value, head}, new_queue} -> {head, new_queue}
      _ -> {:empty, queue}
    end
  end
end
