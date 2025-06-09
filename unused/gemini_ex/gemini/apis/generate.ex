defmodule Gemini.Generate do
  @moduledoc """
  API for generating content with Gemini models.
  """

  alias Gemini.Client.HTTP
  alias Gemini.Config
  alias Gemini.Types.{Content, Part}
  alias Gemini.Types.Request.{GenerateContentRequest, CountTokensRequest}
  alias Gemini.Telemetry

  alias Gemini.Types.Response.{
    GenerateContentResponse,
    CountTokensResponse,
    Candidate,
    PromptFeedback,
    UsageMetadata
  }

  # Note: SafetySetting and GenerationConfig aliases removed as they're not used directly
  alias Gemini.Error

  @doc """
  Generate content using a Gemini model.

  ## Parameters
    - `contents` - List of Content structs or strings
    - `opts` - Options including:
      - `:model` - Model name (default: from config)
      - `:generation_config` - GenerationConfig struct
      - `:safety_settings` - List of SafetySetting structs
      - `:system_instruction` - System instruction as Content or string
      - `:tools` - List of tool definitions
      - `:tool_config` - Tool configuration

  ## Examples

      iex> Gemini.Generate.content("Hello, world!")
      {:ok, %GenerateContentResponse{candidates: [%Candidate{...}]}}

      iex> contents = [Content.text("Explain quantum physics")]
      iex> config = GenerationConfig.creative()
      iex> Gemini.Generate.content(contents, generation_config: config)
      {:ok, %GenerateContentResponse{...}}

  """
  def content(contents, opts \\ []) when is_list(contents) or is_binary(contents) do
    model = Keyword.get(opts, :model, Config.default_model())

    # Add telemetry metadata
    enhanced_opts =
      Keyword.merge(opts,
        model: model,
        function: :generate_content,
        contents_type: Telemetry.classify_contents(contents)
      )

    request = build_generate_request(contents, opts)
    path = "models/#{model}:generateContent"

    case HTTP.post(path, request, enhanced_opts) do
      {:ok, response} -> parse_generate_response(response)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Generate content with streaming support.

  Returns a stream of partial responses as they become available.

  ## Parameters
    - `contents` - List of Content structs or strings
    - `opts` - Same options as `content/2`

  ## Examples

      iex> Gemini.Generate.stream_content("Write a story")
      {:ok, [%GenerateContentResponse{...}, ...]}

  """
  def stream_content(contents, opts \\ []) when is_list(contents) or is_binary(contents) do
    model = Keyword.get(opts, :model, Config.default_model())

    # Add telemetry metadata
    enhanced_opts =
      Keyword.merge(opts,
        model: model,
        function: :stream_generate_content,
        contents_type: Telemetry.classify_contents(contents)
      )

    request = build_generate_request(contents, opts)
    path = "models/#{model}:streamGenerateContent?alt=sse"

    case HTTP.stream_post(path, request, enhanced_opts) do
      {:ok, events} -> parse_stream_responses(events)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Count tokens in the given content.

  ## Parameters
    - `contents` - List of Content structs or strings
    - `opts` - Options including:
      - `:model` - Model name (default: from config)

  ## Examples

      iex> Gemini.Generate.count_tokens("Hello, world!")
      {:ok, %CountTokensResponse{total_tokens: 3}}

  """
  def count_tokens(contents, opts \\ []) when is_list(contents) or is_binary(contents) do
    model = Keyword.get(opts, :model, Config.default_model())

    # Add telemetry metadata
    enhanced_opts =
      Keyword.merge(opts,
        model: model,
        function: :count_tokens,
        contents_type: Telemetry.classify_contents(contents)
      )

    contents_list = normalize_contents(contents)
    request = %CountTokensRequest{contents: contents_list}
    path = "models/#{model}:countTokens"

    case HTTP.post(path, request, enhanced_opts) do
      {:ok, response} -> parse_count_tokens_response(response)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Generate content and return only the text from the first candidate.

  This is a convenience function for simple text generation.

  ## Examples

      iex> Gemini.Generate.text("What is the capital of France?")
      {:ok, "The capital of France is Paris."}

  """
  def text(contents, opts \\ []) do
    case content(contents, opts) do
      {:ok,
       %GenerateContentResponse{
         candidates: [%Candidate{content: %Content{parts: [%Part{text: text} | _]}} | _]
       }} ->
        {:ok, text}

      {:ok, %GenerateContentResponse{candidates: []}} ->
        {:error, Error.invalid_response("No candidates returned")}

      {:ok, %GenerateContentResponse{candidates: [%Candidate{content: nil} | _]}} ->
        {:error, Error.invalid_response("Candidate has no content")}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Start a chat session for multi-turn conversations.

  ## Parameters
    - `opts` - Options including:
      - `:model` - Model name (default: from config)
      - `:history` - Chat history as list of Content structs
      - `:generation_config` - GenerationConfig struct
      - `:safety_settings` - List of SafetySetting structs
      - `:system_instruction` - System instruction

  ## Examples

      iex> {:ok, chat} = Gemini.Generate.chat()
      iex> Gemini.Generate.send_message(chat, "Hello!")
      {:ok, response, updated_chat}

  """
  def chat(opts \\ []) do
    chat = %{
      model: Keyword.get(opts, :model, Config.default_model()),
      history: Keyword.get(opts, :history, []),
      generation_config: Keyword.get(opts, :generation_config),
      safety_settings: Keyword.get(opts, :safety_settings),
      system_instruction: Keyword.get(opts, :system_instruction),
      tools: Keyword.get(opts, :tools),
      tool_config: Keyword.get(opts, :tool_config)
    }

    {:ok, chat}
  end

  @doc """
  Send a message in a chat session.

  ## Parameters
    - `chat` - Chat session from `chat/1`
    - `message` - Message content as string or Content struct

  ## Returns
    - `{:ok, response, updated_chat}` on success
    - `{:error, error}` on failure

  """
  def send_message(chat, message) do
    user_content = normalize_content(message)
    contents = chat.history ++ [user_content]

    opts =
      [
        model: chat.model,
        generation_config: chat.generation_config,
        safety_settings: chat.safety_settings,
        system_instruction: chat.system_instruction,
        tools: chat.tools,
        tool_config: chat.tool_config
      ]
      |> Enum.filter(fn {_k, v} -> v != nil end)

    case content(contents, opts) do
      {:ok, response} ->
        # Add the response to chat history
        assistant_content = extract_assistant_content(response)
        updated_chat = %{chat | history: contents ++ [assistant_content]}
        {:ok, response, updated_chat}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private functions

  @doc """
  Build a generate content request structure.

  This function is exposed publicly to allow the streaming manager and other
  components to construct requests using the same validation and normalization
  logic as the main content generation functions.

  ## Parameters
    - `contents` - List of Content structs or strings
    - `opts` - Options including generation_config, safety_settings, etc.

  ## Returns
    - Map representing the request structure ready for JSON encoding
  """
  def build_generate_request(contents, opts) do
    contents_list = normalize_contents(contents)

    %GenerateContentRequest{
      contents: contents_list,
      generation_config: Keyword.get(opts, :generation_config),
      safety_settings: Keyword.get(opts, :safety_settings, []),
      system_instruction: normalize_system_instruction(Keyword.get(opts, :system_instruction)),
      tools: Keyword.get(opts, :tools, []),
      tool_config: Keyword.get(opts, :tool_config)
    }
    |> Map.from_struct()
    |> Enum.filter(fn {_k, v} -> v != nil and v != [] end)
    |> Map.new()
  end

  defp normalize_contents(contents) when is_binary(contents) do
    [Content.text(contents)]
  end

  defp normalize_contents(contents) when is_list(contents) do
    Enum.map(contents, &normalize_content/1)
  end

  defp normalize_content(%Content{} = content), do: content
  defp normalize_content(text) when is_binary(text), do: Content.text(text)

  defp normalize_system_instruction(nil), do: nil
  defp normalize_system_instruction(%Content{} = content), do: content
  defp normalize_system_instruction(text) when is_binary(text), do: Content.text(text)

  defp parse_generate_response(response) do
    try do
      candidates =
        response
        |> Map.get("candidates", [])
        |> Enum.map(&parse_candidate/1)

      prompt_feedback = parse_prompt_feedback(Map.get(response, "promptFeedback"))
      usage_metadata = parse_usage_metadata(Map.get(response, "usageMetadata"))

      generate_response = %GenerateContentResponse{
        candidates: candidates,
        prompt_feedback: prompt_feedback,
        usage_metadata: usage_metadata
      }

      {:ok, generate_response}
    rescue
      e -> {:error, Error.invalid_response("Failed to parse generate response: #{inspect(e)}")}
    end
  end

  defp parse_stream_responses(events) do
    try do
      responses =
        events
        |> Enum.map(fn event -> parse_generate_response(event) end)
        |> Enum.map(fn {:ok, response} -> response end)

      {:ok, responses}
    rescue
      e -> {:error, Error.invalid_response("Failed to parse stream responses: #{inspect(e)}")}
    end
  end

  defp parse_count_tokens_response(response) do
    try do
      count_response = %CountTokensResponse{
        total_tokens: Map.get(response, "totalTokens", 0)
      }

      {:ok, count_response}
    rescue
      e ->
        {:error, Error.invalid_response("Failed to parse count tokens response: #{inspect(e)}")}
    end
  end

  defp parse_candidate(candidate_data) do
    content =
      case Map.get(candidate_data, "content") do
        nil -> nil
        content_data -> parse_content(content_data)
      end

    %Candidate{
      content: content,
      finish_reason: Map.get(candidate_data, "finishReason"),
      safety_ratings: parse_safety_ratings(Map.get(candidate_data, "safetyRatings", [])),
      citation_metadata: parse_citation_metadata(Map.get(candidate_data, "citationMetadata")),
      token_count: Map.get(candidate_data, "tokenCount"),
      index: Map.get(candidate_data, "index")
    }
  end

  defp parse_content(content_data) do
    parts =
      content_data
      |> Map.get("parts", [])
      |> Enum.map(fn part_data ->
        cond do
          Map.has_key?(part_data, "text") ->
            Part.text(Map.get(part_data, "text"))

          Map.has_key?(part_data, "inlineData") ->
            inline_data = Map.get(part_data, "inlineData")

            Part.blob(
              Map.get(inline_data, "data"),
              Map.get(inline_data, "mimeType")
            )

          true ->
            Part.text("")
        end
      end)

    %Content{
      parts: parts,
      role: Map.get(content_data, "role", "user")
    }
  end

  defp parse_prompt_feedback(nil), do: nil

  defp parse_prompt_feedback(feedback_data) do
    %PromptFeedback{
      block_reason: Map.get(feedback_data, "blockReason"),
      safety_ratings: parse_safety_ratings(Map.get(feedback_data, "safetyRatings", []))
    }
  end

  defp parse_usage_metadata(nil), do: nil

  defp parse_usage_metadata(metadata) do
    %UsageMetadata{
      prompt_token_count: Map.get(metadata, "promptTokenCount"),
      candidates_token_count: Map.get(metadata, "candidatesTokenCount"),
      total_token_count: Map.get(metadata, "totalTokenCount", 0),
      cached_content_token_count: Map.get(metadata, "cachedContentTokenCount")
    }
  end

  defp parse_safety_ratings(ratings) when is_list(ratings) do
    Enum.map(ratings, fn rating ->
      %{
        category: Map.get(rating, "category"),
        probability: Map.get(rating, "probability"),
        blocked: Map.get(rating, "blocked")
      }
    end)
  end

  defp parse_citation_metadata(nil), do: nil

  defp parse_citation_metadata(_metadata) do
    # TODO: Implement citation metadata parsing
    nil
  end

  defp extract_assistant_content(%GenerateContentResponse{
         candidates: [%Candidate{content: content} | _]
       }) do
    %{content | role: "model"}
  end

  defp extract_assistant_content(_), do: Content.text("")
end
