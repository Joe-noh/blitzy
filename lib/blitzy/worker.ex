defmodule Blitzy.Worker do
  use Timex
  require Logger

  def start(url, func \\ &HTTPoison.get/1) do
    {timestamp, response} = Duration.measure(fn -> func.(url) end)
    handle_response({Duration.to_milliseconds(timestamp), response})
  end

  defp handle_response({msecs, {:ok, %HTTPoison.Response{status_code: code}}})
       when code in 200..304 do
    Logger.info("worker #{name()} completed in #{msecs}")
    {:ok, msecs}
  end

  defp handle_response({_msecs, {:error, reason}}) do
    Logger.info("worker #{name()} error due to #{reason}")
    {:error, reason}
  end

  defp handle_response({_msecs, _response}) do
    Logger.info("worker #{name()} errored out")
    {:error, :unknown}
  end

  defp name do
    "[#{node()}-#{inspect(self())}]"
  end
end
