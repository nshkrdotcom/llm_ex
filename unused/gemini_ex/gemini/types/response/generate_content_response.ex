defmodule Gemini.Types.Response do
  @moduledoc """
  Response types for the Gemini API.
  """
end

defmodule Gemini.Types.Response.GenerateContentResponse do
  @moduledoc """
  Response from content generation.
  """

  use TypedStruct

  alias Gemini.Types.Response.{Candidate, PromptFeedback, UsageMetadata}

  @derive Jason.Encoder
  typedstruct do
    field(:candidates, [Candidate.t()], default: [])
    field(:prompt_feedback, PromptFeedback.t() | nil, default: nil)
    field(:usage_metadata, UsageMetadata.t() | nil, default: nil)
  end

  @doc """
  Extract text content from the response.
  """
  @spec extract_text(t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_text(%__MODULE__{candidates: [first_candidate | _]}) do
    case first_candidate do
      %{content: %{parts: [_ | _] = parts}} ->
        text =
          parts
          |> Enum.filter(&Map.has_key?(&1, :text))
          |> Enum.map_join("", & &1.text)

        {:ok, text}

      _ ->
        {:error, "No text content found in response"}
    end
  end

  def extract_text(_), do: {:error, "No candidates found in response"}

  @doc """
  Get the finish reason from the first candidate.
  """
  @spec finish_reason(t()) :: String.t() | nil
  def finish_reason(%__MODULE__{candidates: [%{finish_reason: reason} | _]}), do: reason
  def finish_reason(_), do: nil

  @doc """
  Get token usage information from the response.
  """
  @spec token_usage(t()) :: map() | nil
  def token_usage(%__MODULE__{usage_metadata: %{} = usage}) do
    %{
      total: Map.get(usage, :total_token_count),
      input: Map.get(usage, :prompt_token_count),
      output: Map.get(usage, :candidates_token_count)
    }
  end

  def token_usage(_), do: nil
end

defmodule Gemini.Types.Response.CountTokensResponse do
  @moduledoc """
  Response from counting tokens.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:total_tokens, integer(), enforce: true)
  end
end

defmodule Gemini.Types.Response.Candidate do
  @moduledoc """
  Content candidate in response.
  """

  use TypedStruct

  alias Gemini.Types.Content
  alias Gemini.Types.Response.{SafetyRating, CitationMetadata, GroundingAttribution}

  @derive Jason.Encoder
  typedstruct do
    field(:content, Content.t() | nil, default: nil)
    field(:finish_reason, String.t() | nil, default: nil)
    field(:safety_ratings, [SafetyRating.t()], default: [])
    field(:citation_metadata, CitationMetadata.t() | nil, default: nil)
    field(:token_count, integer() | nil, default: nil)
    field(:grounding_attributions, [GroundingAttribution.t()], default: [])
    field(:index, integer() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.PromptFeedback do
  @moduledoc """
  Prompt feedback information.
  """

  use TypedStruct

  alias Gemini.Types.Response.SafetyRating

  @derive Jason.Encoder
  typedstruct do
    field(:block_reason, String.t() | nil, default: nil)
    field(:safety_ratings, [SafetyRating.t()], default: [])
  end
end

defmodule Gemini.Types.Response.UsageMetadata do
  @moduledoc """
  Usage metadata for API calls.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:prompt_token_count, integer() | nil, default: nil)
    field(:candidates_token_count, integer() | nil, default: nil)
    field(:total_token_count, integer(), enforce: true)
    field(:cached_content_token_count, integer() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.SafetyRating do
  @moduledoc """
  Safety rating for content.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:category, String.t(), enforce: true)
    field(:probability, String.t(), enforce: true)
    field(:blocked, boolean() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.CitationMetadata do
  @moduledoc """
  Citation metadata for generated content.
  """

  use TypedStruct

  alias Gemini.Types.Response.CitationSource

  @derive Jason.Encoder
  typedstruct do
    field(:citation_sources, [CitationSource.t()], default: [])
  end
end

defmodule Gemini.Types.Response.CitationSource do
  @moduledoc """
  Citation source information.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:start_index, integer() | nil, default: nil)
    field(:end_index, integer() | nil, default: nil)
    field(:uri, String.t() | nil, default: nil)
    field(:license, String.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.GroundingAttribution do
  @moduledoc """
  Grounding attribution information.
  """

  use TypedStruct

  alias Gemini.Types.Content
  alias Gemini.Types.Response.GroundingAttributionSourceId

  @derive Jason.Encoder
  typedstruct do
    field(:source_id, GroundingAttributionSourceId.t() | nil, default: nil)
    field(:content, Content.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.GroundingAttributionSourceId do
  @moduledoc """
  Grounding attribution source ID.
  """

  use TypedStruct

  alias Gemini.Types.Response.{GroundingPassageId, SemanticRetrieverChunk}

  @derive Jason.Encoder
  typedstruct do
    field(:grounding_passage, GroundingPassageId.t() | nil, default: nil)
    field(:semantic_retriever_chunk, SemanticRetrieverChunk.t() | nil, default: nil)
  end
end

defmodule Gemini.Types.Response.GroundingPassageId do
  @moduledoc """
  Grounding passage ID.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:passage_id, String.t(), enforce: true)
    field(:part_index, integer(), enforce: true)
  end
end

defmodule Gemini.Types.Response.SemanticRetrieverChunk do
  @moduledoc """
  Semantic retriever chunk information.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:source, String.t(), enforce: true)
    field(:chunk, String.t(), enforce: true)
  end
end
