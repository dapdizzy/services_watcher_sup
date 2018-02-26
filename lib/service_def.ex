defmodule Service.Def do
  defstruct [:service_name, :mode, :timeout, :state]
  alias Service.Def

  defimpl String.Chars, for: __MODULE__ do
    def to_string(%Def{service_name: service_name, mode: mode, timeout: timeout, state: state}) do
      "Watching service [#{service_name}] to be #{mode} every #{timeout} ms (#{state})"
    end
  end
end
