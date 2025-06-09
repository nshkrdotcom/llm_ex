defmodule Gemini.SSE.Parser do
  @moduledoc """
  Server-Sent Events (SSE) parser for streaming responses.

  Handles partial chunks and maintains state across multiple calls.
  Properly parses SSE format with incremental data.
  """

  defstruct buffer: "", events: []

  @type t :: %__MODULE__{
          buffer: String.t(),
          events: [map()]
        }

  @type parse_result :: {:ok, [map()], t()} | {:error, term()}

  @doc """
  Create a new SSE parser state.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Parse incoming SSE chunk and return events + updated state.

  ## Examples

      iex> parser = SSE.Parser.new()
      iex> chunk = "data: {\\"text\\": \\"hello\\"}\n\n"
      iex> {:ok, events, new_parser} = SSE.Parser.parse_chunk(chunk, parser)
      iex> length(events)
      1
  """
  @spec parse_chunk(String.t(), t()) :: parse_result()
  def parse_chunk(chunk, %__MODULE__{buffer: buffer} = state) when is_binary(chunk) do
    try do
      # Combine existing buffer with new chunk
      full_data = buffer <> chunk

      # Extract complete events (separated by \n\n)
      {events, remaining_buffer} = extract_events(full_data)

      # Parse each event
      parsed_events =
        events
        |> Enum.map(&parse_event/1)
        |> Enum.filter(&(&1 != nil))

      new_state = %{state | buffer: remaining_buffer}

      {:ok, parsed_events, new_state}
    rescue
      error -> {:error, {:parse_error, error}}
    end
  end

  @doc """
  Finalize parsing and return any remaining events in buffer.

  Call this when the stream is complete to get any final partial events.
  """
  @spec finalize(t()) :: {:ok, [map()]}
  def finalize(%__MODULE__{buffer: ""}) do
    {:ok, []}
  end

  def finalize(%__MODULE__{buffer: buffer}) do
    # Try to parse any remaining data as a final event
    case parse_event(buffer) do
      nil -> {:ok, []}
      event -> {:ok, [event]}
    end
  end

  # Private functions

  @spec extract_events(String.t()) :: {[String.t()], String.t()}
  defp extract_events(data) do
    # Split by double newlines to separate events (handle both \r\n\r\n and \n\n)
    parts = String.split(data, ~r/\r?\n\r?\n/)

    case parts do
      [] ->
        {[], ""}

      [single_part] ->
        # No complete events, everything goes back to buffer
        {[], single_part}

      multiple_parts ->
        # Last part might be incomplete, keep as buffer
        {complete_events, [remaining]} = Enum.split(multiple_parts, -1)
        # Filter out empty events and trim remaining buffer
        filtered_events = Enum.filter(complete_events, &(&1 != ""))
        trimmed_remaining = String.trim(remaining)
        {filtered_events, trimmed_remaining}
    end
  end

  @spec parse_event(String.t()) :: map() | nil
  defp parse_event(event_data) do
    event_data
    |> String.trim()
    |> parse_sse_lines()
    |> build_event()
  end

  @spec parse_sse_lines(String.t()) :: map()
  defp parse_sse_lines(event_data) do
    event_data
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        ["data", json_data] ->
          Map.put(acc, :data, json_data)

        ["event", event_type] ->
          Map.put(acc, :event, event_type)

        ["id", event_id] ->
          Map.put(acc, :id, event_id)

        ["retry", retry_ms] ->
          case Integer.parse(retry_ms) do
            {ms, ""} -> Map.put(acc, :retry, ms)
            _ -> acc
          end

        [field, value] ->
          # Handle other SSE fields
          Map.put(acc, String.to_atom(field), value)

        _ ->
          # Ignore malformed lines
          acc
      end
    end)
  end

  @spec build_event(map()) :: map() | nil
  defp build_event(%{data: data} = event_fields) do
    case parse_json_data(data) do
      {:ok, parsed_data} ->
        event_fields
        |> Map.put(:data, parsed_data)
        |> Map.put(:timestamp, System.system_time(:millisecond))

      {:error, _} ->
        # Skip events with invalid JSON
        nil
    end
  end

  defp build_event(_), do: nil

  @spec parse_json_data(String.t()) :: {:ok, map()} | {:error, term()}
  defp parse_json_data("[DONE]"), do: {:ok, %{done: true}}

  defp parse_json_data(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Check if an event indicates the stream is done.
  """
  @spec stream_done?(map()) :: boolean()
  def stream_done?(%{data: %{done: true}}), do: true
  def stream_done?(%{data: "[DONE]"}), do: true
  def stream_done?(_), do: false

  @doc """
  Extract text content from a streaming event.
  """
  @spec extract_text(map()) :: String.t() | nil
  def extract_text(%{data: %{"candidates" => candidates}}) do
    candidates
    |> List.first()
    |> case do
      %{"content" => %{"parts" => parts}} ->
        parts
        |> Enum.find_value(fn part ->
          case part do
            %{"text" => text} -> text
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  end

  def extract_text(_), do: nil
end
