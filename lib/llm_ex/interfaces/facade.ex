defmodule LLMEx.Interfaces.Facade do
  @moduledoc """
  Main facade for the LLMEx library providing a unified interface.
  """

  alias LLMEx.Core.UseCases.Chat
  alias LLMEx.Core.Services.ProviderRegistry

  @doc """
  Send a chat message to the specified provider.

  ## Examples

      messages = [%{role: "user", content: "Hello!"}]
      {:ok, response} = LLMEx.Interfaces.Facade.chat(:gemini, "gemini-pro", messages)
  """
  def chat(provider, messages, opts \\ [])

  def chat(provider, messages, opts) when is_list(messages) do
    model = opts[:model] || default_model_for_provider(provider)
    Chat.send_message(provider, model, messages, opts)
  end

  def chat(provider, model, messages) when is_binary(model) and is_list(messages) do
    Chat.send_message(provider, model, messages, [])
  end

  @doc """
  Start a streaming chat with the specified provider.

  ## Examples

      messages = [%{role: "user", content: "Tell me a story"}]
      {:ok, stream} = LLMEx.Interfaces.Facade.stream_chat(:gemini, messages)

      for chunk <- stream do
        IO.write(chunk.content)
      end
  """
  def stream_chat(provider, messages, opts \\ [])

  def stream_chat(provider, messages, opts) when is_list(messages) do
    model = opts[:model] || default_model_for_provider(provider)
    Chat.stream_message(provider, model, messages, opts)
  end

  def stream_chat(provider, model, messages) when is_binary(model) and is_list(messages) do
    Chat.stream_message(provider, model, messages, [])
  end

  @doc """
  List available models for a provider.

  ## Examples

      {:ok, models} = LLMEx.Interfaces.Facade.list_models(:gemini)
  """
  def list_models(provider, opts \\ []) do
    with {:ok, adapter} <- ProviderRegistry.get_adapter(provider) do
      adapter.list_models(opts)
    end
  end

  @doc """
  List all registered providers.
  """
  def list_providers do
    ProviderRegistry.list_providers()
  end

  @doc """
  Register a new provider adapter.
  """
  def register_provider(provider_name, adapter_module, config \\ %{}) do
    ProviderRegistry.register_provider(provider_name, adapter_module, config)
  end

  # Private helpers

  defp default_model_for_provider(:openai), do: "gpt-3.5-turbo"
  defp default_model_for_provider(:anthropic), do: "claude-3-sonnet-20240229"
  defp default_model_for_provider(:gemini), do: "gemini-1.5-pro"
  defp default_model_for_provider(:ollama), do: "llama2"
  defp default_model_for_provider(:groq), do: "mixtral-8x7b-32768"
  defp default_model_for_provider(_), do: "default"
end
