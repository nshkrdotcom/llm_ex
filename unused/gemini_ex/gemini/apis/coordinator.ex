defmodule Gemini.APIs.Coordinator do
  @moduledoc """
  Coordinates API calls across different authentication strategies and endpoints.

  Provides a unified interface that can route requests to either Gemini API or Vertex AI
  based on configuration, while maintaining the same interface.

  This module acts as the main entry point for all Gemini API operations,
  automatically handling authentication strategy selection and request routing.

  ## Features

  - Unified API for content generation across auth strategies
  - Automatic auth strategy selection based on configuration
  - Per-request auth strategy override capability
  - Consistent error handling and response format
  - Support for both streaming and non-streaming operations
  - Model listing and token counting functionality

  ## Usage

      # Use default auth strategy
      {:ok, response} = Coordinator.generate_content("Hello world")

      # Override auth strategy for specific request
      {:ok, response} = Coordinator.generate_content("Hello world", auth: :vertex_ai)

      # Start streaming with specific auth
      {:ok, stream_id} = Coordinator.stream_generate_content("Tell me a story", auth: :gemini)
  """

  alias Gemini.Client.HTTP
  alias Gemini.Streaming.UnifiedManager
  alias Gemini.Types.Request.GenerateContentRequest
  alias Gemini.Types.Response.{GenerateContentResponse, ListModelsResponse}
  alias Gemini.Types.Content

  @type auth_strategy :: :gemini | :vertex_ai
  @type request_opts :: keyword()
  @type api_result(t) :: {:ok, t} | {:error, term()}

  # Content Generation API

  @doc """
  Generate content using the specified model and input.

  ## Parameters
  - `input`: String prompt or GenerateContentRequest struct
  - `opts`: Options including model, auth strategy, and generation config

  ## Options
  - `:model`: Model to use (defaults to "gemini-2.0-flash")
  - `:auth`: Authentication strategy (`:gemini` or `:vertex_ai`)
  - `:temperature`: Generation temperature (0.0-1.0)
  - `:max_output_tokens`: Maximum tokens to generate
  - `:top_p`: Top-p sampling parameter
  - `:top_k`: Top-k sampling parameter
  - `:safety_settings`: List of safety settings

  ## Examples

      # Simple text generation
      {:ok, response} = Coordinator.generate_content("What is AI?")

      # With specific model and auth
      {:ok, response} = Coordinator.generate_content(
        "Explain quantum computing",
        model: "gemini-2.0-flash",
        auth: :vertex_ai,
        temperature: 0.7
      )

      # Using request struct
      request = %GenerateContentRequest{...}
      {:ok, response} = Coordinator.generate_content(request)
  """
  @spec generate_content(String.t() | [Content.t()] | GenerateContentRequest.t(), request_opts()) ::
          api_result(GenerateContentResponse.t())
  def generate_content(input, opts \\ []) do
    model = Keyword.get(opts, :model, "gemini-2.0-flash")
    path = "models/#{model}:generateContent"

    with {:ok, request} <- build_generate_request(input, opts),
         {:ok, response} <- HTTP.post(path, request, opts) do
      parse_generate_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stream content generation with real-time response chunks.

  ## Parameters
  - `input`: String prompt or GenerateContentRequest struct  
  - `opts`: Options including model, auth strategy, and generation config

  ## Returns
  - `{:ok, stream_id}`: Stream started successfully
  - `{:error, reason}`: Failed to start stream

  After starting the stream, subscribe to receive events:

      {:ok, stream_id} = Coordinator.stream_generate_content("Tell me a story")
      :ok = Coordinator.subscribe_stream(stream_id)

      # Handle incoming messages
      receive do
        {:stream_event, ^stream_id, event} -> 
          IO.inspect(event, label: "Stream Event")
        {:stream_complete, ^stream_id} -> 
          IO.puts("Stream completed")
        {:stream_error, ^stream_id, stream_error} -> 
          IO.puts("Stream error: \#{inspect(stream_error)}")
      end

  ## Examples

      # Basic streaming
      {:ok, stream_id} = Coordinator.stream_generate_content("Write a poem")

      # With specific configuration
      {:ok, stream_id} = Coordinator.stream_generate_content(
        "Explain machine learning",
        model: "gemini-2.0-flash",
        auth: :gemini,
        temperature: 0.8,
        max_output_tokens: 1000
      )
  """
  @spec stream_generate_content(String.t() | GenerateContentRequest.t(), request_opts()) ::
          api_result(String.t())
  def stream_generate_content(input, opts \\ []) do
    model = Keyword.get(opts, :model, "gemini-2.0-flash")

    with {:ok, request_body} <- build_generate_request(input, opts) do
      UnifiedManager.start_stream(model, request_body, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Subscribe to a streaming content generation.

  ## Parameters  
  - `stream_id`: ID of the stream to subscribe to
  - `subscriber_pid`: Process to receive stream events (defaults to current process)

  ## Examples

      {:ok, stream_id} = Coordinator.stream_generate_content("Hello")
      :ok = Coordinator.subscribe_stream(stream_id)

      # In a different process
      :ok = Coordinator.subscribe_stream(stream_id, target_pid)
  """
  @spec subscribe_stream(String.t(), pid()) :: :ok | {:error, term()}
  def subscribe_stream(stream_id, subscriber_pid \\ self()) do
    UnifiedManager.subscribe(stream_id, subscriber_pid)
  end

  @doc """
  Unsubscribe from a streaming content generation.
  """
  @spec unsubscribe_stream(String.t(), pid()) :: :ok | {:error, term()}
  def unsubscribe_stream(stream_id, subscriber_pid \\ self()) do
    UnifiedManager.unsubscribe(stream_id, subscriber_pid)
  end

  @doc """
  Stop a streaming content generation.
  """
  @spec stop_stream(String.t()) :: :ok | {:error, term()}
  def stop_stream(stream_id) do
    UnifiedManager.stop_stream(stream_id)
  end

  @doc """
  Get the status of a streaming content generation.
  """
  @spec stream_status(String.t()) :: {:ok, atom()} | {:error, term()}
  def stream_status(stream_id) do
    UnifiedManager.stream_status(stream_id)
  end

  # Model Management API

  @doc """
  List available models for the specified authentication strategy.

  ## Parameters
  - `opts`: Options including auth strategy and pagination

  ## Options
  - `:auth`: Authentication strategy (`:gemini` or `:vertex_ai`)
  - `:page_size`: Number of models per page
  - `:page_token`: Pagination token for next page

  ## Examples

      # List models with default auth
      {:ok, models_response} = Coordinator.list_models()

      # List models with specific auth strategy
      {:ok, models_response} = Coordinator.list_models(auth: :vertex_ai)

      # With pagination
      {:ok, models_response} = Coordinator.list_models(
        auth: :gemini,
        page_size: 50,
        page_token: "next_page_token"
      )
  """
  @spec list_models(request_opts()) :: api_result(ListModelsResponse.t())
  def list_models(opts \\ []) do
    path = "models"

    with {:ok, response} <- HTTP.get(path, opts) do
      parse_models_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get information about a specific model.

  ## Parameters
  - `model_name`: Name of the model to retrieve
  - `opts`: Options including auth strategy

  ## Examples

      {:ok, model} = Coordinator.get_model("gemini-2.0-flash")
      {:ok, model} = Coordinator.get_model("gemini-1.5-pro", auth: :vertex_ai)
  """
  @spec get_model(String.t(), request_opts()) :: api_result(map())
  def get_model(model_name, opts \\ []) do
    path = "models/#{model_name}"

    with {:ok, response} <- HTTP.get(path, opts) do
      # Normalize response to use atom keys for common fields
      normalized_response = normalize_model_response(response)
      {:ok, normalized_response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Token Counting API

  @doc """
  Count tokens in the given input.

  ## Parameters
  - `input`: String or GenerateContentRequest to count tokens for
  - `opts`: Options including model and auth strategy

  ## Options
  - `:model`: Model to use for token counting (defaults to "gemini-2.0-flash")
  - `:auth`: Authentication strategy (`:gemini` or `:vertex_ai`)

  ## Examples

      {:ok, count} = Coordinator.count_tokens("Hello world")
      {:ok, count} = Coordinator.count_tokens("Complex text", model: "gemini-1.5-pro", auth: :vertex_ai)
  """
  @spec count_tokens(String.t() | GenerateContentRequest.t(), request_opts()) ::
          api_result(%{total_tokens: integer()})
  def count_tokens(input, opts \\ []) do
    model = Keyword.get(opts, :model, "gemini-2.0-flash")
    path = "models/#{model}:countTokens"

    with {:ok, request} <- build_count_tokens_request(input, opts),
         {:ok, response} <- HTTP.post(path, request, opts) do
      # Convert raw response to structured format
      total_tokens = Map.get(response, "totalTokens", 0)
      formatted_response = %{total_tokens: total_tokens}
      {:ok, formatted_response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Utility Functions

  @doc """
  Extract text content from a GenerateContentResponse.

  ## Examples

      {:ok, response} = Coordinator.generate_content("Hello")
      {:ok, text} = Coordinator.extract_text(response)
  """
  @spec extract_text(GenerateContentResponse.t()) :: {:ok, String.t()} | {:error, term()}
  def extract_text(%GenerateContentResponse{candidates: [first_candidate | _]}) do
    case first_candidate do
      %{content: %{parts: [_ | _] = parts}} ->
        text =
          parts
          |> Enum.filter(&Map.has_key?(&1, :text))
          |> Enum.map_join("", & &1.text)

        {:ok, text}

      _ ->
        {:error, "No text content found in response"}
    end
  end

  def extract_text(_), do: {:error, "No candidates found in response"}

  # Private Helper Functions

  @spec build_generate_request(
          String.t() | [Content.t()] | GenerateContentRequest.t(),
          request_opts()
        ) ::
          {:ok, map()} | {:error, term()}
  defp build_generate_request(%GenerateContentRequest{} = request, _opts) do
    {:ok, request}
  end

  defp build_generate_request(text, opts) when is_binary(text) do
    # Build a basic content request from text
    content = %{
      contents: [
        %{
          parts: [%{text: text}]
        }
      ]
    }

    # Add generation config if provided
    config = build_generation_config(opts)

    final_content =
      if map_size(config) > 0 do
        Map.put(content, :generationConfig, config)
      else
        content
      end

    {:ok, final_content}
  end

  defp build_generate_request(contents, opts) when is_list(contents) do
    # Build content request from Content structs
    formatted_contents = Enum.map(contents, &format_content/1)

    content = %{
      contents: formatted_contents
    }

    # Add generation config if provided
    config = build_generation_config(opts)

    final_content =
      if map_size(config) > 0 do
        Map.put(content, :generationConfig, config)
      else
        content
      end

    {:ok, final_content}
  end

  defp build_generate_request(_, _), do: {:error, "Invalid input type"}

  # Helper function to format Content structs for API requests
  defp format_content(%Content{role: role, parts: parts}) do
    %{
      role: role,
      parts: Enum.map(parts, &format_part/1)
    }
  end

  # Helper function to format Part structs for API requests  
  defp format_part(%{text: text}) when is_binary(text) do
    %{text: text}
  end

  defp format_part(%{inline_data: %{mime_type: mime_type, data: data}}) do
    %{inline_data: %{mime_type: mime_type, data: data}}
  end

  defp format_part(part), do: part

  # Helper function to normalize model response keys
  defp normalize_model_response(response) when is_map(response) do
    response
    |> Map.new(fn {key, value} ->
      atom_key =
        case key do
          "displayName" -> :display_name
          "name" -> :name
          "description" -> :description
          "inputTokenLimit" -> :input_token_limit
          "outputTokenLimit" -> :output_token_limit
          "supportedGenerationMethods" -> :supported_generation_methods
          _ -> key
        end

      {atom_key, value}
    end)
  end

  @spec build_generation_config(request_opts()) :: map()
  defp build_generation_config(opts) do
    opts
    |> Enum.reduce(%{}, fn
      {:temperature, temp}, acc when is_number(temp) -> Map.put(acc, :temperature, temp)
      {:max_output_tokens, max}, acc when is_integer(max) -> Map.put(acc, :maxOutputTokens, max)
      {:top_p, top_p}, acc when is_number(top_p) -> Map.put(acc, :topP, top_p)
      {:top_k, top_k}, acc when is_integer(top_k) -> Map.put(acc, :topK, top_k)
      _, acc -> acc
    end)
  end

  @spec build_count_tokens_request(String.t() | GenerateContentRequest.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  defp build_count_tokens_request(%GenerateContentRequest{} = request, _opts) do
    {:ok, %{generateContentRequest: request}}
  end

  defp build_count_tokens_request(text, _opts) when is_binary(text) do
    {:ok,
     %{
       contents: [
         %{
           parts: [%{text: text}]
         }
       ]
     }}
  end

  defp build_count_tokens_request(_, _), do: {:error, "Invalid input type"}

  @spec parse_generate_response(map()) :: {:ok, GenerateContentResponse.t()} | {:error, term()}
  defp parse_generate_response(response) when is_map(response) do
    # Convert string keys to atom keys for struct creation
    atomized_response = atomize_keys(response)
    {:ok, struct(GenerateContentResponse, atomized_response)}
  end

  @spec parse_models_response(map()) :: {:ok, ListModelsResponse.t()} | {:error, term()}
  defp parse_models_response(response) when is_map(response) do
    atomized_response = atomize_keys(response)
    {:ok, struct(ListModelsResponse, atomized_response)}
  end

  # Helper function to recursively convert string keys to atom keys
  @spec atomize_keys(term()) :: term()
  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {atomize_key(k), atomize_keys(v)} end)
    |> Enum.into(%{})
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  @spec atomize_key(String.t() | atom()) :: atom()
  defp atomize_key(key) when is_binary(key), do: String.to_atom(key)
  defp atomize_key(key) when is_atom(key), do: key
end
