defmodule PollerMonitor do
  use GenServer

  defstruct [:poller_pid, :poller_ref, :timer_job_pid, :timer_job_ref, :restart_task_ref, :delay, :retry_count, :retry_num, :delay_factor]

  # API
  def start_link(delay, retry_count, delay_factor \\ 1) do
    __MODULE__ |> GenServer.start_link({delay, retry_count, delay_factor}, name: __MODULE__)
  end

  # Callbacks
  def init({delay, retry_count, delay_factor}) do
    IO.puts "PollerMonitor starting..."
    Helpers.sleep 3_000
    {poller_pid, timer_job_pid} = start_processes()
    poller_ref = poller_pid |> Process.monitor()
    timer_job_ref = timer_job_pid |> Process.monitor()
    {:ok, %__MODULE__{poller_pid: poller_pid, poller_ref: poller_ref, timer_job_pid: timer_job_pid, timer_job_ref: timer_job_ref, delay: delay, retry_count: retry_count, delay_factor: delay_factor, retry_num: 0}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason} = msg, %__MODULE__{poller_pid: poller_pid, poller_ref: poller_ref, timer_job_pid: timer_job_pid, timer_job_ref: timer_job_ref, restart_task_ref: restart_task_ref, retry_num: retry_num, retry_count: retry_count, delay: delay, delay_factor: delay_factor} = state) do
    IO.puts "Something went down..."
    IO.puts "#{inspect msg}"
    Helpers.sleep 500
    {upd_restart_task_ref, new_retry_num} =
      case ref do
        ^poller_ref ->
          unless restart_task_ref do
            IO.puts "Restarting caused by poller"
            Helpers.sleep 1_500
            %Task{ref: new_restart_task_ref} = Task.Supervisor |> Task.Supervisor.async_nolink(fn -> retry_loop() end)
            IO.puts "Obtained a restart task reference #{inspect restart_task_ref}"
            {new_restart_task_ref, 1}
          else
            {restart_task_ref, retry_num}
          end
        ^timer_job_ref ->
          unless restart_task_ref do
            IO.puts "Restarting caused by timer_job"
            Helpers.sleep 1_500
            %Task{ref: new_restart_task_ref} = Task.Supervisor |> Task.Supervisor.async_nolink(fn -> retry_loop() end)
            IO.puts "Obtained a restart task reference #{inspect restart_task_ref}"
            {new_restart_task_ref, 1}
          else
            {restart_task_ref, retry_num}
          end
        ^restart_task_ref ->
          case reason do
            :normal ->
              {nil, 0}
            :retry_failure ->
              exit(:shutdown)
            _ ->
            IO.puts "Restart task failed...Starting a new one right away..."
            Helpers.sleep 1_500
            %Task{ref: new_restart_task_ref} = Task.Supervisor |> Task.Supervisor.async_nolink(fn -> retry_loop() end)
            {new_restart_task_ref, retry_num + 1}
          end
        _ ->
          IO.puts "Unknown reference...do nothing..."
          Helpers.sleep 1_500
          {nil, 0}
      end
    {:noreply, %{state|restart_task_ref: upd_restart_task_ref, retry_num: new_retry_num}}
  end

  def handle_info({ref, result}, %__MODULE__{poller_pid: poller_pid, poller_ref: poller_ref, timer_job_pid: timer_job_pid, timer_job_ref: timer_job_ref, restart_task_ref: restart_task_ref, retry_num: retry_num} = state) do
    x =
      case ref do
        ^restart_task_ref ->
          IO.puts "Processes have been successfuly restarted and here is the result: #{inspect result}"
          result
        _ -> nil
      end
    {{new_poller_pid, new_timer_job_pid}, succeeded} =
      case x do
        {_new_poller_pid, _new_timer_job_pid} ->
          {x, true}
        _ ->
          {{poller_pid, timer_job_pid}, false}
      end
    {upd_poller_ref, upd_timer_job_ref} =
      if succeeded do
        new_poller_ref = new_poller_pid |> Process.monitor()
        new_timer_job_ref = new_timer_job_pid |> Process.monitor()
        {new_poller_ref, new_timer_job_ref}
      else
        {poller_ref, timer_job_ref}
      end
    {:noreply, %{state|poller_pid: new_poller_pid, poller_ref: upd_poller_ref, timer_job_pid: new_timer_job_pid, timer_job_ref: upd_timer_job_ref, restart_task_ref: nil, retry_num: (if succeeded, do: 0, else: retry_num)}}
  end

  def start_processes do
    IO.puts "Starting the processes..."
    Helpers.sleep 1_000
    {:ok, poller_pid} = Poller.start()
    IO.puts "Poller initialized: #{inspect poller_pid}"
    Helpers.sleep 200
    {:ok, timer_job_pid} = TimerJob.start Poller, :poll_for_commands, [], 500, :infinity, false, [name: PollJob], true
    IO.puts "TimerJob initialized: #{inspect timer_job_pid}"
    Helpers.sleep 200
    {poller_pid, timer_job_pid}
  end

  def retry_start_processes(retry_num, retry_count, delay, delay_factor \\ 1) do
    IO.puts "Starting the retry_start_processes function with the following parameters"
    IO.puts "retry_num: #{retry_num}, retry_count: #{retry_count}, delay: #{delay}, delay_factor: #{delay_factor}"
    Helpers.sleep 1_500
    # if retry_num > retry_count do
    #   # raise "Exceeded #{retry_count} attempts!"
    #   exit(:retry_failure)
    # end
    unless retry_count > 0 && delay_factor > 0 && delay > 0 do
      raise "retry_count should be greater than zero and it is #{retry_count}\ndelay_factor should be greater than zero and it is #{delay_factor}\ndelay should be greater than zero and it is #{delay}"
    end
    IO.puts "Retrying to start processes..."
    result =
      retry_num..retry_count
        |> Enum.reduce_while(nil, fn retry_num, _acc ->
          sleep_time = DelayManager.delay() # round(delay * :math.pow(delay_factor, retry_num - 1))
          IO.puts "Retry #{retry_num}. Going to sleep for #{sleep_time} ms..."
          Helpers.sleep sleep_time, true
          IO.puts "GO!"
          x =
            try do
              start_processes()
            rescue
              _ -> nil
            end
          if x, do: {:halt, x}, else: {:cont, nil}
        end)
    result
  end

  def retry_loop() do
    sleep_time = DelayManager.delay()
    IO.puts "Going to sleep for #{sleep_time} ms"
    Helpers.sleep sleep_time, true
    IO.puts "Slept for #{sleep_time} ms"
    x =
      try do
        start_processes()
      rescue
        _ -> nil
      end
    if x do
      DelayManager.reset()
      x
    else
      retry_loop()
    end
  end

end
