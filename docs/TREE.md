# ExLLM Architecture - Refined with Gemini Multi-Auth Pattern

## Executive Summary

This refined architecture incorporates the sophisticated multi-authentication patterns from your Gemini implementation while maintaining CMMI compliance and clean architecture principles. The design emphasizes a comprehensive first adapter (Gemini) that showcases the full capability of the architecture.

## Refined File Tree Structure

```
lib/
├── ex_llm/
│   │
│   ├── application/                          # OTP Application & Supervision
│   │   ├── supervisors/
│   │   │   ├── application_supervisor.ex       # Root supervisor
│   │   │   ├── core_services_supervisor.ex     # Domain services
│   │   │   ├── adapters_supervisor.ex          # Provider adapters
│   │   │   ├── auth_supervisor.ex              # Authentication managers
│   │   │   └── streaming_supervisor.ex         # Streaming coordinators
│   │   └── application.ex                      # OTP Application entry
│   │
│   ├── core/                                 # Clean Architecture Core Domain
│   │   ├── entities/                         # Domain Entities
│   │   │   ├── conversation.ex
│   │   │   ├── message.ex
│   │   │   ├── model.ex
│   │   │   ├── provider.ex
│   │   │   ├── authentication.ex             # Auth entity
│   │   │   └── streaming_session.ex
│   │   │
│   │   ├── value_objects/                    # Immutable Value Objects
│   │   │   ├── conversation_id.ex
│   │   │   ├── message_content.ex            # Multimodal content handling
│   │   │   ├── response.ex                   # Unified response
│   │   │   ├── stream_chunk.ex
│   │   │   ├── token_usage.ex
│   │   │   ├── cost_calculation.ex
│   │   │   ├── auth_credentials.ex           # Auth value objects
│   │   │   └── provider_capabilities.ex
│   │   │
│   │   ├── use_cases/                        # Business Logic Orchestrators
│   │   │   ├── conversations/
│   │   │   │   ├── create_conversation.ex
│   │   │   │   ├── send_message.ex
│   │   │   │   ├── get_conversation.ex
│   │   │   │   └── archive_conversation.ex
│   │   │   ├── streaming/
│   │   │   │   ├── initiate_stream.ex
│   │   │   │   ├── process_stream_chunk.ex
│   │   │   │   └── handle_stream_error.ex
│   │   │   ├── models/
│   │   │   │   ├── list_models.ex
│   │   │   │   ├── get_model_info.ex
│   │   │   │   └── validate_model_capabilities.ex
│   │   │   └── authentication/
│   │   │       ├── authenticate_provider.ex
│   │   │       ├── refresh_credentials.ex
│   │   │       └── validate_auth_config.ex
│   │   │
│   │   ├── ports/                            # Interface Contracts (Behaviours)
│   │   │   ├── provider_adapter_port.ex      # Main provider contract
│   │   │   ├── auth_strategy_port.ex         # Authentication contract
│   │   │   ├── streaming_port.ex             # Streaming contract
│   │   │   ├── cache_port.ex                 # Caching contract
│   │   │   ├── conversation_repo_port.ex     # Persistence contract
│   │   │   └── telemetry_port.ex             # Observability contract
│   │   │
│   │   └── services/                         # Domain Services (GenServers)
│   │       ├── conversation_manager.ex       # Conversation lifecycle
│   │       ├── provider_registry.ex          # Provider registration
│   │       ├── auth_coordinator.ex           # Multi-auth coordination
│   │       ├── streaming_coordinator.ex      # Stream management
│   │       └── cost_calculator.ex            # Token & cost tracking
│   │
│   ├── adapters/                             # Hexagonal Architecture Adapters
│   │   ├── providers/                        # LLM Provider Implementations
│   │   │   ├── shared/                       # Shared Provider Infrastructure
│   │   │   │   ├── http_client.ex            # Unified HTTP client
│   │   │   │   ├── error_mapper.ex           # Error normalization
│   │   │   │   ├── response_normalizer.ex    # Response standardization
│   │   │   │   ├── streaming_coordinator.ex  # Provider-agnostic streaming
│   │   │   │   └── auth_manager.ex           # Base auth management
│   │   │   │
│   │   │   ├── gemini/                       # Comprehensive Gemini Implementation
│   │   │   │   ├── adapter.ex                # Main adapter (implements ProviderAdapterPort)
│   │   │   │   ├── client.ex                 # Core HTTP client
│   │   │   │   │
│   │   │   │   ├── auth/                     # Multi-Strategy Authentication
│   │   │   │   │   ├── strategy.ex           # Auth strategy behaviour
│   │   │   │   │   ├── gemini_strategy.ex    # API key auth
│   │   │   │   │   ├── vertex_strategy.ex    # OAuth2/Service Account
│   │   │   │   │   ├── jwt_manager.ex        # JWT creation & validation
│   │   │   │   │   ├── multi_auth_coordinator.ex # Auth coordination
│   │   │   │   │   └── credential_manager.ex # Credential lifecycle
│   │   │   │   │
│   │   │   │   ├── apis/                     # Gemini API Implementations
│   │   │   │   │   ├── coordinator.ex        # API routing & coordination
│   │   │   │   │   ├── generate.ex           # generateContent API
│   │   │   │   │   ├── models.ex             # Model management API
│   │   │   │   │   ├── tokens.ex             # Token counting API
│   │   │   │   │   ├── files.ex              # File API (upload/manage)
│   │   │   │   │   ├── embedding.ex          # Embedding API
│   │   │   │   │   ├── caching.ex            # Context caching API
│   │   │   │   │   ├── live.ex               # Live API (WebSocket)
│   │   │   │   │   ├── retrieval/            # Semantic Retrieval APIs
│   │   │   │   │   │   ├── corpora.ex
│   │   │   │   │   │   ├── documents.ex
│   │   │   │   │   │   ├── chunks.ex
│   │   │   │   │   │   └── permissions.ex
│   │   │   │   │   └── tuning/               # Model Tuning APIs
│   │   │   │   │       ├── tuning.ex
│   │   │   │   │       └── permissions.ex
│   │   │   │   │
│   │   │   │   ├── streaming/                # Advanced Streaming Support
│   │   │   │   │   ├── manager.ex            # Stream lifecycle management
│   │   │   │   │   ├── unified_manager.ex    # Multi-endpoint streaming
│   │   │   │   │   ├── chunk_processor.ex    # Chunk parsing & validation
│   │   │   │   │   └── recovery_manager.ex   # Stream error recovery
│   │   │   │   │
│   │   │   │   ├── types/                    # Gemini-Specific Types
│   │   │   │   │   ├── common/
│   │   │   │   │   │   ├── content.ex
│   │   │   │   │   │   ├── part.ex
│   │   │   │   │   │   ├── blob.ex
│   │   │   │   │   │   ├── generation_config.ex
│   │   │   │   │   │   └── safety_setting.ex
│   │   │   │   │   ├── requests/
│   │   │   │   │   │   ├── generate_content_request.ex
│   │   │   │   │   │   ├── embed_content_request.ex
│   │   │   │   │   │   └── list_models_request.ex
│   │   │   │   │   └── responses/
│   │   │   │   │       ├── generate_content_response.ex
│   │   │   │   │       ├── embed_content_response.ex
│   │   │   │   │       └── model_response.ex
│   │   │   │   │
│   │   │   │   ├── mappers/                  # Data Transformation
│   │   │   │   │   ├── request_mapper.ex     # Core domain → Gemini API
│   │   │   │   │   ├── response_mapper.ex    # Gemini API → Core domain
│   │   │   │   │   ├── streaming_mapper.ex   # Stream chunk mapping
│   │   │   │   │   └── error_mapper.ex       # Error transformation
│   │   │   │   │
│   │   │   │   ├── config.ex                 # Gemini-specific configuration
│   │   │   │   ├── telemetry.ex              # Gemini telemetry events
│   │   │   │   └── utils.ex                  # Utility functions
│   │   │   │
│   │   │   ├── anthropic/                    # Anthropic Implementation
│   │   │   │   ├── adapter.ex
│   │   │   │   ├── client.ex
│   │   │   │   ├── auth/
│   │   │   │   │   └── api_key_strategy.ex
│   │   │   │   ├── apis/
│   │   │   │   │   ├── messages.ex
│   │   │   │   │   └── tools.ex
│   │   │   │   ├── streaming/
│   │   │   │   │   └── manager.ex
│   │   │   │   ├── types/
│   │   │   │   ├── mappers/
│   │   │   │   └── config.ex
│   │   │   │
│   │   │   ├── openai/                       # OpenAI Implementation
│   │   │   │   └── [similar structure]
│   │   │   │
│   │   │   └── mock/                         # Testing Provider
│   │   │       ├── adapter.ex
│   │   │       ├── response_generator.ex
│   │   │       └── config.ex
│   │   │
│   │   ├── persistence/                      # Data Storage Adapters
│   │   │   ├── memory/
│   │   │   │   ├── conversation_repo.ex      # In-memory storage
│   │   │   │   └── session_cache.ex
│   │   │   ├── ets/
│   │   │   │   ├── conversation_repo.ex      # ETS storage
│   │   │   │   └── model_cache.ex
│   │   │   └── ecto/
│   │   │       ├── conversation_repo.ex      # Database storage
│   │   │       └── schemas/
│   │   │           ├── conversation.ex
│   │   │           └── message.ex
│   │   │
│   │   ├── streaming/                        # Streaming Infrastructure
│   │   │   ├── sse_parser.ex                 # Server-Sent Events parser
│   │   │   ├── websocket_handler.ex          # WebSocket streaming
│   │   │   ├── stream_coordinator.ex         # Cross-provider streaming
│   │   │   ├── backpressure_manager.ex       # Flow control
│   │   │   └── recovery_coordinator.ex       # Error recovery
│   │   │
│   │   ├── cache/                            # Caching Implementations
│   │   │   ├── ets_cache.ex                  # Local ETS cache
│   │   │   ├── redis_cache.ex                # Distributed Redis cache
│   │   │   ├── memory_cache.ex               # Simple memory cache
│   │   │   └── layered_cache.ex              # Multi-level caching
│   │   │
│   │   └── telemetry/                        # Observability Adapters
│   │       ├── prometheus_exporter.ex        # Prometheus metrics
│   │       ├── telemetry_handler.ex          # Telemetry event handling
│   │       ├── logger_handler.ex             # Structured logging
│   │       └── tracer.ex                     # Distributed tracing
│   │
│   ├── infrastructure/                       # Technical Infrastructure
│   │   ├── http/                             # HTTP Infrastructure
│   │   │   ├── client.ex                     # Base HTTP client (Req/Finch)
│   │   │   ├── middleware/                   # HTTP middleware
│   │   │   │   ├── auth_middleware.ex
│   │   │   │   ├── retry_middleware.ex
│   │   │   │   ├── rate_limit_middleware.ex
│   │   │   │   ├── telemetry_middleware.ex
│   │   │   │   └── cache_middleware.ex
│   │   │   ├── connection_pool.ex            # Connection pooling
│   │   │   └── ssl_config.ex                 # SSL/TLS configuration
│   │   │
│   │   ├── auth/                             # Authentication Infrastructure
│   │   │   ├── credential_store.ex           # Secure credential storage
│   │   │   ├── token_manager.ex              # Token lifecycle management
│   │   │   ├── refresh_scheduler.ex          # Automatic token refresh
│   │   │   └── security_validator.ex         # Security validation
│   │   │
│   │   ├── streaming/                        # Streaming Infrastructure
│   │   │   ├── flow_controller.ex            # GenStage-based flow control
│   │   │   ├── buffer_manager.ex             # Stream buffering
│   │   │   ├── compression.ex                # Stream compression
│   │   │   └── stats_collector.ex            # Streaming statistics
│   │   │
│   │   ├── config/                           # Configuration Management
│   │   │   ├── loader.ex                     # Configuration loading
│   │   │   ├── validator.ex                  # Configuration validation
│   │   │   ├── transformer.ex                # Configuration transformation
│   │   │   └── watcher.ex                    # Runtime config changes
│   │   │
│   │   ├── error/                            # Error Management
│   │   │   ├── handler.ex                    # Central error handling
│   │   │   ├── classifier.ex                 # Error classification
│   │   │   ├── recovery.ex                   # Error recovery strategies
│   │   │   └── reporter.ex                   # Error reporting
│   │   │
│   │   ├── retry/                            # Retry Infrastructure
│   │   │   ├── backoff.ex                    # Backoff strategies
│   │   │   ├── circuit_breaker.ex            # Circuit breaker pattern
│   │   │   ├── rate_limiter.ex               # Rate limiting
│   │   │   └── jitter.ex                     # Retry jitter
│   │   │
│   │   ├── security/                         # Security Infrastructure
│   │   │   ├── encryption.ex                 # Data encryption
│   │   │   ├── sanitization.ex               # Input sanitization
│   │   │   ├── audit_logger.ex               # Security audit logging
│   │   │   └── access_control.ex             # Access control
│   │   │
│   │   └── telemetry/                        # Telemetry Infrastructure
│   │       ├── events.ex                     # Event definitions
│   │       ├── metrics.ex                    # Metrics collection
│   │       ├── tracing.ex                    # Distributed tracing
│   │       └── spans.ex                      # Span management
│   │
│   ├── interfaces/                           # External Interfaces
│   │   ├── facade.ex                         # Main API facade
│   │   ├── streaming_api.ex                  # Streaming API interface
│   │   ├── admin_api.ex                      # Administrative interface
│   │   └── health_check.ex                   # Health check endpoints
│   │
│   ├── process_management/                   # CMMI Implementation
│   │   ├── level_2_managed/
│   │   │   ├── requirements_tracker.ex
│   │   │   ├── quality_gates.ex
│   │   │   ├── configuration_control.ex
│   │   │   └── measurement_analysis.ex
│   │   ├── level_3_defined/
│   │   │   ├── organizational_standards.ex
│   │   │   ├── training_programs.ex
│   │   │   ├── risk_management.ex
│   │   │   └── decision_analysis.ex
│   │   ├── level_4_quantitative/
│   │   │   ├── process_metrics.ex
│   │   │   ├── statistical_control.ex
│   │   │   ├── performance_baselines.ex
│   │   │   └── predictive_analytics.ex
│   │   └── level_5_optimizing/
│   │       ├── innovation_deployment.ex
│   │       ├── causal_analysis.ex
│   │       ├── organizational_learning.ex
│   │       └── process_optimization.ex
│   │
│   └── types.ex                              # Shared public types
│
├── ex_llm.ex                                 # Main Facade Entry Point
│
├── config/                                   # Application Configuration
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   ├── prod.exs
│   └── runtime.exs
│
├── priv/                                     # Private Application Data
│   ├── repo/
│   │   └── migrations/
│   ├── static/
│   └── gettext/
│
└── test/                                     # Comprehensive Test Suite
    ├── support/                              # Test Support Infrastructure
    │   ├── case_templates/
    │   │   ├── adapter_case.ex
    │   │   ├── integration_case.ex
    │   │   └── unit_case.ex
    │   ├── factories/
    │   │   ├── conversation_factory.ex
    │   │   ├── message_factory.ex
    │   │   └── provider_factory.ex
    │   ├── mocks/
    │   │   ├── mock_provider.ex
    │   │   ├── mock_auth_strategy.ex
    │   │   └── mock_http_client.ex
    │   ├── fixtures/
    │   │   ├── gemini_responses.json
    │   │   ├── anthropic_responses.json
    │   │   └── streaming_chunks.json
    │   └── helpers/
    │       ├── auth_helper.ex
    │       ├── streaming_helper.ex
    │       └── assertion_helper.ex
    │
    ├── unit/                                 # Unit Tests (Core Domain)
    │   ├── core/
    │   │   ├── entities/
    │   │   ├── value_objects/
    │   │   ├── use_cases/
    │   │   └── services/
    │   └── infrastructure/
    │
    ├── integration/                          # Integration Tests
    │   ├── adapters/
    │   │   ├── providers/
    │   │   │   └── gemini/
    │   │   │       ├── auth_test.exs
    │   │   │       ├── apis_test.exs
    │   │   │       └── streaming_test.exs
    │   │   ├── persistence/
    │   │   └── cache/
    │   ├── streaming/
    │   └── auth/
    │
    ├── contract/                             # Contract Tests
    │   ├── provider_adapter_contract_test.exs
    │   ├── auth_strategy_contract_test.exs
    │   └── streaming_contract_test.exs
    │
    ├── property/                             # Property-Based Tests
    │   ├── conversation_properties_test.exs
    │   ├── streaming_properties_test.exs
    │   └── auth_properties_test.exs
    │
    ├── performance/                          # Performance Tests
    │   ├── streaming_performance_test.exs
    │   ├── auth_performance_test.exs
    │   └── memory_usage_test.exs
    │
    └── acceptance/                           # End-to-End Tests
        ├── complete_flow_test.exs
        ├── multi_provider_test.exs
        └── error_recovery_test.exs
```

