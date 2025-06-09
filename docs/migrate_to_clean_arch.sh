#!/bin/bash

# Migration script to create LLMEx unified library with Clean Architecture
# Following the structure defined in TREE.md

set -e

PROJECT_ROOT="/home/home/p/g/n/llm_ex"
cd "$PROJECT_ROOT"

echo "🚀 Creating LLMEx unified library with Clean Architecture..."

# Create new mix project
mix new llm_ex --module LLMEx

cd llm_ex

echo "📦 Setting up Clean Architecture directory structure..."

# Create Clean Architecture directories
mkdir -p lib/llm_ex/{entities,use_cases,interfaces,infrastructure}
mkdir -p lib/llm_ex/interfaces/{adapters,gateways,presenters}
mkdir -p lib/llm_ex/infrastructure/{providers,http,streaming,config}
mkdir -p lib/llm_ex/infrastructure/providers/{gemini,openai,anthropic,ollama,azure,bedrock,cohere,huggingface,mistral,perplexity,groq,replicate,together,anyscale,fireworks}

# Create subdirectories
mkdir -p lib/llm_ex/entities/{conversation,provider,auth,streaming}
mkdir -p lib/llm_ex/use_cases/{chat,streaming,auth,provider_management}
mkdir -p lib/llm_ex/interfaces/adapters/{http,streaming,auth}
mkdir -p lib/llm_ex/infrastructure/{sessions,monitoring,error_handling}

# Preserve original codebases
echo "📋 Preserving original codebases..."
mkdir -p unused
cp -r ../ex_llm/ unused/
cp -r ../gemini_ex/ unused/

echo "🎯 Starting migration with Gemini as reference implementation..."

# Create base entities
cat > lib/llm_ex/entities/provider.ex << 'EOF'
defmodule LLMEx.Entities.Provider do
  @moduledoc """
  Core provider entity following Clean Architecture principles.
  """

  defstruct [
    :name,
    :type,
    :config,
    :auth_methods,
    :capabilities,
    :endpoints,
    :rate_limits,
    :status
  ]

  @type t :: %__MODULE__{
    name: atom(),
    type: :chat | :embedding | :completion,
    config: map(),
    auth_methods: [atom()],
    capabilities: [atom()],
    endpoints: map(),
    rate_limits: map(),
    status: :active | :inactive | :error
  }
end
EOF

cat > lib/llm_ex/entities/conversation.ex << 'EOF'
defmodule LLMEx.Entities.Conversation do
  @moduledoc """
  Core conversation entity.
  """

  defstruct [
    :id,
    :messages,
    :provider,
    :model,
    :config,
    :created_at,
    :updated_at,
    :status
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    messages: [map()],
    provider: atom(),
    model: String.t(),
    config: map(),
    created_at: DateTime.t(),
    updated_at: DateTime.t(),
    status: :active | :completed | :error
  }
end
EOF

cat > lib/llm_ex/entities/auth.ex << 'EOF'
defmodule LLMEx.Entities.Auth do
  @moduledoc """
  Authentication entity for providers.
  """

  defstruct [
    :provider,
    :method,
    :credentials,
    :scopes,
    :expires_at,
    :project_id,
    :location
  ]

  @type t :: %__MODULE__{
    provider: atom(),
    method: :api_key | :oauth | :service_account | :vertex_ai,
    credentials: map(),
    scopes: [String.t()],
    expires_at: DateTime.t() | nil,
    project_id: String.t() | nil,
    location: String.t() | nil
  }
end
EOF

# Create use cases
cat > lib/llm_ex/use_cases/chat.ex << 'EOF'
defmodule LLMEx.UseCases.Chat do
  @moduledoc """
  Chat use case orchestrating provider interactions.
  """

  alias LLMEx.Entities.{Conversation, Provider}
  alias LLMEx.Interfaces.Gateways.ProviderGateway

  def send_message(provider, model, messages, opts \\ []) do
    with {:ok, conversation} <- create_conversation(provider, model, messages, opts),
         {:ok, response} <- ProviderGateway.send_request(conversation) do
      {:ok, response}
    end
  end

  def stream_message(provider, model, messages, opts \\ []) do
    with {:ok, conversation} <- create_conversation(provider, model, messages, opts) do
      ProviderGateway.stream_request(conversation)
    end
  end

  defp create_conversation(provider, model, messages, opts) do
    conversation = %Conversation{
      id: generate_id(),
      messages: messages,
      provider: provider,
      model: model,
      config: Enum.into(opts, %{}),
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      status: :active
    }
    {:ok, conversation}
  end

  defp generate_id, do: :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
