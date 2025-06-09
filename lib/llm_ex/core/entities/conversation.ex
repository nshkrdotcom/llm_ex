defmodule LLMEx.Core.Entities.Conversation do
  @moduledoc """
  Core conversation entity representing a chat session.
  """

  alias LLMEx.Core.Entities.Message

  defstruct [
    :id,
    :messages,
    :provider,
    :model,
    :config,
    :context,
    :created_at,
    :updated_at,
    :status,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          messages: [Message.t()],
          provider: atom(),
          model: String.t(),
          config: map(),
          context: map() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: :active | :completed | :error,
          metadata: map()
        }

  @doc """
  Creates a new conversation.
  """
  def new(provider, model, opts \\ []) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: generate_id(),
      messages: opts[:messages] || [],
      provider: provider,
      model: model,
      config: opts[:config] || %{},
      context: opts[:context],
      created_at: now,
      updated_at: now,
      status: :active,
      metadata: opts[:metadata] || %{}
    }
  end

  @doc """
  Adds a message to the conversation.
  """
  def add_message(%__MODULE__{} = conversation, %Message{} = message) do
    %{conversation |
      messages: conversation.messages ++ [message],
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Adds a message to the conversation with role and content.
  """
  def add_message(%__MODULE__{} = conversation, role, content, opts \\ []) do
    message = Message.new(role, content, opts)
    add_message(conversation, message)
  end

  @doc """
  Gets the last message in the conversation.
  """
  def last_message(%__MODULE__{messages: []}), do: nil
  def last_message(%__MODULE__{messages: messages}), do: List.last(messages)

  @doc """
  Gets messages with a specific role.
  """
  def messages_by_role(%__MODULE__{messages: messages}, role) do
    Enum.filter(messages, &(&1.role == role))
  end

  @doc """
  Counts total messages in the conversation.
  """
  def message_count(%__MODULE__{messages: messages}), do: length(messages)

  @doc """
  Marks the conversation as completed.
  """
  def complete(%__MODULE__{} = conversation) do
    %{conversation |
      status: :completed,
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Marks the conversation as having an error.
  """
  def error(%__MODULE__{} = conversation, error_info \\ %{}) do
    %{conversation |
      status: :error,
      updated_at: DateTime.utc_now(),
      metadata: Map.put(conversation.metadata, :error, error_info)
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> binary_part(0, 16)
  end
end