## Key Architecture Decisions

### 1. Multi-Authentication Strategy Implementation

Based on your Gemini auth implementation, I've designed a sophisticated auth system:

```elixir
defmodule ExLLM.Core.Ports.AuthStrategyPort do
  @moduledoc """
  Contract for authentication strategies across all providers.
  
  Supports multiple authentication methods per provider,
  credential lifecycle management, and automatic refresh.
  """

  @type credentials :: map()
  @type auth_result :: {:ok, headers :: list()} | {:error, term()}
  @type refresh_result :: {:ok, credentials()} | {:error, term()}

  @callback authenticate(credentials()) :: auth_result()
  @callback refresh_credentials(credentials()) :: refresh_result()
  @callback validate_credentials(credentials()) :: :ok | {:error, term()}
  @callback headers(credentials()) :: list()
  @callback base_url(credentials()) :: String.t() | {:error, term()}
  @callback build_path(String.t(), String.t(), credentials()) :: String.t()
end
```

### 2. Comprehensive Gemini Implementation

The Gemini adapter serves as the reference implementation, showcasing:

```elixir
defmodule ExLLM.Adapters.Providers.Gemini.Auth.MultiAuthCoordinator do
  @moduledoc """
  Coordinates between Gemini API key and Vertex AI OAuth authentication.
  
  Demonstrates the multi-auth pattern that can be applied to other
  providers with multiple authentication methods.
  """

  alias ExLLM.Adapters.Providers.Gemini.Auth.{GeminiStrategy, VertexStrategy}

  def coordinate_auth(strategy, credentials) do
    case strategy do
      :gemini_api -> GeminiStrategy.authenticate(credentials)
      :vertex_ai -> VertexStrategy.authenticate(credentials)
    end
  end

  def determine_strategy(credentials) do
    cond do
      Map.has_key?(credentials, :api_key) -> :gemini_api
      Map.has_key?(credentials, :project_id) -> :vertex_ai
      true -> {:error, "Cannot determine auth strategy"}
    end
  end
end
```

