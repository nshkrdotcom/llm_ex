defmodule LLMEx.Core.Entities.StreamChunk do
  @moduledoc """
  Core entity representing a chunk from a streaming LLM response.
  """

  defstruct [
    :content,
    :finish_reason,
    :model,
    :id,
    :metadata,
    :provider,
    :created_at
  ]

  @type t :: %__MODULE__{
          content: String.t() | nil,
          finish_reason: String.t() | nil,
          model: String.t() | nil,
          id: String.t() | nil,
          metadata: map() | nil,
          provider: atom() | nil,
          created_at: DateTime.t() | nil
        }

  @doc """
  Creates a new stream chunk.
  """
  def new(attrs \\ %{}) do
    attrs
    |> Map.put_new(:created_at, DateTime.utc_now())
    |> then(&struct(__MODULE__, &1))
  end

  @doc """
  Checks if this chunk indicates the stream is finished.
  """
  def finished?(%__MODULE__{finish_reason: nil}), do: false
  def finished?(%__MODULE__{finish_reason: _}), do: true

  @doc """
  Checks if this chunk has content.
  """
  def has_content?(%__MODULE__{content: nil}), do: false
  def has_content?(%__MODULE__{content: ""}), do: false
  def has_content?(%__MODULE__{content: _}), do: true
end
