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

  # Callbacks
  def init({proxy, username, password}) do
    {:ok, %__MODULE__{proxy: proxy, username: username, password: password}}
  end

  def handle_call({:post, url, payload}, _from, %__MODULE__{proxy: proxy, username: username, password: password} = state) do
    response = Helpers.post url, payload, proxy, username, password
    # :timer.sleep(100)
    {:reply, response, state}
  end
end
