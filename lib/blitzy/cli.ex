defmodule Blitzy.CLI do
  require Logger

  def main(args) do
    Application.get_env(:blitzy, :master_node) |> Node.start
    Application.get_env(:blitzy, :slave_nodes) |> Enum.each(&Node.connect(&1))

    args
    |> parse_args()
    |> process_options([node() | Node.list])
  end

  defp parse_args(args) do
    OptionParser.parse(args, aliases: [n: :requests], strict: [requests: :integer])
  end

  defp process_options({[requests: n], [url], []}, nodes) do
    do_requests(n, url, nodes)
  end

  defp process_options(_, _) do
    do_help()
  end

  defp do_requests(n_requests, url, nodes) do
    Logger.info "Pummeling #{url} with #{n_requests} requests"

    total_nodes = Enum.count(nodes)
    req_per_node = div(n_requests, total_nodes)

    nodes
    |> Enum.flat_map(fn node ->
      Enum.map(1..req_per_node,  fn _ ->
        Task.Supervisor.async({Blitzy.TasksSupervisor, node}, Blitzy.Worker, :start, [url])
      end)
    end)
    |> Enum.map(&Task.await(&1, :infinity))
    |> parse_results
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

  defp do_help do
    IO.puts """
    Usage: blitzy -n [requests] [url]

    Options:
      -n, [--requests]  # Number of requests

    Example:
      ./blitzy -n 100 http://www.bieberfever.com
    """

    System.halt(0)
  end
end
