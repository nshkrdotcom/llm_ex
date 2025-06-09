defmodule LLMEx.Core.UseCases.Chat do
  @moduledoc """
  Use case for handling chat interactions with LLM providers.
  """

  alias LLMEx.Core.Entities.{Conversation, Message, LLMResponse}
  alias LLMEx.Core.Ports.ProviderAdapter
  alias LLMEx.Core.Services.ProviderRegistry

  @doc """
  Sends a chat message to the specified provider.
  """
  def send_message(provider, model, messages, opts \\ []) when is_list(messages) do
    with {:ok, conversation} <- create_conversation(provider, model, messages, opts),
         {:ok, adapter} <- ProviderRegistry.get_adapter(provider),
         {:ok, response} <- adapter.chat(conversation, opts) do
      {:ok, response}
    end
  end

  @doc """
  Starts a streaming chat with the specified provider.
  """
  def stream_message(provider, model, messages, opts \\ []) when is_list(messages) do
    with {:ok, conversation} <- create_conversation(provider, model, messages, opts),
         {:ok, adapter} <- ProviderRegistry.get_adapter(provider),
         {:ok, stream} <- adapter.stream_chat(conversation, opts) do
      {:ok, stream}
    end
  end

  @doc """
  Continues an existing conversation with a new message.
  """
  def continue_conversation(%Conversation{} = conversation, role, content, opts \\ []) do
    updated_conversation =
      conversation
      |> Conversation.add_message(role, content, opts)

    with {:ok, adapter} <- ProviderRegistry.get_adapter(conversation.provider),
         {:ok, response} <- adapter.chat(updated_conversation, opts) do
      {:ok, response, updated_conversation}
    end
  end

  @doc """
  Validates that a provider supports the requested capabilities.
  """
  def validate_request(provider, _model, _messages, opts) do
    with {:ok, provider_config} <- ProviderRegistry.get_provider(provider) do
      cond do
        opts[:stream] && not provider_config.supports?(:streaming) ->
          {:error, :streaming_not_supported}

        opts[:tools] && not provider_config.supports?(:function_calling) ->
          {:error, :function_calling_not_supported}

        has_images_in_messages?(opts[:messages] || []) && not provider_config.supports?(:vision) ->
          {:error, :vision_not_supported}

        true ->
          :ok
      end
    end
  end

  # Private helpers

  defp create_conversation(provider, model, messages, opts) do
    conversation = Conversation.new(provider, model, opts)

    # Convert raw message maps to Message entities
    normalized_messages =
      messages
      |> Enum.map(&normalize_message/1)

    updated_conversation = %{conversation | messages: normalized_messages}
    {:ok, updated_conversation}
  end

  defp normalize_message(%Message{} = message), do: message
  defp normalize_message(%{role: role, content: content} = msg) do
    Message.new(role, content, Map.drop(msg, [:role, :content]))
  end

  defp has_images_in_messages?(messages) do
    Enum.any?(messages, fn message ->
      case message.content do
        content when is_list(content) ->
          Enum.any?(content, &(&1[:type] in [:image, :image_url]))
        _ ->
          false
      end
    end)
  end
end