### 3. Advanced Streaming Architecture

Incorporating lessons from your streaming implementation:

```elixir
defmodule ExLLM.Adapters.Providers.Gemini.Streaming.UnifiedManager do
  @moduledoc """
  Unified streaming manager supporting multiple Gemini endpoints:
  - generateContent (streaming)
  - Live API (WebSocket)
  - Custom streaming endpoints
  
  Provides consistent streaming interface regardless of underlying protocol.
  """

  use GenServer

  def start_stream(endpoint, request, opts \\ []) do
    GenServer.start_link(__MODULE__, {endpoint, request, opts})
  end

  def init({:generate_content, request, opts}) do
    # HTTP SSE streaming
    {:ok, init_sse_stream(request, opts)}
  end

  def init({:live_api, request, opts}) do
    # WebSocket streaming
    {:ok, init_websocket_stream(request, opts)}
  end
end
```

### 4. Provider API Coordination

Following your coordinator pattern:

```elixir
defmodule ExLLM.Adapters.Providers.Gemini.APIs.Coordinator do
  @moduledoc """
  Coordinates between different Gemini API endpoints based on request type.
  
  Routes requests to appropriate specialized API modules while maintaining
  a unified interface through the main adapter.
  """

  alias ExLLM.Adapters.Providers.Gemini.APIs.{Generate, Models, Tokens, Files}

  def route_request(request_type, request, opts) do
    case request_type do
      :generate_content -> Generate.process(request, opts)
      :list_models -> Models.list(request, opts)
      :count_tokens -> Tokens.count(request, opts)
      :upload_file -> Files.upload(request, opts)
    end
  end
end
```

