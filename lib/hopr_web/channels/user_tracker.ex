defmodule HoprWeb.UserTracker do
  @behaviour Phoenix.Tracker
  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def start_link(opts) do
    opts =
      opts
      |> Keyword.put(:name, __MODULE__)
      |> Keyword.put(:pubsub_server, Hopr.PubSub)

    Phoenix.Tracker.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server}}
  end

  def handle_diff(changes, state) do
    Logger.info inspect({"tracked changes", changes})
    {:ok, state}
  end

  def track(pid, topic, user_id) do
    metadata = %{
      online_at: DateTime.utc_now(),
      user_id: user_id
    }

    Phoenix.Tracker.track(__MODULE__, pid, topic, user_id, metadata)
  end

  def list(topic) do
    Phoenix.Tracker.list(__MODULE__, topic)
  end

  @doc """
  Tracks each client of an application connected to the pubsub server.
  The pid of the client is used
  The clientId of the application is used as the topic.

  ## Example

    iex>track_api_connections(:api_connections, "api_connections")
  """
  def track_api_connections(pid, clientId) do
    track(pid, "application_connections:#{clientId}", clientId)
  end

  @doc """
  Counts the number of connections an application has.
  The application is identified by its clientId.
  The role limit of the application being counted
  Raises an error if limit for application connections is reached.
  Returns the number of connections.

  ## Example

    iex> count_api_channel("0x1234567890", :SLIM)
    {:ok, 1}
    {:error, reason}
  """
  def count_api_channel(clientId, role) do
    lists = list("application_connections:#{clientId}")
    number_of_presences = length(lists)
    case role do
      :ADMIN ->
        {:ok, number_of_presences}
      :HOBBYIST ->
        if number_of_presences > 10 do
          {:error, "Too many connections"}
        else
          {:ok, number_of_presences}
        end
      :PERSONAL ->
        if number_of_presences > 50 do
          {:error, "Too many connections"}
        else
          {:ok, number_of_presences}
        end
      :PROFESSIONAL ->
        if number_of_presences > 100 do
          {:error, "Too many connections"}
        else
          {:ok, number_of_presences}
        end
    end
  end

end
