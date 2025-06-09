defmodule Gemini.Types.Blob do
  @moduledoc """
  Binary data with MIME type for Gemini API.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field(:data, String.t(), enforce: true)
    field(:mime_type, String.t(), enforce: true)
  end

  @typedoc "Base64 encoded binary data."
  @type blob_data :: String.t()

  @typedoc "MIME type of the data."
  @type mime_type :: String.t()

  @doc """
  Create a new blob with base64 encoded data.
  """
  @spec new(String.t(), String.t()) :: t()
  def new(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    encoded_data = Base.encode64(data)

    %__MODULE__{
      data: encoded_data,
      mime_type: mime_type
    }
  end

  @doc """
  Create a blob from a file path.
  """
  @spec from_file(String.t()) :: {:ok, t()} | {:error, Gemini.Error.t()}
  def from_file(file_path) do
    case File.read(file_path) do
      {:ok, data} ->
        mime_type = determine_mime_type(file_path)
        {:ok, new(data, mime_type)}

      {:error, reason} ->
        {:error, Gemini.Error.new(:file_error, "Could not read file: #{reason}")}
    end
  end

  # Simple MIME type detection based on file extension
  defp determine_mime_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".pdf" -> "application/pdf"
      ".mp4" -> "video/mp4"
      ".avi" -> "video/avi"
      ".mov" -> "video/mov"
      ".mp3" -> "audio/mp3"
      ".wav" -> "audio/wav"
      _ -> "application/octet-stream"
    end
  end
end
