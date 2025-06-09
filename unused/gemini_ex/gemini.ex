defmodule Gemini do
  @moduledoc """
  Main Gemini client interface.

  This module provides backward-compatible access to the Gemini API
  while routing requests through the unified coordinator.
  """

  alias Gemini.APIs.Coordinator
  alias Gemini.Error
  alias Gemini.Types.Content
  alias Gemini.Types.Response.GenerateContentResponse

  @doc """
  Configure authentication for the client.

  ## Examples

      # Gemini API
      Gemini.configure(:gemini, %{api_key: "your_api_key"})

      # Vertex AI
      Gemini.configure(:vertex_ai, %{
        service_account_key: "/path/to/key.json",
        project_id: "your-project", 
        location: "us-central1"
      })
  """
  @spec configure(atom(), map()) :: :ok
  def configure(auth_type, credentials) do
    Application.put_env(:gemini, :auth, %{type: auth_type, credentials: credentials})
    :ok
  end

  @doc """
  Generate content using the configured authentication.
  """
  @spec generate(String.t() | [Content.t()], keyword()) ::
          {:ok, GenerateContentResponse.t()} | {:error, Error.t()}
  def generate(contents, opts \\ []) do
    Coordinator.generate_content(contents, opts)
  end

  @doc """
  Generate text content and return only the text.
  """
  @spec text(String.t() | [Content.t()], keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def text(contents, opts \\ []) do
    case Coordinator.generate_content(contents, opts) do
      {:ok, response} -> Coordinator.extract_text(response)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  List available models.
  """
  @spec list_models(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list_models(opts \\ []) do
    Coordinator.list_models(opts)
  end

  @doc """
  Get information about a specific model.
  """
  @spec get_model(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_model(model_name) do
    Coordinator.get_model(model_name)
  end

  @doc """
  Count tokens in the given content.
  """
  @spec count_tokens(String.t() | [Content.t()], keyword()) :: {:ok, map()} | {:error, Error.t()}
  def count_tokens(contents, opts \\ []) do
    Coordinator.count_tokens(contents, opts)
  end

  @doc """
  Start a new chat session.
  """
  @spec chat(keyword()) :: {:ok, map()}
  def chat(opts \\ []) do
    {:ok, %{history: [], opts: opts}}
  end

  @doc """
  Send a message in a chat session.
  """
  @spec send_message(map(), String.t()) ::
          {:ok, GenerateContentResponse.t(), map()} | {:error, Error.t()}
  def send_message(chat, message) do
    contents = [Content.text(message)]

    case generate(contents, chat.opts) do
      {:ok, response} ->
        updated_chat = %{
          chat
          | history:
              chat.history ++
                [
                  %{role: "user", content: message},
                  %{role: "model", content: response}
                ]
        }

        {:ok, response, updated_chat}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Start a managed streaming session.
  """
  @spec start_stream(String.t() | [Content.t()], keyword()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def start_stream(contents, opts \\ []) do
    Coordinator.stream_generate_content(contents, opts)
  end

  @doc """
  Subscribe to streaming events.
  """
  @spec subscribe_stream(String.t()) :: :ok | {:error, Error.t()}
  def subscribe_stream(stream_id) do
    Coordinator.subscribe_stream(stream_id, self())
  end

  @doc """
  Get stream status.
  """
  @spec get_stream_status(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_stream_status(stream_id) do
    Coordinator.stream_status(stream_id)
  end

  @doc """
  Extract text from a GenerateContentResponse or raw streaming data.
  """
  @spec extract_text(GenerateContentResponse.t() | map()) ::
          {:ok, String.t()} | {:error, String.t()}
  def extract_text(%GenerateContentResponse{
        candidates: [%{content: %{parts: [%{text: text} | _]}} | _]
      }) do
    {:ok, text}
  end

  def extract_text(%GenerateContentResponse{candidates: []}) do
    {:error, "No candidates in response"}
  end

  def extract_text(%GenerateContentResponse{}) do
    {:error, "No text content found in response"}
  end

  # Handle raw streaming data format
  def extract_text(%{"candidates" => [%{"content" => %{"parts" => parts}} | _]}) do
    text =
      parts
      |> Enum.find(&Map.has_key?(&1, "text"))
      |> case do
        %{"text" => text} -> text
        _ -> ""
      end

    {:ok, text}
  end

  def extract_text(_), do: {:error, "Invalid response format"}

  @doc """
  Check if a model exists.
  """
  @spec model_exists?(String.t()) :: {:ok, boolean()}
  def model_exists?(model_name) do
    case get_model(model_name) do
      {:ok, _model} -> {:ok, true}
      {:error, _} -> {:ok, false}
    end
  end

  @doc """
  Generate content with streaming response (synchronous collection).
  """
  @spec stream_generate(String.t() | [Content.t()], keyword()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def stream_generate(contents, opts \\ []) do
    case start_stream(contents, opts) do
      {:ok, stream_id} ->
        :ok = subscribe_stream(stream_id)
        collect_stream_responses(stream_id, [])

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Start the streaming manager (for compatibility).
  """
  @spec start_link() :: {:ok, pid()} | {:error, term()}
  def start_link do
    # The UnifiedManager is started automatically with the application
    # This function is for compatibility with tests
    case Process.whereis(Gemini.Streaming.UnifiedManager) do
      nil -> {:error, :not_started}
      pid -> {:ok, pid}
    end
  end

  # Helper function to collect streaming responses
  defp collect_stream_responses(stream_id, acc) do
    receive do
      {:stream_event, ^stream_id, %{type: :data, data: data}} ->
        collect_stream_responses(stream_id, [data | acc])

      {:stream_complete, ^stream_id} ->
        {:ok, Enum.reverse(acc)}

      {:stream_error, ^stream_id, error} ->
        {:error, error}
    after
      30_000 ->
        {:error, "Stream timeout"}
    end
  end
end
