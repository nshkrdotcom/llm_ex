defmodule LLMEx.Adapters.Providers.Gemini.Client do
  @moduledoc """
  Unified HTTP client for both Gemini and Vertex AI APIs.

  Supports multiple authentication strategies and provides both
  regular and streaming request capabilities using the multi-auth coordinator.
  """

  alias LLMEx.Adapters.Providers.Gemini.Auth.MultiAuthCoordinator
  alias LLMEx.Core.Entities.{Message, LLMResponse, StreamChunk}

  require Logger

  @type request_options :: [
          auth_strategy: :gemini | :vertex_ai,
          timeout: pos_integer(),
          stream: boolean()
        ]

  @doc """
  Make a POST request for chat completion.

  ## Parameters
  - `model` - The model to use (e.g., "gemini-pro", "gemini-pro-vision")
  - `messages` - List of Message entities
  - `opts` - Request options including auth strategy

  ## Returns
  - `{:ok, LLMResponse.t()}` on success
  - `{:error, term()}` on error
  """
  @spec chat_completion(String.t(), [Message.t()], request_options()) ::
          {:ok, LLMResponse.t()} | {:error, term()}
  def chat_completion(model, messages, opts \\ []) do
    auth_strategy = Keyword.get(opts, :auth_strategy, :gemini)
    stream = Keyword.get(opts, :stream, false)

    with {:ok, auth_strategy, headers} <- MultiAuthCoordinator.coordinate_auth(auth_strategy, opts),
         {:ok, base_url} <- MultiAuthCoordinator.get_base_url(auth_strategy, extract_credentials(opts)),
         {:ok, path} <- build_chat_path(auth_strategy, model, stream, extract_credentials(opts)),
         {:ok, body} <- build_chat_body(messages, opts) do
      url = "#{base_url}/#{path}"

      request_opts = [
        method: :post,
        url: url,
        headers: headers,
        json: body,
        receive_timeout: Keyword.get(opts, :timeout, 30_000)
      ]

      Logger.debug("Making Gemini chat request", %{url: url, model: model, auth_strategy: auth_strategy})

      case Req.request(request_opts) do
        {:ok, %{status: 200, body: response_body}} ->
          parse_chat_response(response_body, model)

        {:ok, %{status: status, body: error_body}} ->
          {:error, "HTTP #{status}: #{inspect(error_body)}"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Stream a chat completion request.

  ## Parameters
  - `model` - The model to use
  - `messages` - List of Message entities
  - `callback` - Function to handle stream chunks
  - `opts` - Request options

  ## Returns
  - `:ok` on success
  - `{:error, term()}` on error
  """
  @spec stream_chat_completion(String.t(), [Message.t()], function(), request_options()) ::
          :ok | {:error, term()}
  def stream_chat_completion(model, messages, callback, opts \\ []) do
    auth_strategy = Keyword.get(opts, :auth_strategy, :gemini)

    with {:ok, auth_strategy, headers} <- MultiAuthCoordinator.coordinate_auth(auth_strategy, opts),
         {:ok, base_url} <- MultiAuthCoordinator.get_base_url(auth_strategy, extract_credentials(opts)),
         {:ok, path} <- build_chat_path(auth_strategy, model, true, extract_credentials(opts)),
         {:ok, body} <- build_chat_body(messages, opts) do
      url = "#{base_url}/#{path}"

      # Add streaming headers
      stream_headers = [
        {"Accept", "text/event-stream"},
        {"Cache-Control", "no-cache"} | headers
      ]

      request_opts = [
        method: :post,
        url: url,
        headers: stream_headers,
        json: body,
        receive_timeout: Keyword.get(opts, :timeout, 60_000)
      ]

      Logger.debug("Making Gemini streaming request", %{url: url, model: model, auth_strategy: auth_strategy})

      # Use Req to stream the response
      Req.request(request_opts, into: fn {:data, chunk}, {req, resp} ->
        case parse_sse_chunk(chunk) do
          {:ok, stream_chunk} ->
            callback.(stream_chunk)

          {:error, _reason} ->
            # Skip invalid chunks
            :ok
        end

        {:cont, {req, resp}}
      end)
    end
  end

  @doc """
  List available models for the given authentication strategy.
  """
  @spec list_models(request_options()) :: {:ok, [String.t()]} | {:error, term()}
  def list_models(opts \\ []) do
    auth_strategy = Keyword.get(opts, :auth_strategy, :gemini)

    with {:ok, auth_strategy, headers} <- MultiAuthCoordinator.coordinate_auth(auth_strategy, opts),
         {:ok, base_url} <- MultiAuthCoordinator.get_base_url(auth_strategy, extract_credentials(opts)) do
      path = case auth_strategy do
        :gemini -> "models"
        :vertex_ai -> build_vertex_models_path(extract_credentials(opts))
      end

      url = "#{base_url}/#{path}"

      request_opts = [
        method: :get,
        url: url,
        headers: headers,
        receive_timeout: Keyword.get(opts, :timeout, 30_000)
      ]

      case Req.request(request_opts) do
        {:ok, %{status: 200, body: response_body}} ->
          parse_models_response(response_body, auth_strategy)

        {:ok, %{status: status, body: error_body}} ->
          {:error, "HTTP #{status}: #{inspect(error_body)}"}

        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end

  # Private helper functions

  defp extract_credentials(opts) do
    # Extract credential-related options
    opts
    |> Enum.filter(fn {key, _value} ->
      key in [:api_key, :project_id, :location, :access_token, :service_account_key, :service_account_data]
    end)
    |> Enum.into(%{})
  end

  defp build_chat_path(:gemini, model, stream, _credentials) do
    endpoint = if stream, do: "streamGenerateContent", else: "generateContent"
    path = MultiAuthCoordinator.build_path(:gemini, model, endpoint, %{})
    {:ok, path}
  end

  defp build_chat_path(:vertex_ai, model, stream, credentials) do
    endpoint = if stream, do: "streamGenerateContent", else: "generateContent"
    path = MultiAuthCoordinator.build_path(:vertex_ai, model, endpoint, credentials)
    {:ok, path}
  end

  defp build_chat_body(messages, opts) do
    # Convert Message entities to Gemini API format
    contents = Enum.map(messages, &message_to_gemini_format/1)

    body = %{
      contents: contents,
      generationConfig: build_generation_config(opts)
    }

    {:ok, body}
  end

  defp message_to_gemini_format(%Message{role: role, content: content}) do
    gemini_role = case role do
      :user -> "user"
      :assistant -> "model"
      :system -> "user"  # Gemini treats system messages as user messages
    end

    parts = case content do
      text when is_binary(text) -> [%{text: text}]
      contents when is_list(contents) -> Enum.map(contents, &content_part_to_gemini/1)
    end

    %{
      role: gemini_role,
      parts: parts
    }
  end

  defp content_part_to_gemini(%{type: :text, text: text}), do: %{text: text}
  defp content_part_to_gemini(%{type: :image, image_url: %{url: url}}), do: %{inline_data: %{mime_type: "image/jpeg", data: url}}
  defp content_part_to_gemini(content), do: %{text: to_string(content)}

  defp build_generation_config(opts) do
    config = %{}

    config = if temperature = Keyword.get(opts, :temperature), do: Map.put(config, :temperature, temperature), else: config
    config = if max_tokens = Keyword.get(opts, :max_tokens), do: Map.put(config, :maxOutputTokens, max_tokens), else: config
    config = if top_p = Keyword.get(opts, :top_p), do: Map.put(config, :topP, top_p), else: config
    config = if top_k = Keyword.get(opts, :top_k), do: Map.put(config, :topK, top_k), else: config

    config
  end

  defp parse_chat_response(%{"candidates" => [candidate | _]} = response, model) do
    content = case candidate do
      %{"content" => %{"parts" => [%{"text" => text} | _]}} -> text
      %{"content" => %{"parts" => parts}} ->
        parts |> Enum.map(&Map.get(&1, "text", "")) |> Enum.join("")
      _ -> ""
    end

    usage = extract_usage(response)

    llm_response = %LLMResponse{
      id: generate_response_id(),
      content: content,
      model: model,
      usage: usage,
      finish_reason: extract_finish_reason(candidate),
      created_at: DateTime.utc_now()
    }

    {:ok, llm_response}
  end

  defp parse_chat_response(response, _model) do
    {:error, "Invalid response format: #{inspect(response)}"}
  end

  defp extract_usage(%{"usageMetadata" => usage}) do
    %{
      prompt_tokens: Map.get(usage, "promptTokenCount", 0),
      completion_tokens: Map.get(usage, "candidatesTokenCount", 0),
      total_tokens: Map.get(usage, "totalTokenCount", 0)
    }
  end

  defp extract_usage(_), do: %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}

  defp extract_finish_reason(%{"finishReason" => reason}) do
    case reason do
      "STOP" -> :stop
      "MAX_TOKENS" -> :length
      "SAFETY" -> :content_filter
      "RECITATION" -> :content_filter
      _ -> :other
    end
  end

  defp extract_finish_reason(_), do: nil

  defp generate_response_id do
    "llmex_resp_#{System.system_time(:millisecond)}_#{:rand.uniform(9999)}"
  end
end
