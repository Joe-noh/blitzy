defmodule Blitzy do
  def run(n_workers, url) when n_workers > 0 do
    worker_fun = fn -> Blitzy.Worker.start(url) end

    1..n_workers
    |> Enum.map(fn _ -> Task.async(worker_fun) end)
    |> Enum.map(&Task.await(&1, :infinity))
    |> parse_results()
  end

  defp parse_results(results) do
    {successes, _failures} = results
      |> Enum.split_with(fn
        {:ok, _} -> true
        _error -> false
      end)

    total_workers = Enum.count(results)
    total_success = Enum.count(successes)
    total_failure = total_workers - total_success

    data = successes |> Enum.map(fn {:ok, time} -> time end)
    average_time = average(data)
    longest_time = Enum.max(data)
    shortest_time = Enum.min(data)

    IO.puts """
    Total workers: #{total_workers}
    Successful reqs: #{total_success}
    Failed res: #{total_failure}
    Average (msecs): #{average_time}
    Longest (msecs): #{longest_time}
    shortest (msecs): #{shortest_time}
    """
  end

  defp average(list) do
    case Enum.sum(list) do
      sum when sum > 0 -> sum / Enum.count(list)
      _minus -> 0
    end
  end
end
