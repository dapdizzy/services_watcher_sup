defmodule DelayManager do
  defstruct [:elapsed, :lower_bound, :short_step, :long_step]

  use GenServer

  # API
  def start_link(lower_bound, short_step, long_step) do
    __MODULE__ |> GenServer.start_link({lower_bound, short_step, long_step}, name: __MODULE__)
  end

  def delay() do
    __MODULE__ |> GenServer.call(:delay)
  end

  def reset() do
    __MODULE__ |> GenServer.cast(:reset)
  end

  # Callbacks
  def init({lower_bound, short_step, long_step}) do
    {:ok, %__MODULE__{elapsed: 0, lower_bound: lower_bound, short_step: short_step, long_step: long_step}}
  end

  def handle_call(:delay, _from, %__MODULE__{elapsed: elapsed, lower_bound: lower_bound, short_step: short_step, long_step: long_step} = state) do
    if elapsed < lower_bound do
      {:reply, short_step, %{state|elapsed: elapsed + short_step}}
    else
      {:reply, long_step, %{state|elapsed: elapsed + long_step}}
    end
  end

  def handle_cast(:reset, state) do
    {:noreply, %{state|elapsed: 0}}
  end
end
