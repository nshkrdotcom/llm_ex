defmodule Gemini.Types.SafetySetting do
  @moduledoc """
  Safety settings for content generation.
  """

  use TypedStruct

  @type category ::
          :harm_category_harassment
          | :harm_category_hate_speech
          | :harm_category_sexually_explicit
          | :harm_category_dangerous_content

  @type threshold ::
          :harm_block_threshold_unspecified
          | :block_low_and_above
          | :block_medium_and_above
          | :block_only_high
          | :block_none

  @derive Jason.Encoder
  typedstruct do
    field(:category, category(), enforce: true)
    field(:threshold, threshold(), enforce: true)
  end

  @doc """
  Create a safety setting for harassment content.
  """
  def harassment(threshold \\ :block_medium_and_above) do
    %__MODULE__{
      category: :harm_category_harassment,
      threshold: threshold
    }
  end

  @doc """
  Create a safety setting for hate speech content.
  """
  def hate_speech(threshold \\ :block_medium_and_above) do
    %__MODULE__{
      category: :harm_category_hate_speech,
      threshold: threshold
    }
  end

  @doc """
  Create a safety setting for sexually explicit content.
  """
  def sexually_explicit(threshold \\ :block_medium_and_above) do
    %__MODULE__{
      category: :harm_category_sexually_explicit,
      threshold: threshold
    }
  end

  @doc """
  Create a safety setting for dangerous content.
  """
  def dangerous_content(threshold \\ :block_medium_and_above) do
    %__MODULE__{
      category: :harm_category_dangerous_content,
      threshold: threshold
    }
  end

  @doc """
  Get default safety settings (medium threshold for all categories).
  """
  def defaults do
    [
      harassment(),
      hate_speech(),
      sexually_explicit(),
      dangerous_content()
    ]
  end

  @doc """
  Get permissive safety settings (block only high risk content).
  """
  def permissive do
    [
      harassment(:block_only_high),
      hate_speech(:block_only_high),
      sexually_explicit(:block_only_high),
      dangerous_content(:block_only_high)
    ]
  end
end
