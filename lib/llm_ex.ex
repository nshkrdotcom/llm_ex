defmodule LLMEx do
  @moduledoc """
  LLMEx - Unified Elixir client library for Large Language Models.

  This library provides a consistent interface across multiple LLM providers
  with advanced features like multi-authentication, streaming, and clean
  architecture patterns.

  ## Quick Start

      # Simple chat
      messages = [%{role: "user", content: "Hello!"}]
      {:ok, response} = LLMEx.chat(:openai, messages)

      # Streaming
      LLMEx.stream_chat(:anthropic, messages)
      |> Stream.each(&IO.write(&1.content))
      |> Stream.run()

  ## Supported Providers

  - `:openai` - OpenAI GPT models
  - `:anthropic` - Anthropic Claude models
  - `:gemini` - Google Gemini (API + Vertex AI)
  - `:ollama` - Local models via Ollama
  - And many more...
  """

  # Main public API - delegating to facade
  def chat(provider, messages, opts \\ []) do
    LLMEx.Interfaces.Facade.chat(provider, messages, opts)
  end

  def stream_chat(provider, messages, opts \\ []) do
    LLMEx.Interfaces.Facade.stream_chat(provider, messages, opts)
  end

  def list_models(provider, opts \\ []) do
    LLMEx.Interfaces.Facade.list_models(provider, opts)
  end

  def providers do
    case LLMEx.Interfaces.Facade.list_providers() do
      {:ok, providers} -> providers
      _ -> [:openai, :anthropic, :gemini, :ollama, :groq, :mistral, :bedrock, :bumblebee, :lmstudio, :openai_compatible, :openrouter, :perplexity, :xai, :mock]
    end
  end
end
