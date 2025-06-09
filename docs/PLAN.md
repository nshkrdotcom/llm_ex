# PLAN.md: Integrating gemini_ex and ex_llm

## Executive Summary

This document outlines the integration plan between two Elixir LLM libraries:
- **gemini_ex**: A specialized, comprehensive Gemini API client with streaming capabilities
- **ex_llm**: A unified LLM provider interface supporting multiple providers (OpenAI, Anthropic, Gemini, etc.)

The goal is to create a seamless integration where `gemini_ex` serves as the best-in-class Gemini provider implementation for `ex_llm`, while `ex_llm` provides the unified interface layer.

## Current State Analysis

### gemini_ex Strengths
- ✅ **Complete Gemini API Coverage**: Full implementation of Gemini 2.0, 2.5 APIs
- ✅ **Native Streaming**: Sophisticated streaming with UnifiedManager, manager v2
- ✅ **Authentication**: Both Gemini API and Vertex AI support
- ✅ **Type Safety**: Comprehensive TypedStruct definitions
- ✅ **Error Handling**: Structured error types with Gemini.Error
- ✅ **Telemetry**: Built-in metrics and monitoring
- ✅ **Production Ready**: Mature codebase with proper supervision trees

### ex_llm Strengths  
- ✅ **Provider Abstraction**: Unified interface across 13+ LLM providers
- ✅ **Structured Outputs**: instructor.ex integration for schema validation
- ✅ **Session Management**: Conversation state and context management
- ✅ **Cost Tracking**: Automatic usage and cost calculation
- ✅ **Retry Logic**: Exponential backoff with provider-specific policies
- ✅ **Function Calling**: Unified tool/function interface
- ✅ **Context Management**: Smart message truncation and sliding window
- ✅ **Configuration**: Flexible config injection with multiple providers

### Integration Challenges
- 🔄 **Streaming Architecture**: Different streaming implementations
- 🔄 **Type Systems**: Different response/request type definitions
- 🔄 **Error Handling**: Need to align error types
- 🔄 **Structured Outputs**: gemini_ex native vs instructor.ex approach
- 🔄 **Configuration**: Merge config systems

## Integration Strategy

### Phase 1: Foundation Integration (Immediate)

#### 1.1 Repository Structure
```
gemini_unified/
├── lib/
│   ├── gemini/              # Keep existing gemini_ex (Phase 1: minimal changes)
│   └── ex_llm/              # Fork of ex_llm (Phase 1: adapter replacement)
├── mix.exs                  # Updated dependencies
└── PLAN.md                  # This document
```

#### 1.2 Replace ex_llm Gemini Adapter
**Target**: `ex_llm/lib/ex_llm/adapters/gemini.ex`

Replace the basic ex_llm Gemini adapter with a bridge to gemini_ex:

```elixir
defmodule ExLLM.Adapters.Gemini do
  @moduledoc """
  Enhanced Gemini adapter using gemini_ex for comprehensive API support.
  
  This adapter bridges ex_llm's unified interface with gemini_ex's 
  specialized Gemini implementation.
  """
  
  @behaviour ExLLM.Adapter
  
  alias Gemini.APIs.Coordinator
  alias ExLLM.Types.LLMResponse
  
  @impl true
  def chat(messages, options \\ []) do
    # Transform ex_llm messages to gemini_ex format
    with {:ok, gemini_contents} <- transform_messages_to_gemini(messages),
         {:ok, gemini_opts} <- transform_options_to_gemini(options),
         {:ok, gemini_response} <- Coordinator.generate_content(gemini_contents, gemini_opts) do
      transform_gemini_response_to_ex_llm(gemini_response, options)
    end
  end
  
  @impl true  
  def stream_chat(messages, options \\ []) do
    # Use gemini_ex streaming with ex_llm stream format
    with {:ok, gemini_contents} <- transform_messages_to_gemini(messages),
         {:ok, gemini_opts} <- transform_options_to_gemini(options),
         {:ok, stream_id} <- Coordinator.stream_generate_content(gemini_contents, gemini_opts) do
      create_ex_llm_stream(stream_id)
    end
  end
  
  # ... implementation details below
end
```

