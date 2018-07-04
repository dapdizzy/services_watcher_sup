defmodule HTTPHelper do
  defstruct [:proxy, :username, :password]

  use GenServer

  # API

  def start_link(proxy, username, password) do
    GenServer.start_link __MODULE__, {proxy, username, password}, name: __MODULE__
  end

  def post(url, payload) do
    __MODULE__ |> GenServer.call({:post, url, payload})
  end

  def process_queued_messages() do
    __MODULE__ |> GenServer.cast(:process_queued_messages)
  end

  # Callbacks
  def init({proxy, username, password}) do
    # process_queued_messages()
    Helpers.sleep 2_000, true
    {:ok, %__MODULE__{proxy: proxy, username: username, password: password}}
  end

  def handle_call({:post, url, payload}, _from, %__MODULE__{proxy: proxy, username: username, password: password} = state) do
    response = Helpers.post url, payload, proxy, username, password
    # Helpers.sleep(100)
    {:reply, response, state}
  end

  def handle_cast(:process_queued_messages, state) do
    spawn_link(
    fn ->
      initial_value = MessageQueue.peek()
      initial_value |> Stream.unfold(fn :empty -> nil; value ->
        MessageQueue.dequeue() # Remove the value from the queue.
        {value, MessageQueue.peek()} # And obtain the next value.
      end) |> Stream.take_while(fn nil -> false; _ -> true end)
        |> Enum.reduce_while(:ok, fn value, status ->
          case status do
            :ok ->
              case value do
                {message, destination} ->
                  case Service.Watcher.send_message(message, destination, true) do # Skip the MessageQueue when we basically drain it.
                    :ok ->
                      IO.puts "Successfuly sent and dequeued"
                      {:cont, :ok}
                    :failed ->
                      IO.puts "An attempt to send the message faield, so stop the process of resending queued messages..."
                      {:halt, :failed}
                  end
                stuff ->
                  IO.puts "Weird stuff: #{inspect stuff}"
                  {:cont, :ok}
              end
            :failed ->
              IO.puts "Somehow a failed status from the previous step came, stop the process of resending queued messages..."
              {:halt, :failed}
          end
        end)
    end
    )
    {:noreply, state}
  end

  def do_process_queued_messages() do
    list = MessageQueue.list()
      |> Enum.reduce_while(:ok, fn value, status ->
        case status do
          :ok ->
            case value do
              {message, destination} ->
                case Service.Watcher.send_message(message, destination, true) do # Skip the MessageQueue when we basically drain it.
                  :ok ->
                    MessageQueue.dequeue()
                    IO.puts "Successfuly sent and dequeued"
                    {:cont, :ok}
                  :failed ->
                    IO.puts "An attempt to send the message faield, so stop the process of resending queued messages..."
                    {:halt, :failed}
                end
              stuff ->
                IO.puts "Weird stuff: #{inspect stuff}"
                {:cont, :ok}
            end
          :failed ->
            IO.puts "Somehow a failed status from the previous step came, stop the process of resending queued messages..."
            {:halt, :failed}
        end
      end)
  end
end
