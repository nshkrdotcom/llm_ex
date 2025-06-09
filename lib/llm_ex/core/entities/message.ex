defmodule LLMEx.Core.Entities.Message do
  @moduledoc """
  Core message entity representing a single message in a conversation.
  """

  defstruct [
    :role,
    :content,
    :timestamp,
    :metadata
  ]

  @type content_part :: text_content() | image_content()

  @type text_content :: %{
          type: :text,
          text: String.t()
        }

  @type image_content :: %{
          type: :image_url | :image,
          image_url: image_url() | nil,
          image: image_data() | nil
        }

  @type image_url :: %{
          url: String.t(),
          detail: :auto | :low | :high | nil
        }

  @type image_data :: %{
          data: String.t(),
          media_type: String.t()
        }

  @type t :: %__MODULE__{
          role: String.t(),
          content: String.t() | list(content_part()),
          timestamp: DateTime.t() | nil,
          metadata: map() | nil
        }

  @doc """
  Creates a new message with the given role and content.
  """
  def new(role, content, opts \\ []) do
    %__MODULE__{
      role: role,
      content: content,
      timestamp: opts[:timestamp] || DateTime.utc_now(),
      metadata: opts[:metadata] || %{}
    }
  end

  @doc """
  Creates a user message.
  """
  def user(content, opts \\ []) do
    new("user", content, opts)
  end

  @doc """
  Creates an assistant message.
  """
  def assistant(content, opts \\ []) do
    new("assistant", content, opts)
  end

  @doc """
  Creates a system message.
  """
  def system(content, opts \\ []) do
    new("system", content, opts)
  end
end
