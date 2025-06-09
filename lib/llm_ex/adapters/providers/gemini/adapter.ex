defmodule LLMEx.Adapters.Providers.Gemini.Adapter do
  @moduledoc """
  Gemini provider adapter implementing the ProviderAdapter behavior.

  This adapter provides a unified interface to Google's Gemini API
  and Vertex AI, handling authentication, requests, and streaming.
  """

  @behaviour LLMEx.Core.Ports.ProviderAdapter

  alias LLMEx.Core.Entities.{Conversation, LLMResponse, StreamChunk, Message}
  alias LLMEx.Adapters.Providers.Gemini.{Client, Mapper}

  @impl true
  def chat(%Conversation{} = conversation, opts \\ []) do
    model = conversation.model || "gemini-pro"
    messages = conversation.messages

    # Use the client directly with the multi-auth coordinator
    case Client.chat_completion(model, messages, opts) do
      {:ok, llm_response} -> {:ok, llm_response}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def stream_chat(%Conversation{} = conversation, opts \\ []) do
    model = conversation.model || "gemini-pro"
    messages = conversation.messages

    # Create a stream that collects chunks
    {:ok, pid} = Agent.start_link(fn -> [] end)

    callback = fn chunk ->
      Agent.update(pid, fn chunks -> [chunk | chunks] end)
    end

    case Client.stream_chat_completion(model, messages, callback, opts) do
      :ok ->
        # Get collected chunks and create a stream
        chunks = Agent.get(pid, &Enum.reverse/1)
        Agent.stop(pid)
        stream = Stream.map(chunks, & &1)
        {:ok, stream}

      {:error, reason} ->
        Agent.stop(pid)
        {:error, reason}
    end
  end

  @impl true
  def list_models(opts \\ []) do
    case Client.list_models(opts) do
      {:ok, models} -> {:ok, models}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def validate_config(config) do
    case config do
      %{api_key: api_key} when is_binary(api_key) -> :ok
      %{service_account_key: _} -> :ok
      %{credentials: %{}} -> :ok
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Configure authentication for the Gemini adapter.
  """
  def configure(auth_type, credentials) do
    Auth.configure(auth_type, credentials)
  end

  @doc """
  Get available models with detailed information.
  """
  def get_model(model_name, opts \\ []) do
    with {:ok, auth_config} <- Auth.get_auth_config(),
         {:ok, model} <- Client.get_model(model_name, auth_config, opts) do
      {:ok, model}
    end
  end

  @doc """
  Count tokens for the given content.
  """
  def count_tokens(%Conversation{} = conversation, opts \\ []) do
    with {:ok, auth_config} <- Auth.get_auth_config(),
         {:ok, request} <- Mapper.conversation_to_request(conversation),
         {:ok, response} <- Client.count_tokens(request, auth_config, opts) do
      {:ok, response}
    end
  end
end