#### 1.3 Configuration Bridge
Create configuration mapping between the two systems:

```elixir
defmodule ExLLM.Adapters.Gemini.ConfigBridge do
  @moduledoc """
  Maps ex_llm configuration format to gemini_ex configuration.
  """
  
  def transform_config(ex_llm_config) do
    # Map ex_llm's %{gemini: %{api_key: "...", model: "..."}}
    # to gemini_ex's Application.put_env(:gemini, :auth, ...)
  end
end
```

#### 1.4 Message Format Transformation
Bridge message formats between ex_llm and gemini_ex:

```elixir
defmodule ExLLM.Adapters.Gemini.MessageTransformer do
  @moduledoc """
  Transforms between ex_llm and gemini_ex message formats.
  """
  
  # ex_llm: [%{role: "user", content: "text"}]
  # gemini_ex: [%Gemini.Types.Content{parts: [%{text: "text"}]}]
  
  def to_gemini_format(ex_llm_messages) do
    # Implementation
  end
  
  def from_gemini_format(gemini_response) do
    # Implementation  
  end
end
```

### Phase 2: Enhanced Integration (Medium Term)

#### 2.1 Streaming Unification
**Goal**: Make gemini_ex streaming work seamlessly with ex_llm's stream interface

```elixir
defmodule ExLLM.Adapters.Gemini.StreamBridge do
  @moduledoc """
  Bridges gemini_ex streaming to ex_llm stream format.
  """
  
  def create_stream(gemini_stream_id) do
    Stream.resource(
      fn -> setup_gemini_stream(gemini_stream_id) end,
      fn state -> next_chunk(state) end,
      fn state -> cleanup_stream(state) end
    )
  end
  
  defp next_chunk(state) do
    # Convert gemini_ex stream events to ex_llm chunk format
    receive do
      {:stream_event, ^stream_id, %{type: :data, data: data}} ->
        chunk = %ExLLM.Types.StreamChunk{
          content: extract_text(data),
          finish_reason: nil,
          model: state.model
        }
        {[chunk], state}
        
      {:stream_complete, ^stream_id} ->
        {:halt, state}
    end
  end
end
```

#### 2.2 Error Mapping
Create comprehensive error mapping:

```elixir
defmodule ExLLM.Adapters.Gemini.ErrorMapper do
  @moduledoc """
  Maps gemini_ex errors to ex_llm error format.
  """
  
  def map_error(%Gemini.Error{} = error) do
    %ExLLM.Error{
      type: map_error_type(error.type),
      message: error.message,
      details: %{
        provider: :gemini,
        original_error: error
      }
    }
  end
end
```

#### 2.3 Enhanced Type Safety
Extend ex_llm types to leverage gemini_ex's comprehensive types:

```elixir
defmodule ExLLM.Types.GeminiExtensions do
  @moduledoc """
  Gemini-specific extensions to ex_llm types.
  """
  
  # Add Gemini-specific fields while maintaining ex_llm compatibility
  defstruct [:safety_ratings, :citation_metadata, :grounding_attributions]
end
```

### Phase 3: Structured Output Evolution (Future)

#### 3.1 Current State: Instructor.ex Integration
Currently, ex_llm uses instructor.ex for structured outputs:

```elixir
# Current ex_llm approach
{:ok, result} = ExLLM.Instructor.chat(:gemini, messages,
  response_model: EmailClassification,
  max_retries: 3
)
```

#### 3.2 Future State: Native Gemini Structured Output
Gemini's native structured output (responseSchema) is more powerful than instructor.ex:

```elixir
# Future gemini_ex native approach  
{:ok, result} = Gemini.generate_structured(messages,
  response_schema: %{
    type: "object",
    properties: %{
      classification: %{type: "string", enum: ["spam", "not_spam"]},
      confidence: %{type: "number", minimum: 0.0, maximum: 1.0}
    }
  }
)
```

#### 3.3 Migration Strategy
1. **Phase 3a**: Keep instructor.ex support for backward compatibility
2. **Phase 3b**: Add native Gemini structured output option
3. **Phase 3c**: Deprecate instructor.ex for Gemini provider
4. **Phase 3d**: Full migration to native structured output

