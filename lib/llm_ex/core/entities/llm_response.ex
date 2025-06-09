defmodule LLMEx.Core.Entities.LLMResponse do
  @moduledoc """
  Core entity representing a response from an LLM provider.
  """

  defstruct [
    :content,
    :model,
    :usage,
    :finish_reason,
    :id,
    :cost,
    :function_call,
    :tool_calls,
    :refusal,
    :logprobs,
    :metadata,
    :provider,
    :created_at
  ]

  @type token_usage :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer()
        }

  @type cost_result :: %{
          provider: String.t(),
          model: String.t(),
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          total_tokens: non_neg_integer(),
          input_cost: float(),
          output_cost: float(),
          total_cost: float(),
          currency: String.t(),
          pricing: %{input: float(), output: float()}
        }

  @type t :: %__MODULE__{
          content: String.t() | nil,
          model: String.t() | nil,
          usage: token_usage() | nil,
          finish_reason: String.t() | nil,
          id: String.t() | nil,
          cost: cost_result() | nil,
          function_call: map() | nil,
          tool_calls: list(map()) | nil,
          refusal: String.t() | nil,
          logprobs: map() | nil,
          metadata: map() | nil,
          provider: atom() | nil
        }

  @doc """
  Creates a new LLM response.
  """
  def new(attrs \\ %{}) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Checks if the response is complete (has finish_reason).
  """
  def complete?(%__MODULE__{finish_reason: nil}), do: false
  def complete?(%__MODULE__{finish_reason: _}), do: true

  @doc """
  Gets the total tokens used in the response.
  """
  def total_tokens(%__MODULE__{usage: nil}), do: 0
  def total_tokens(%__MODULE__{usage: %{input_tokens: input, output_tokens: output}}) do
    input + output
  end
end
