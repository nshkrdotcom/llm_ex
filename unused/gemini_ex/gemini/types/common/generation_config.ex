defmodule Gemini.Types.GenerationConfig do
  @moduledoc """
  Configuration for content generation parameters.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:stop_sequences, [String.t()], default: [])
    field(:response_mime_type, String.t() | nil, default: nil)
    field(:response_schema, map() | nil, default: nil)
    field(:candidate_count, integer() | nil, default: nil)
    field(:max_output_tokens, integer() | nil, default: nil)
    field(:temperature, float() | nil, default: nil)
    field(:top_p, float() | nil, default: nil)
    field(:top_k, integer() | nil, default: nil)
    field(:presence_penalty, float() | nil, default: nil)
    field(:frequency_penalty, float() | nil, default: nil)
    field(:response_logprobs, boolean() | nil, default: nil)
    field(:logprobs, integer() | nil, default: nil)
  end

  @doc """
  Create a new generation config with default values.
  """
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Create a creative generation config (higher temperature).
  """
  def creative(opts \\ []) do
    defaults = [
      temperature: 0.9,
      top_p: 1.0,
      top_k: 40
    ]

    struct(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc """
  Create a balanced generation config.
  """
  def balanced(opts \\ []) do
    defaults = [
      temperature: 0.7,
      top_p: 0.95,
      top_k: 40
    ]

    struct(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc """
  Create a precise generation config (lower temperature).
  """
  def precise(opts \\ []) do
    defaults = [
      temperature: 0.2,
      top_p: 0.8,
      top_k: 10
    ]

    struct(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc """
  Create a deterministic generation config.
  """
  def deterministic(opts \\ []) do
    defaults = [
      temperature: 0.0,
      candidate_count: 1
    ]

    struct(__MODULE__, Keyword.merge(defaults, opts))
  end

  @doc """
  Set JSON response format.
  """
  def json_response(config \\ %__MODULE__{}) do
    %{config | response_mime_type: "application/json"}
  end

  @doc """
  Set plain text response format.
  """
  def text_response(config \\ %__MODULE__{}) do
    %{config | response_mime_type: "text/plain"}
  end

  @doc """
  Set maximum output tokens.
  """
  def max_tokens(config \\ %__MODULE__{}, tokens) when is_integer(tokens) and tokens > 0 do
    %{config | max_output_tokens: tokens}
  end

  @doc """
  Add stop sequences.
  """
  def stop_sequences(config \\ %__MODULE__{}, sequences) when is_list(sequences) do
    %{config | stop_sequences: sequences}
  end
end
