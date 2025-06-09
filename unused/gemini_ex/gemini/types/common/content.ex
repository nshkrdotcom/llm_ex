defmodule Gemini.Types.Content do
  @moduledoc """
  Content type for Gemini API requests and responses.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:role, String.t(), default: "user")
    field(:parts, [Gemini.Types.Part.t()], default: [])
  end

  @typedoc "The role of the content creator."
  @type role :: String.t()

  @typedoc "Ordered parts that constitute a single message."
  @type parts :: [Gemini.Types.Part.t()]

  @doc """
  Create content with text.
  """
  @spec text(String.t(), String.t()) :: t()
  def text(text, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [Gemini.Types.Part.text(text)]
    }
  end

  @doc """
  Create content with text and image.
  """
  @spec multimodal(String.t(), String.t(), String.t(), String.t()) :: t()
  def multimodal(text, image_data, mime_type, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [
        Gemini.Types.Part.text(text),
        Gemini.Types.Part.inline_data(image_data, mime_type)
      ]
    }
  end

  @doc """
  Create content with an image from a file path.
  """
  @spec image(String.t(), String.t()) :: t()
  def image(path, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [Gemini.Types.Part.file(path)]
    }
  end
end