## Implementation Strategy

### Phase 1: Core Domain (Weeks 1-3)
1. **Entities & Value Objects**: Define core domain model
2. **Use Cases**: Implement business logic without external dependencies
3. **Ports**: Define all interface contracts
4. **Services**: Create domain services for state management

### Phase 2: Gemini Reference Implementation (Weeks 4-8)
1. **Authentication System**: Multi-strategy auth with JWT support
2. **Core APIs**: Generate, Models, Tokens endpoints
3. **Advanced APIs**: Files, Embedding, Caching, Retrieval
4. **Streaming System**: Unified streaming with SSE and WebSocket

### Phase 3: Infrastructure & Other Providers (Weeks 9-12)
1. **HTTP Infrastructure**: Middleware, pooling, retry logic
2. **Streaming Infrastructure**: GenStage-based flow control
3. **Anthropic Adapter**: Apply patterns from Gemini
4. **OpenAI Adapter**: Standard implementation

### Phase 4: Operations & Quality (Weeks 13-16)
1. **Observability**: Comprehensive telemetry and monitoring
2. **Testing**: All test types with >95% coverage
3. **Documentation**: Complete API and implementation guides
4. **Performance**: Optimization and benchmarking

## Key Benefits of This Architecture

1. **Multi-Auth Sophistication**: Your auth patterns provide enterprise-grade flexibility
2. **Comprehensive API Coverage**: Gemini implementation showcases full provider capability
3. **Streaming Excellence**: Advanced streaming with multiple protocols
4. **Clean Boundaries**: Clear separation between domain and infrastructure
5. **Provider Extensibility**: Pattern established for complex provider implementations
6. **CMMI Compliance**: Enterprise process maturity built-in

This architecture leverages your excellent work on Gemini auth and API coordination while providing a clean, extensible foundation for a comprehensive LLM adapter library.
