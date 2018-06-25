defmodule ManagementCommandsProcessor do
  def process_command(%ReceiverMessage{payload: payload}) do
    decoded_message = payload |> Poison.decode!
    function = decoded_message["function"] |> String.to_atom
    args = decoded_message["args"]
    result = apply Service.Watcher, function, args
    result_string = result
    IO.puts "result: #{result_string}"
    reply_to = decoded_message["reply_to"]
    if reply_to do
      IO.puts "Going to reply to #{reply_to}"
      prefix = (if mention = decoded_message["mention"], do: mention <> " ", else: "")
      IO.puts "Prefix is #{prefix}"
      payload = "#{prefix}#{result_string}"
      IO.puts "Payload message is #{payload}"
      Service.Watcher.send_message(payload, reply_to)
    end
    result
  end

  def execute_command(command) do
    function = command["function"] |> String.to_atom
    args = command["args"]
    result = apply Service.Watcher, function, args
    result_string = result
    IO.puts "result: #{result_string}"
    reply_to = command["reply_to"]
    if reply_to do
      IO.puts "Going to reply to #{reply_to}"
      prefix = (if mention = command["mention"], do: mention <> " ", else: "")
      IO.puts "Prefix is #{prefix}"
      payload = "#{prefix}#{result_string}"
      IO.puts "Payload message is #{payload}"
      Service.Watcher.send_message(payload, reply_to)
    end
  end
end
