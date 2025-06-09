defmodule LLMEx.Adapters.Providers.Gemini.Mapper do
  @moduledoc """
  Mappers for converting between LLMEx entities and Gemini API formats.
  """

  alias LLMEx.Core.Entities.{Conversation, Message, LLMResponse, StreamChunk}

  @doc """
  Converts a Conversation to a Gemini API request format.
  """
  def conversation_to_request(%Conversation{} = conversation) do
    contents = Enum.map(conversation.messages, &message_to_content/1)

    request = %{
      contents: contents,
      generation_config: conversation.config[:generation_config] || %{},
      safety_settings: conversation.config[:safety_settings] || [],
      tools: conversation.config[:tools] || []
    }

    {:ok, request}
  end

  @doc """
  Converts a Gemini API response to an LLMResponse entity.
  """
  def response_to_llm_response(response, %Conversation{} = conversation) do
    content = extract_text_from_response(response)

    usage = case response[:usage_metadata] do
      nil -> nil
      metadata -> %{
        input_tokens: metadata[:prompt_token_count] || 0,
        output_tokens: metadata[:candidates_token_count] || 0
      }
    end

    llm_response = LLMResponse.new(%{
      content: content,
      model: conversation.model,
      usage: usage,
      finish_reason: get_finish_reason(response),
      id: generate_id(),
      provider: :gemini,
      metadata: %{
        original_response: response
      }
    })

    {:ok, llm_response}
  end

  @doc """
  Converts a Gemini streaming chunk to a StreamChunk entity.
  """
  def chunk_to_stream_chunk(chunk, %Conversation{} = conversation) do
    content = extract_text_from_response(chunk)

    stream_chunk = StreamChunk.new(%{
      content: content,
      model: conversation.model,
      finish_reason: get_finish_reason(chunk),
      provider: :gemini,
      metadata: %{
        original_chunk: chunk
      }
    })

    {:ok, stream_chunk}
  end

  # Private helpers

  defp message_to_content(%Message{role: "user", content: content}) do
    %{
      role: "user",
      parts: content_to_parts(content)
    }
  end

  defp message_to_content(%Message{role: "assistant", content: content}) do
    %{
      role: "model",
      parts: content_to_parts(content)
    }
  end

  defp message_to_content(%Message{role: "system", content: content}) do
    # Gemini doesn't have system role, prepend to first user message
    %{
      role: "user",
      parts: [%{text: "[System]: #{content}"}]
    }
  end

  defp content_to_parts(content) when is_binary(content) do
    [%{text: content}]
  end

  defp content_to_parts(content) when is_list(content) do
    Enum.map(content, fn
      %{type: :text, text: text} -> %{text: text}
      %{type: :image_url, image_url: %{url: url}} -> %{inline_data: %{mime_type: "image/jpeg", data: url}}
      part -> part
    end)
  end

  defp extract_text_from_response(%{candidates: [%{content: %{parts: [%{text: text} | _]}} | _]}) do
    text
  end

  defp extract_text_from_response(_), do: ""

  defp get_finish_reason(%{candidates: [%{finish_reason: reason} | _]}) when reason != nil do
    String.downcase(reason)
  end

  defp get_finish_reason(_), do: nil

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode64() |> binary_part(0, 8)
  end
end
