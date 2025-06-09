defmodule ExLLM.ProviderCapabilities do
  @moduledoc """
  Provider-level capability tracking for ExLLM.

  This module provides information about what features and capabilities
  each provider supports at the API level, independent of specific models.
  It helps users understand what operations are available with each provider
  and assists in provider selection based on required features.

  ## Features

  - Provider endpoint discovery (chat, embeddings, images, etc.)
  - Authentication method tracking
  - Cost tracking availability
  - API feature support
  - Provider metadata and limitations
  - Feature-based provider recommendations

  ## Usage

      # Check if a provider supports a specific feature
      ExLLM.ProviderCapabilities.supports?(:openai, :embeddings)
      
      # Get all capabilities for a provider
      {:ok, caps} = ExLLM.ProviderCapabilities.get_capabilities(:anthropic)
      
      # Find providers that support specific features
      providers = ExLLM.ProviderCapabilities.find_providers_with_features([:embeddings, :streaming])
      
      # Get provider recommendations based on requirements
      recommended = ExLLM.ProviderCapabilities.recommend_providers(%{
        required_features: [:streaming, :function_calling],
        preferred_features: [:vision, :cost_tracking],
        exclude_providers: [:mock]
      })
  """

  defmodule ProviderInfo do
    @moduledoc """
    Represents provider-level information and capabilities.
    """
    defstruct [
      :id,
      :name,
      :description,
      :documentation_url,
      :status_url,
      :endpoints,
      :authentication,
      :features,
      :limitations
    ]

    @type endpoint ::
            :chat | :embeddings | :images | :audio | :completions | :fine_tuning | :files
    @type auth_method :: :api_key | :oauth | :aws_signature | :service_account | :bearer_token
    @type feature ::
            :streaming
            | :function_calling
            | :cost_tracking
            | :usage_tracking
            | :dynamic_model_listing
            | :batch_operations
            | :file_uploads
            | :rate_limiting_headers
            | :system_messages
            | :json_mode
            | :context_caching
            | :vision
            | :audio_input
            | :audio_output
            | :web_search
            | :tool_use
            | :computer_use

    @type t :: %__MODULE__{
            id: atom(),
            name: String.t(),
            description: String.t() | nil,
            documentation_url: String.t() | nil,
            status_url: String.t() | nil,
            endpoints: [endpoint()],
            authentication: [auth_method()],
            features: [feature()],
            limitations: map()
          }
  end

  # Provider database - built at runtime to avoid compile-time struct issues
  defp provider_database do
    %{
      # OpenAI
      openai: %__MODULE__.ProviderInfo{
        id: :openai,
        name: "OpenAI",
        description: "OpenAI API with GPT-4, GPT-3.5, DALL-E, and more",
        documentation_url: "https://platform.openai.com/docs",
        status_url: "https://status.openai.com",
        endpoints: [
          :assistants,
          :audio,
          :chat,
          :completions,
          :embeddings,
          :files,
          :fine_tuning,
          :images,
          :runs,
          :threads,
          :vector_stores
        ],
        authentication: [:api_key, :bearer_token],
        features: [
          :assistants_api,
          :batch_operations,
          :code_interpreter,
          :cost_tracking,
          :dynamic_model_listing,
          :embeddings,
          :file_uploads,
          :fine_tuning_api,
          :function_calling,
          :image_generation,
          :json_mode,
          :logprobs,
          :long_context,
          :moderation,
          :parallel_function_calling,
          :rate_limiting_headers,
          :reasoning,
          :response_format,
          :retrieval,
          :seed_control,
          :speech_recognition,
          :speech_synthesis,
          :streaming,
          :structured_outputs,
          :system_messages,
          :tool_use,
          :usage_tracking,
          :vision
        ],
        limitations: %{
          # 512MB
          max_file_size: 512 * 1024 * 1024,
          # GPT-4 Turbo
          max_context_tokens: 128_000,
          # GPT-4o
          max_output_tokens: 16_384,
          rate_limits_vary_by_tier: true,
          image_generation_size_limits: [
            "256x256",
            "512x512",
            "1024x1024",
            "1792x1024",
            "1024x1792"
          ],
          # 25MB
          audio_file_size_limit: 25 * 1024 * 1024
        }
      },

      # Anthropic
      anthropic: %__MODULE__.ProviderInfo{
        id: :anthropic,
        name: "Anthropic",
        description: "Claude AI models with advanced reasoning capabilities",
        documentation_url: "https://docs.anthropic.com",
        status_url: "https://status.anthropic.com",
        endpoints: [:chat, :messages],
        authentication: [:api_key, :bearer_token],
        features: [
          :batch_processing,
          :code_execution,
          :computer_use,
          :context_caching,
          :cost_tracking,
          :document_understanding,
          :function_calling,
          :json_mode,
          :latex_rendering,
          :long_context,
          :multiple_images,
          :prompt_caching,
          :rate_limiting_headers,
          :streaming,
          :structured_outputs,
          :system_messages,
          :tool_use,
          :usage_tracking,
          :vision,
          :xml_mode
        ],
        limitations: %{
          # Claude 3
          max_context_tokens: 200_000,
          max_output_tokens: 8_192,
          max_images_per_request: 20,
          # 5MB per image
          max_image_size: 5 * 1024 * 1024,
          beta_features: [:computer_use, :context_caching, :prompt_caching],
          no_fine_tuning: true,
          no_embeddings: true,
          no_image_generation: true
        }
      },

      # Google Gemini
      gemini: %__MODULE__.ProviderInfo{
        id: :gemini,
        name: "Google Gemini",
        description: "Google's multimodal AI models",
        documentation_url: "https://ai.google.dev/docs",
        endpoints: [:chat, :count_tokens, :embeddings],
        authentication: [:api_key, :service_account, :oauth2],
        features: [
          :audio_input,
          :citation_metadata,
          :code_execution,
          :context_caching,
          :cost_tracking,
          :document_understanding,
          :dynamic_model_listing,
          :embeddings,
          :function_calling,
          :grounding,
          :json_mode,
          :long_context,
          :multi_turn_conversations,
          :multiple_images,
          :safety_settings,
          :streaming,
          :structured_outputs,
          :system_messages,
          :tool_use,
          :usage_tracking,
          :video_understanding,
          :vision
        ],
        limitations: %{
          # Gemini 1.5 Pro (experimental)
          max_context_tokens: 2_000_000,
          standard_context_tokens: 1_000_000,
          max_output_tokens: 8_192,
          max_images_per_request: 16,
          # 1 hour
          max_video_length_seconds: 3600,
          requires_google_cloud_for_some_features: true,
          rate_limits_vary_by_model: true,
          no_fine_tuning_via_api: true
        }
      },

      # Ollama (Local)
      ollama: %__MODULE__.ProviderInfo{
        id: :ollama,
        name: "Ollama",
        description: "Run large language models locally",
        documentation_url: "https://github.com/ollama/ollama",
        endpoints: [:chat, :embeddings, :generate, :list, :show, :pull, :push, :delete, :copy],
        # No auth required for local
        authentication: [],
        features: [
          :streaming,
          :usage_tracking,
          :dynamic_model_listing,
          :system_messages,
          :keep_alive,
          :raw_mode,
          :custom_templates,
          :model_management,
          :context_window_override,
          :temperature_control,
          :seed_control,
          :stop_sequences,
          :mirostat,
          :numa_control,
          :function_calling,
          :tool_use,
          :json_mode,
          :vision,
          :embeddings,
          :stateful_conversations,
          :model_distribution
        ],
        limitations: %{
          no_cost_tracking: true,
          performance_depends_on_hardware: true,
          limited_function_calling: true,
          vision_depends_on_model: true,
          no_image_generation: true,
          no_audio_support: true,
          local_only: true
        }
      },

      # AWS Bedrock
      bedrock: %__MODULE__.ProviderInfo{
        id: :bedrock,
        name: "AWS Bedrock",
        description: "Fully managed foundation models from AWS",
        documentation_url: "https://docs.aws.amazon.com/bedrock",
        endpoints: [
          :chat,
          :embeddings,
          :invoke_model,
          :invoke_model_with_response_stream,
          :converse,
          :converse_stream
        ],
        authentication: [:aws_signature, :iam_role],
        features: [
          :streaming,
          :function_calling,
          :cost_tracking,
          :usage_tracking,
          :system_messages,
          :vision,
          :tool_use,
          :multi_provider_models,
          :guardrails,
          :knowledge_bases,
          :agents,
          :fine_tuning,
          :model_evaluation,
          :provisioned_throughput,
          :json_mode,
          :document_understanding,
          :code_interpretation,
          :batch_inference
        ],
        limitations: %{
          requires_aws_account: true,
          model_access_requires_approval: true,
          region_specific_availability: true,
          pricing_varies_by_model_provider: true,
          some_models_require_commitment: true
        }
      },

      # OpenRouter
      openrouter: %__MODULE__.ProviderInfo{
        id: :openrouter,
        name: "OpenRouter",
        description: "Unified API for multiple LLM providers",
        documentation_url: "https://openrouter.ai/docs",
        endpoints: [:chat],
        authentication: [:api_key],
        features: [
          :streaming,
          :function_calling,
          :cost_tracking,
          :usage_tracking,
          :dynamic_model_listing,
          :rate_limiting_headers,
          :system_messages,
          :vision
        ],
        limitations: %{
          features_depend_on_underlying_provider: true,
          pricing_markup: true
        }
      },

      # Groq
      groq: %__MODULE__.ProviderInfo{
        id: :groq,
        name: "Groq",
        description: "Ultra-fast LLM inference",
        documentation_url: "https://console.groq.com/docs",
        endpoints: [:chat],
        authentication: [:api_key],
        features: [
          :streaming,
          :function_calling,
          :cost_tracking,
          :usage_tracking,
          :dynamic_model_listing,
          :rate_limiting_headers,
          :system_messages,
          :json_mode,
          :tool_use
        ],
        limitations: %{
          limited_model_selection: true,
          optimized_for_speed_not_size: true
        }
      },

      # X.AI
      xai: %__MODULE__.ProviderInfo{
        id: :xai,
        name: "X.AI",
        description: "Grok models with advanced capabilities",
        documentation_url: "https://docs.x.ai",
        endpoints: [:chat],
        authentication: [:api_key],
        features: [
          :streaming,
          :function_calling,
          :cost_tracking,
          :usage_tracking,
          :system_messages,
          :vision,
          :tool_use,
          :web_search,
          :reasoning,
          :json_mode,
          :structured_outputs,
          :tool_choice
        ],
        limitations: %{
          max_context_tokens: 131_072,
          beta_features: [:reasoning]
        }
      },

      # Bumblebee
      bumblebee: %__MODULE__.ProviderInfo{
        id: :bumblebee,
        name: "Bumblebee",
        description: "Run models locally using Elixir's Bumblebee",
        documentation_url: "https://github.com/elixir-nx/bumblebee",
        endpoints: [:chat, :embeddings],
        # No auth required
        authentication: [],
        features: [
          :usage_tracking,
          :system_messages
        ],
        limitations: %{
          no_streaming: true,
          no_cost_tracking: true,
          limited_model_selection: true,
          performance_depends_on_hardware: true,
          requires_model_download: true
        }
      },

      # Mock (Testing)
      mock: %__MODULE__.ProviderInfo{
        id: :mock,
        name: "Mock Provider",
        description: "Mock provider for testing",
        endpoints: [:chat, :embeddings],
        # No auth required
        authentication: [],
        features: [
          :streaming,
          :function_calling,
          :cost_tracking,
          :usage_tracking,
          :system_messages,
          :vision,
          :tool_use,
          :json_mode
        ],
        limitations: %{
          for_testing_only: true
        }
      }
    }
  end

  @doc """
  Get capabilities for a specific provider.

  ## Parameters
  - `provider` - Provider atom (e.g., :openai, :anthropic)

  ## Returns
  - `{:ok, provider_info}` on success
  - `{:error, :not_found}` if provider not found

  ## Examples

      {:ok, info} = ExLLM.ProviderCapabilities.get_capabilities(:openai)
  """
  @spec get_capabilities(atom()) :: {:ok, ProviderInfo.t()} | {:error, :not_found}
  def get_capabilities(provider) do
    case Map.get(provider_database(), provider) do
      nil -> {:error, :not_found}
      info -> {:ok, info}
    end
  end

  @doc """
  Check if a provider supports a specific feature.

  ## Parameters
  - `provider` - Provider atom
  - `feature` - Feature to check (endpoint or capability)

  ## Returns
  - `true` if supported
  - `false` if not supported or provider not found

  ## Examples

      ExLLM.ProviderCapabilities.supports?(:openai, :embeddings)
      # => true
      
      ExLLM.ProviderCapabilities.supports?(:ollama, :cost_tracking)
      # => false
  """
  @spec supports?(atom(), atom()) :: boolean()
  def supports?(provider, feature) do
    case get_capabilities(provider) do
      {:ok, info} ->
        feature in info.endpoints || feature in info.features

      {:error, _} ->
        false
    end
  end

  @doc """
  Find providers that support all specified features.

  ## Parameters
  - `features` - List of required features

  ## Returns
  - List of provider atoms that support all features

  ## Examples

      providers = ExLLM.ProviderCapabilities.find_providers_with_features([:embeddings, :streaming])
      # => [:openai, :groq]
  """
  @spec find_providers_with_features([atom()]) :: [atom()]
  def find_providers_with_features(features) do
    provider_database()
    |> Enum.filter(fn {_provider, info} ->
      Enum.all?(features, fn feature ->
        feature in info.endpoints || feature in info.features
      end)
    end)
    |> Enum.map(fn {provider, _info} -> provider end)
    |> Enum.sort()
  end

  @doc """
  Get authentication methods for a provider.

  ## Parameters
  - `provider` - Provider atom

  ## Returns
  - List of authentication methods or empty list

  ## Examples

      ExLLM.ProviderCapabilities.get_auth_methods(:openai)
      # => [:api_key, :bearer_token]
  """
  @spec get_auth_methods(atom()) :: [atom()]
  def get_auth_methods(provider) do
    case get_capabilities(provider) do
      {:ok, info} -> info.authentication
      {:error, _} -> []
    end
  end

  @doc """
  Get available endpoints for a provider.

  ## Parameters
  - `provider` - Provider atom

  ## Returns
  - List of available endpoints or empty list

  ## Examples

      ExLLM.ProviderCapabilities.get_endpoints(:openai)
      # => [:chat, :embeddings, :images, :audio, :completions, :fine_tuning, :files]
  """
  @spec get_endpoints(atom()) :: [atom()]
  def get_endpoints(provider) do
    case get_capabilities(provider) do
      {:ok, info} -> info.endpoints
      {:error, _} -> []
    end
  end

  @doc """
  List all known providers.

  ## Returns
  - List of provider atoms

  ## Examples

      ExLLM.ProviderCapabilities.list_providers()
      # => [:anthropic, :bedrock, :bumblebee, :gemini, :groq, :mock, :ollama, :openai, :openrouter, :xai]
  """
  @spec list_providers() :: [atom()]
  def list_providers do
    Map.keys(provider_database()) |> Enum.sort()
  end

  @doc """
  Get provider limitations.

  ## Parameters
  - `provider` - Provider atom

  ## Returns
  - Map of limitations or empty map

  ## Examples

      ExLLM.ProviderCapabilities.get_limitations(:ollama)
      # => %{no_cost_tracking: true, performance_depends_on_hardware: true}
  """
  @spec get_limitations(atom()) :: map()
  def get_limitations(provider) do
    case get_capabilities(provider) do
      {:ok, info} -> info.limitations
      {:error, _} -> %{}
    end
  end

  @doc """
  Compare capabilities across multiple providers.

  ## Parameters
  - `providers` - List of provider atoms to compare

  ## Returns
  - Map with comparison data

  ## Examples

      comparison = ExLLM.ProviderCapabilities.compare_providers([:openai, :anthropic, :ollama])
  """
  @spec compare_providers([atom()]) :: map()
  def compare_providers(providers) do
    provider_infos =
      providers
      |> Enum.map(fn provider ->
        case get_capabilities(provider) do
          {:ok, info} -> {provider, info}
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    # Collect all unique features and endpoints
    all_features =
      provider_infos
      |> Enum.flat_map(fn {_provider, info} -> info.features end)
      |> Enum.uniq()
      |> Enum.sort()

    all_endpoints =
      provider_infos
      |> Enum.flat_map(fn {_provider, info} -> info.endpoints end)
      |> Enum.uniq()
      |> Enum.sort()

    %{
      providers: Map.keys(provider_infos),
      features: all_features,
      endpoints: all_endpoints,
      comparison:
        Map.new(provider_infos, fn {provider, info} ->
          {provider,
           %{
             features: info.features,
             endpoints: info.endpoints,
             authentication: info.authentication,
             limitations: info.limitations
           }}
        end)
    }
  end

  @doc """
  Get provider recommendations based on requirements.

  ## Parameters
  - `requirements` - Map with:
    - `:required_features` - List of features that must be supported
    - `:preferred_features` - List of features that are nice to have
    - `:required_endpoints` - List of endpoints that must be available
    - `:exclude_providers` - List of providers to exclude
    - `:prefer_local` - Boolean to prefer local providers (default: false)
    - `:prefer_free` - Boolean to prefer free providers (default: false)

  ## Returns
  - List of recommended providers sorted by match score

  ## Examples

      recommendations = ExLLM.ProviderCapabilities.recommend_providers(%{
        required_features: [:streaming, :function_calling],
        preferred_features: [:vision, :cost_tracking],
        exclude_providers: [:mock]
      })
      # => [
      #   %{provider: :openai, score: 1.0, matched_features: [...], missing_features: []},
      #   %{provider: :anthropic, score: 0.85, matched_features: [...], missing_features: [...]}
      # ]
  """
  @spec recommend_providers(map()) :: [map()]
  def recommend_providers(requirements \\ %{}) do
    required_features = Map.get(requirements, :required_features, [])
    preferred_features = Map.get(requirements, :preferred_features, [])
    required_endpoints = Map.get(requirements, :required_endpoints, [])
    exclude_providers = Map.get(requirements, :exclude_providers, [])
    prefer_local = Map.get(requirements, :prefer_local, false)
    prefer_free = Map.get(requirements, :prefer_free, false)

    provider_database()
    |> Enum.reject(fn {provider, _} -> provider in exclude_providers end)
    |> Enum.map(fn {provider, info} ->
      # Check required features
      has_required_features =
        Enum.all?(required_features, fn feature ->
          feature in info.features or feature in info.endpoints
        end)

      # Check required endpoints
      has_required_endpoints =
        Enum.all?(required_endpoints, fn endpoint ->
          endpoint in info.endpoints
        end)

      if has_required_features and has_required_endpoints do
        # Calculate score
        matched_preferred =
          Enum.filter(preferred_features, fn feature ->
            feature in info.features or feature in info.endpoints
          end)

        matched_required =
          Enum.filter(required_features, fn feature ->
            feature in info.features or feature in info.endpoints
          end)

        missing_preferred = preferred_features -- matched_preferred

        # Base score from matched features
        score = length(matched_required) * 1.0 + length(matched_preferred) * 0.5

        # Bonus for local providers
        score =
          if prefer_local and provider in [:bumblebee, :ollama], do: score + 0.5, else: score

        # Bonus for free providers
        score =
          if prefer_free and provider in [:bumblebee, :ollama, :mock],
            do: score + 0.5,
            else: score

        # Penalty for limitations
        limitation_count = map_size(info.limitations)
        score = score - limitation_count * 0.1

        # Normalize score
        max_score = length(required_features) + length(preferred_features) * 0.5 + 1.0
        normalized_score = score / max_score

        %{
          provider: provider,
          score: normalized_score,
          matched_features: matched_required ++ matched_preferred,
          missing_features: missing_preferred,
          limitations: info.limitations
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Get a provider-specific adapter module.

  ## Parameters
  - `provider` - Provider atom

  ## Returns
  - Module atom or nil

  ## Examples

      ExLLM.ProviderCapabilities.get_adapter_module(:openai)
      # => ExLLM.Adapters.OpenAI
  """
  @spec get_adapter_module(atom()) :: module() | nil
  def get_adapter_module(provider) do
    case provider do
      :anthropic -> ExLLM.Adapters.Anthropic
      :openai -> ExLLM.Adapters.OpenAI
      :ollama -> ExLLM.Adapters.Ollama
      :bedrock -> ExLLM.Adapters.Bedrock
      :gemini -> ExLLM.Adapters.Gemini
      :groq -> ExLLM.Adapters.Groq
      :openrouter -> ExLLM.Adapters.OpenRouter
      :bumblebee -> ExLLM.Adapters.Bumblebee
      :mock -> ExLLM.Adapters.Mock
      _ -> nil
    end
  end

  @doc """
  Check if a provider is considered "local" (no API calls).

  ## Parameters
  - `provider` - Provider atom

  ## Returns
  - Boolean

  ## Examples

      ExLLM.ProviderCapabilities.is_local?(:ollama)
      # => true
      
      ExLLM.ProviderCapabilities.is_local?(:openai)
      # => false
  """
  @spec is_local?(atom()) :: boolean()
  def is_local?(provider) do
    provider in [:bumblebee, :ollama, :mock]
  end

  @doc """
  Check if a provider requires authentication.

  ## Parameters
  - `provider` - Provider atom

  ## Returns
  - Boolean

  ## Examples

      ExLLM.ProviderCapabilities.requires_auth?(:openai)
      # => true
      
      ExLLM.ProviderCapabilities.requires_auth?(:ollama)
      # => false
  """
  @spec requires_auth?(atom()) :: boolean()
  def requires_auth?(provider) do
    case get_capabilities(provider) do
      {:ok, info} -> info.authentication != []
      {:error, _} -> false
    end
  end
end