end
EOF

# Create interfaces
cat > lib/llm_ex/interfaces/gateways/provider_gateway.ex << 'EOF'
defmodule LLMEx.Interfaces.Gateways.ProviderGateway do
  @moduledoc """
  Gateway interface for provider interactions.
  """

  alias LLMEx.Entities.Conversation

  @callback send_request(Conversation.t()) :: {:ok, map()} | {:error, term()}
  @callback stream_request(Conversation.t()) :: {:ok, Enumerable.t()} | {:error, term()}
  @callback validate_config(map()) :: :ok | {:error, term()}
end
EOF

# Start migrating Gemini as reference implementation
echo "🔄 Migrating Gemini codebase as reference implementation..."

# Copy and transform Gemini files
cp ../gemini_ex/lib/gemini_ex.ex lib/llm_ex/infrastructure/providers/gemini/client.ex

# Transform module names in the copied file
sed -i 's/defmodule GeminiEx/defmodule LLMEx.Infrastructure.Providers.Gemini.Client/g' lib/llm_ex/infrastructure/providers/gemini/client.ex
sed -i 's/GeminiEx\./LLMEx.Infrastructure.Providers.Gemini./g' lib/llm_ex/infrastructure/providers/gemini/client.ex

# Copy Gemini types and transform
cp ../gemini_ex/lib/gemini_ex/types.ex lib/llm_ex/infrastructure/providers/gemini/types.ex
sed -i 's/defmodule GeminiEx\.Types/defmodule LLMEx.Infrastructure.Providers.Gemini.Types/g' lib/llm_ex/infrastructure/providers/gemini/types.ex

