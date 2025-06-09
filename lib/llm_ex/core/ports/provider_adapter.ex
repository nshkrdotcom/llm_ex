defmodule LLMEx.Core.Ports.ProviderAdapter do
  @moduledoc """
  Port defining the contract for LLM provider adapters.
  """

  alias LLMEx.Core.Entities.{Conversation, LLMResponse, StreamChunk}

  @callback chat(Conversation.t(), keyword()) :: {:ok, LLMResponse.t()} | {:error, term()}

  @callback stream_chat(Conversation.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}

  @callback list_models(keyword()) :: {:ok, [String.t()]} | {:error, term()}

  @callback validate_config(map()) :: :ok | {:error, term()}

  @optional_callbacks [stream_chat: 2, list_models: 1]
end