```elixir
# Bridge implementation
defmodule ExLLM.Adapters.Gemini.StructuredOutput do
  def handle_structured_request(messages, options) do
    case Keyword.get(options, :structured_output_mode, :instructor) do
      :instructor -> 
        # Use current instructor.ex approach
        use_instructor_approach(messages, options)
        
      :native ->
        # Use gemini_ex native structured output
        use_native_gemini_approach(messages, options)
        
      :auto ->
        # Automatically choose best approach
        choose_best_approach(messages, options)
    end
  end
end
```

## Implementation Roadmap

### Week 1-2: Foundation Setup
- [ ] Set up unified repository structure
- [ ] Update mix.exs with unified dependencies
- [ ] Create basic adapter bridge (ExLLM.Adapters.Gemini)
- [ ] Implement message format transformers
- [ ] Basic configuration bridge

### Week 3-4: Core Integration  
- [ ] Complete chat functionality bridge
- [ ] Implement streaming bridge
- [ ] Error mapping system
- [ ] Basic test suite for integration
- [ ] Documentation updates

### Week 5-6: Enhanced Features
- [ ] Session management integration
- [ ] Cost tracking for Gemini via gemini_ex
- [ ] Function calling bridge
- [ ] Context management integration
- [ ] Retry logic coordination

### Week 7-8: Production Readiness
- [ ] Comprehensive test coverage
- [ ] Performance optimization
- [ ] Error handling edge cases
- [ ] Telemetry integration
- [ ] Production deployment guide

### Future Quarters: Advanced Features
- [ ] Native structured output implementation
- [ ] Instructor.ex deprecation path
- [ ] Advanced streaming features
- [ ] Performance benchmarking
- [ ] Extended Gemini API coverage

## Technical Decisions

### 1. Dependency Management
**Decision**: Keep gemini_ex as embedded dependency rather than external
**Rationale**: Tighter integration, faster iteration, unified versioning

### 2. Streaming Architecture
**Decision**: Use gemini_ex streaming as the source of truth
**Rationale**: More mature, feature-complete streaming implementation

### 3. Configuration Strategy  
**Decision**: Bridge pattern - support both config systems
**Rationale**: Backward compatibility while leveraging best of both

### 4. Error Handling
**Decision**: Map gemini_ex errors to ex_llm format
**Rationale**: Maintain unified error interface across providers

### 5. Type Safety
**Decision**: Extend ex_llm types with optional Gemini-specific fields
**Rationale**: Enhanced capabilities without breaking changes

## Success Metrics

### Phase 1 Success
- [ ] All ex_llm Gemini tests pass with new adapter
- [ ] Basic chat functionality works
- [ ] Configuration bridge functional
- [ ] No regression in ex_llm functionality

### Phase 2 Success  
- [ ] Streaming works seamlessly
- [ ] Error handling comprehensive
- [ ] Performance matches or exceeds current implementation
- [ ] Full feature parity with original ex_llm Gemini adapter

### Phase 3 Success
- [ ] Native structured output available
- [ ] Migration path from instructor.ex clear
- [ ] Performance improvement over instructor.ex
- [ ] Comprehensive schema support

## Risks and Mitigations

### Risk 1: Complexity Explosion
**Mitigation**: Start with minimal viable bridge, iterate incrementally

### Risk 2: Performance Degradation  
**Mitigation**: Benchmark early and often, optimize hot paths

### Risk 3: Breaking Changes
**Mitigation**: Maintain backward compatibility, clear deprecation paths

### Risk 4: Configuration Conflicts
**Mitigation**: Clear precedence rules, comprehensive testing

## Conclusion

This integration plan provides a path to combine the best of both libraries:
- gemini_ex's comprehensive Gemini API implementation becomes the engine
- ex_llm's unified provider interface becomes the user-facing API  
- Users get both multi-provider support AND best-in-class Gemini features

The phased approach minimizes risk while delivering immediate value, with a clear path to advanced features like native structured output that will surpass current instructor.ex capabilities. 