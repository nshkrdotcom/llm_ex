defmodule Gemini.Client.HTTPStreaming do
  @moduledoc """
  HTTP client for streaming Server-Sent Events (SSE) from Gemini API.

  Provides proper streaming support with:
  - Incremental SSE parsing
  - Connection management
  - Error handling and retries
  - Backpressure support
  """

  alias Gemini.SSE.Parser
  alias Gemini.Error
  alias Gemini.Telemetry

  require Logger

  @type stream_event :: %{
          type: :data | :error | :complete,
          data: map() | nil,
          error: term() | nil
        }

  @type stream_callback :: (stream_event() -> :ok | :stop)

  @doc """
  Start an SSE stream with a callback function.

  ## Parameters
  - `url` - Full URL for the streaming endpoint
  - `headers` - HTTP headers including authentication
  - `body` - Request body (will be JSON encoded)
  - `callback` - Function called for each event
  - `opts` - Options including timeout, retry settings

  ## Examples

      callback = fn
        %{type: :data, data: data} ->
          IO.puts("Received data")
          :ok
        %{type: :complete} ->
          IO.puts("Stream complete")
          :ok
        %{type: :error, error: _error} ->
          IO.puts("Stream error")
          :stop
      end

      HTTPStreaming.stream_sse(url, headers, body, callback)
  """
  @spec stream_sse(String.t(), [{String.t(), String.t()}], map(), stream_callback(), keyword()) ::
          {:ok, :completed} | {:error, term()}
  def stream_sse(url, headers, body, callback, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    max_retries = Keyword.get(opts, :max_retries, 3)

    stream_id = Telemetry.generate_stream_id()
    metadata = Telemetry.build_stream_metadata(url, :post, stream_id, opts)
    measurements = %{system_time: System.system_time()}

    Telemetry.execute([:gemini, :stream, :start], measurements, metadata)

    try do
      # Wrap the callback to emit telemetry for chunks
      telemetry_callback = fn event ->
        case event do
          %{type: :data, data: data} ->
            chunk_measurements = %{
              chunk_size: calculate_chunk_size(data),
              system_time: System.system_time()
            }

            Telemetry.execute([:gemini, :stream, :chunk], chunk_measurements, metadata)

          _ ->
            :ok
        end

        callback.(event)
      end

      result =
        stream_with_retries(url, headers, body, telemetry_callback, timeout, max_retries, 0)

      case result do
        {:ok, :completed} ->
          # Emit stream completion event
          Telemetry.execute([:gemini, :stream, :stop], %{}, metadata)
          result

        {:error, error} ->
          Telemetry.execute(
            [:gemini, :stream, :exception],
            measurements,
            Map.put(metadata, :reason, error)
          )

          result
      end
    rescue
      exception ->
        Telemetry.execute(
          [:gemini, :stream, :exception],
          measurements,
          Map.put(metadata, :reason, exception)
        )

        reraise exception, __STACKTRACE__
    end
  end

  @doc """
  Start an SSE stream that sends events to a GenServer process.

  Events are sent as messages: {:stream_event, stream_id, event}
  """
  @spec stream_to_process(
          String.t(),
          [{String.t(), String.t()}],
          map(),
          String.t(),
          pid(),
          keyword()
        ) ::
          {:ok, pid()} | {:error, term()}
  def stream_to_process(url, headers, body, stream_id, target_pid, opts \\ []) do
    callback = fn event ->
      send(target_pid, {:stream_event, stream_id, event})
      :ok
    end

    # Start streaming in a separate process
    stream_pid =
      spawn(fn ->
        case stream_sse(url, headers, body, callback, opts) do
          {:ok, :completed} ->
            send(target_pid, {:stream_complete, stream_id})

          {:error, error} ->
            send(target_pid, {:stream_error, stream_id, error})
        end
      end)

    {:ok, stream_pid}
  end

  # Private implementation

  @spec stream_with_retries(
          String.t(),
          list(),
          map(),
          stream_callback(),
          integer(),
          integer(),
          integer()
        ) ::
          {:ok, :completed} | {:error, term()}
  defp stream_with_retries(url, headers, body, callback, timeout, max_retries, attempt) do
    case do_stream(url, headers, body, callback, timeout) do
      {:ok, :completed} ->
        {:ok, :completed}

      {:error, error} when attempt < max_retries ->
        Logger.warning("Stream attempt #{attempt + 1} failed: #{inspect(error)}, retrying...")

        # Exponential backoff
        delay = min(1000 * :math.pow(2, attempt), 10_000) |> round()
        Process.sleep(delay)

        stream_with_retries(url, headers, body, callback, timeout, max_retries, attempt + 1)

      {:error, error} ->
        Logger.error("Stream failed after #{max_retries} retries: #{inspect(error)}")
        {:error, error}
    end
  end

  @spec do_stream(String.t(), list(), map(), stream_callback(), integer()) ::
          {:ok, :completed} | {:error, term()}
  defp do_stream(url, headers, body, callback, timeout) do
    # Add SSE parameters to URL
    sse_url = add_sse_params(url)

    # Initialize SSE parser
    parser = Parser.new()

    # Use a more direct approach with custom HTTP handling
    case stream_with_finch(sse_url, headers, body, callback, parser, timeout) do
      {:ok, :completed} ->
        {:ok, :completed}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec stream_with_finch(String.t(), list(), map(), stream_callback(), Parser.t(), integer()) ::
          {:ok, :completed} | {:error, term()}
  defp stream_with_finch(url, headers, body, callback, parser, timeout) do
    Logger.debug("Starting real-time streaming with Req to #{url}")

    # Track parser state for real-time processing
    parser_ref = make_ref()
    :persistent_term.put(parser_ref, parser)

    # Use Req's `:self` option for real-time streaming
    req_opts = [
      method: :post,
      url: url,
      headers: add_sse_headers(headers),
      json: body,
      receive_timeout: timeout,
      connect_options: [timeout: 5_000],
      # Use :self to get messages as they arrive
      into: :self
    ]

    try do
      case Req.request(req_opts) do
        {:ok, response} ->
          # Check for HTTP errors before starting to stream
          if response.status >= 400 do
            # For error responses, we need to collect the body from streaming messages
            error_body = collect_error_body(response, timeout)
            error_msg = extract_error_message(error_body) || "HTTP #{response.status}"
            error = Error.http_error(response.status, error_msg)
            error_event = %{type: :error, data: nil, error: error}
            callback.(error_event)
            {:error, error}
          else
            # Process streaming messages in real-time
            stream_loop(response, parser_ref, callback, timeout)
          end

        {:error, %Req.TransportError{reason: reason}} ->
          error = Error.network_error("Transport error: #{inspect(reason)}")
          error_event = %{type: :error, data: nil, error: error}
          callback.(error_event)
          {:error, error}

        {:error, reason} ->
          error = Error.network_error("Request failed: #{inspect(reason)}")
          error_event = %{type: :error, data: nil, error: error}
          callback.(error_event)
          {:error, reason}
      end
    catch
      {:stop_stream, :completed} ->
        {:ok, :completed}

      {:stop_stream, :requested} ->
        {:ok, :completed}

      {:stop_stream, error} ->
        {:error, error}
    after
      # Always clean up persistent term
      :persistent_term.erase(parser_ref)
    end
  end

  # Collect error response body from streaming messages
  defp collect_error_body(response, timeout) do
    collect_error_body(response, timeout, "")
  end

  defp collect_error_body(response, timeout, acc) do
    receive do
      message ->
        case Req.parse_message(response, message) do
          {:ok, [{:data, chunk}]} ->
            collect_error_body(response, timeout, acc <> chunk)

          {:ok, [:done]} ->
            acc

          {:ok, other} ->
            Logger.debug("Received other message during error collection: #{inspect(other)}")
            collect_error_body(response, timeout, acc)

          :unknown ->
            Logger.debug("Received unknown message during error collection: #{inspect(message)}")
            collect_error_body(response, timeout, acc)
        end
    after
      timeout ->
        Logger.warning("Timeout collecting error response body")
        acc
    end
  end

  # Process streaming messages in real-time
  defp stream_loop(response, parser_ref, callback, timeout) do
    receive do
      message ->
        case Req.parse_message(response, message) do
          {:ok, [{:data, chunk}]} ->
            Logger.debug("Received streaming chunk of size #{byte_size(chunk)}")

            # Get current parser state
            current_parser = :persistent_term.get(parser_ref)

            # Process chunk immediately!
            case Parser.parse_chunk(chunk, current_parser) do
              {:ok, events, new_parser} ->
                # Update parser state
                :persistent_term.put(parser_ref, new_parser)

                # Send each event immediately - TRUE STREAMING!
                Enum.each(events, fn event ->
                  stream_event = %{type: :data, data: event.data, error: nil}

                  case callback.(stream_event) do
                    :ok -> :continue
                    :stop -> throw({:stop_stream, :requested})
                  end

                  # Check if this event indicates stream completion
                  if Parser.stream_done?(event) do
                    completion_event = %{type: :complete, data: nil, error: nil}
                    callback.(completion_event)
                    throw({:stop_stream, :completed})
                  end
                end)

              {:error, error} ->
                error_event = %{type: :error, data: nil, error: error}
                callback.(error_event)
            end

            # Continue processing
            stream_loop(response, parser_ref, callback, timeout)

          {:ok, [:done]} ->
            Logger.debug("Stream completed")

            # Parse any remaining buffered data
            final_parser = :persistent_term.get(parser_ref)

            case Parser.finalize(final_parser) do
              {:ok, remaining_events} ->
                Enum.each(remaining_events, fn event ->
                  stream_event = %{type: :data, data: event.data, error: nil}
                  callback.(stream_event)
                end)
            end

            # Send final completion event
            completion_event = %{type: :complete, data: nil, error: nil}
            callback.(completion_event)
            {:ok, :completed}

          {:ok, other} ->
            Logger.debug("Received other message: #{inspect(other)}")
            stream_loop(response, parser_ref, callback, timeout)

          :unknown ->
            Logger.debug("Received unknown message: #{inspect(message)}")
            stream_loop(response, parser_ref, callback, timeout)
        end
    after
      timeout ->
        error = Error.network_error("Stream timeout after #{timeout}ms")
        error_event = %{type: :error, data: nil, error: error}
        callback.(error_event)
        {:error, :timeout}
    end
  end

  @spec add_sse_params(String.t()) :: String.t()
  defp add_sse_params(url) do
    separator = if String.contains?(url, "?"), do: "&", else: "?"
    url <> separator <> "alt=sse"
  end

  @spec add_sse_headers([{String.t(), String.t()}]) :: [{String.t(), String.t()}]
  defp add_sse_headers(headers) do
    sse_headers = [
      {"Accept", "text/event-stream"},
      {"Cache-Control", "no-cache"}
    ]

    # Merge with existing headers, avoiding duplicates
    existing_keys = Enum.map(headers, fn {key, _} -> String.downcase(key) end)

    new_headers =
      sse_headers
      |> Enum.reject(fn {key, _} -> String.downcase(key) in existing_keys end)

    headers ++ new_headers
  end

  @spec extract_error_message(binary()) :: String.t() | nil
  defp extract_error_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => message}}} when is_binary(message) -> message
      {:ok, %{"error" => error}} when is_binary(error) -> error
      _ -> nil
    end
  end

  # Helper functions for telemetry

  defp calculate_chunk_size(data) when is_map(data) do
    data
    |> Jason.encode()
    |> case do
      {:ok, json} -> byte_size(json)
      _ -> 0
    end
  end

  defp calculate_chunk_size(data) when is_binary(data), do: byte_size(data)
  defp calculate_chunk_size(_), do: 0
end