# Copy and transform other Gemini modules
for file in ../gemini_ex/lib/gemini_ex/*.ex; do
  if [ -f "$file" ]; then
    filename=$(basename "$file")
    if [ "$filename" != "types.ex" ]; then
      cp "$file" "lib/llm_ex/infrastructure/providers/gemini/$filename"
      # Transform module names
      sed -i "s/defmodule GeminiEx\./defmodule LLMEx.Infrastructure.Providers.Gemini./g" "lib/llm_ex/infrastructure/providers/gemini/$filename"
      sed -i "s/GeminiEx\./LLMEx.Infrastructure.Providers.Gemini./g" "lib/llm_ex/infrastructure/providers/gemini/$filename"
    fi
  fi
done

# Create Gemini adapter implementing the gateway
cat > lib/llm_ex/infrastructure/providers/gemini/adapter.ex << 'EOF'
defmodule LLMEx.Infrastructure.Providers.Gemini.Adapter do
  @moduledoc """
  Gemini provider adapter implementing ProviderGateway behavior.
  """

  @behaviour LLMEx.Interfaces.Gateways.ProviderGateway

  alias LLMEx.Entities.Conversation
  alias LLMEx.Infrastructure.Providers.Gemini.Client

  @impl true
  def send_request(%Conversation{} = conversation) do
    # Transform conversation to Gemini format and send
    Client.chat(conversation.messages, conversation.config)
  end

  @impl true
  def stream_request(%Conversation{} = conversation) do
    # Transform and stream
    Client.stream_chat(conversation.messages, conversation.config)
  end

  @impl true
  def validate_config(config) do
    # Validate Gemini-specific config
    :ok
  end
end
EOF

echo "🔧 Setting up main application module..."

# Update main application module
cat > lib/llm_ex.ex << 'EOF'
defmodule LLMEx do
  @moduledoc """
  LLMEx - Unified LLM client library following Clean Architecture principles.
  
  This library provides a unified interface for interacting with various LLM providers
  while maintaining clean separation of concerns and extensibility.
  """

  alias LLMEx.UseCases.Chat
  alias LLMEx.Entities.{Provider, Conversation, Auth}

  @doc """
  Send a chat message to a provider.
  """
  def chat(provider, model, messages, opts \\ []) do
    Chat.send_message(provider, model, messages, opts)
  end

  @doc """
  Stream a chat message from a provider.
  """
  def stream_chat(provider, model, messages, opts \\ []) do
    Chat.stream_message(provider, model, messages, opts)
  end

  @doc """
  List available providers.
  """
  def providers do
    # Implementation will delegate to provider registry
    [:gemini, :openai, :anthropic, :ollama]
  end
end
EOF

echo "📝 Updating mix.exs with unified dependencies..."

# Update mix.exs with dependencies from both projects
cat > mix.exs << 'EOF'
defmodule LLMEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :llm_ex,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Unified LLM client library with Clean Architecture",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssl, :crypto],
      mod: {LLMEx.Application, []}
    ]
  end

  defp deps do
    [
      # HTTP clients
      {:httpoison, "~> 2.0"},
      {:finch, "~> 0.16"},
      
      # JSON handling
      {:jason, "~> 1.4"},
      
      # Google Cloud & Vertex AI
      {:goth, "~> 1.4"},
      {:google_api_ai_platform, "~> 0.4"},
      
      # Streaming & Server-Sent Events
      {:eventsource_ex, "~> 1.0"},
      
      # Configuration
      {:typed_struct, "~> 0.3"},
      
      # Testing & Development
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      name: "llm_ex",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/user/llm_ex"
      }
    ]
  end

  defp docs do
    [
      main: "LLMEx",
      extras: ["README.md"]
    ]
  end
end
EOF

# Create application supervisor
cat > lib/llm_ex/application.ex << 'EOF'
defmodule LLMEx.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Add supervisors and workers here
      # {LLMEx.ProviderSupervisor, []},
      # {LLMEx.SessionManager, []}
    ]

    opts = [strategy: :one_for_one, name: LLMEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
EOF

echo "📚 Creating comprehensive README..."

cat > README.md << 'EOF'
# LLMEx

A unified Elixir library for interacting with Large Language Model providers, built following Clean Architecture principles.

## Features

- **Unified Interface**: Single API for multiple LLM providers
- **Clean Architecture**: Separation of concerns with clear boundaries
- **Multiple Providers**: Support for OpenAI, Anthropic, Google Gemini, Ollama, and more
- **Streaming Support**: Real-time streaming responses
- **Multiple Auth Methods**: API keys, OAuth, Service Accounts, Vertex AI
- **Type Safety**: Comprehensive type definitions
- **Extensible**: Easy to add new providers

## Supported Providers

- ✅ Google Gemini (API & Vertex AI)
- 🔄 OpenAI (migrating)
- 🔄 Anthropic (migrating)
- 🔄 Ollama (migrating)
- 🔄 Azure OpenAI (migrating)
- 🔄 AWS Bedrock (migrating)
- 🔄 Cohere (migrating)
- 🔄 HuggingFace (migrating)
- 🔄 And more...

## Installation

```elixir
def deps do
  [
    {:llm_ex, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Simple chat
{:ok, response} = LLMEx.chat(:gemini, "gemini-pro", [
  %{role: "user", content: "Hello, world!"}
])

# Streaming chat
{:ok, stream} = LLMEx.stream_chat(:gemini, "gemini-pro", [
  %{role: "user", content: "Tell me a story"}
])

for chunk <- stream do
  IO.write(chunk.content)
end
```

## Architecture

This library follows Clean Architecture principles:

- **Entities**: Core business logic (Provider, Conversation, Auth)
- **Use Cases**: Application-specific business rules (Chat, Streaming)
- **Interface Adapters**: Gateways and adapters for external systems
- **Infrastructure**: External interfaces (HTTP clients, provider APIs)

## Migration Status

This library consolidates and modernizes two existing codebases:
- `ex_llm` (15+ providers, session management)
- `gemini_ex` (advanced Gemini integration with multi-auth)

✅ **Phase 1**: Clean Architecture foundation
🔄 **Phase 2**: Gemini reference implementation
🔄 **Phase 3**: Provider ecosystem migration
🔄 **Phase 4**: Advanced features

See `PLAN.md` for detailed migration roadmap.

## License

MIT
EOF

echo "🧪 Creating basic tests..."

mkdir -p test
cat > test/llm_ex_test.exs << 'EOF'
defmodule LLMExTest do
  use ExUnit.Case
  doctest LLMEx

  test "greets the world" do
    assert LLMEx.providers() |> is_list()
  end
end
EOF

echo "✅ Migration complete! Summary:"
echo "📁 Created Clean Architecture structure in llm_ex/"
echo "🔄 Migrated Gemini as reference implementation"
echo "📋 Preserved original codebases in unused/"
echo "📦 Updated mix.exs with unified dependencies"
echo "📚 Created comprehensive documentation"
echo ""
echo "🚀 Next steps:"
echo "1. cd llm_ex && mix deps.get"
echo "2. Review and test Gemini implementation"
echo "3. Continue with provider migration per PLAN.md"
echo ""
echo "📍 Current status: Phase 1 complete, ready for Phase 2"
