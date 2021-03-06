defmodule Helpers do
  def enrich_options(options, proxy, username, password) do
    [{:proxy, proxy}, {:proxy_auth, (if username && password, do: {username, password})}]
      |> Enum.reduce(options, fn {key, value}, acc -> acc |> enrich_option(key, value) end)
  end

  def enrich_option(options, key, value) do
    if value, do: options |> Keyword.put(key, value), else: options
  end

  defp build_headers() do
    [{"Content-Type", "application/json"}]
      # |> Helpers.enrich_options(proxy, username, password)
  end

  defp build_options(proxy, username, password) do
    [] |> enrich_options(proxy, username, password)
  end

  def post(url, payload, proxy, username, password) do
    headers = build_headers # proxy, username, password
    IO.puts "Headers: #{inspect headers}"
    options =
      if proxy && username do
        options = build_options proxy, username, password
        IO.puts "Options: #{inspect options}"
        options
      else
        []
      end
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.post! url, payload, headers, options
    body
  end

  def sleep(timout, for_real \\ false)

  def sleep(timeout, true) do
    :timer.sleep timeout
  end

  def sleep(_timeout, _) do
    nil
  end
end
