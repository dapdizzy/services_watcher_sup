defmodule Service.Def do
  defstruct [:service_name, :mode, :timeout, :state, :computer_name, :notify_destination]
  alias Service.Def

  defimpl String.Chars, for: __MODULE__ do
    def to_string(%Def{service_name: service_name, mode: mode, timeout: timeout, state: state, computer_name: computer_name, notify_destination: notify_destination}) do
      state_description = if (state_str = "#{state}") != "", do: " (*#{state_str}*)", else: ""
      "Watching service [*#{service_name}*] on [*#{computer_name}*] to be *#{mode}* every *#{timeout}* ms#{state_description}, notify destination: *#{inspect notify_destination}*"
    end
  end
end
