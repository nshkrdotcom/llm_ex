defmodule LLMEx.Core.Entities.Provider do
  @moduledoc """
  Core provider entity representing an LLM provider configuration.
  """

  defstruct [
    :name,
    :type,
    :auth_config,
    :endpoints,
    :capabilities,
    :models,
    :rate_limits,
    :pricing,
    :status,
    :metadata
  ]

  @type capability :: :chat | :streaming | :embeddings | :function_calling | :vision | :tool_use

  @type t :: %__MODULE__{
          name: atom(),
          type: :api | :local | :vertex_ai,
          auth_config: map(),
          endpoints: map(),
          capabilities: [capability()],
          models: [String.t()],
          rate_limits: map() | nil,
          pricing: map() | nil,
          status: :active | :inactive | :error,
          metadata: map()
        }

  @doc """
  Creates a new provider configuration.
  """
  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      type: opts[:type] || :api,
      auth_config: opts[:auth_config] || %{},
      endpoints: opts[:endpoints] || %{},
      capabilities: opts[:capabilities] || [],
      models: opts[:models] || [],
      rate_limits: opts[:rate_limits],
      pricing: opts[:pricing],
      status: opts[:status] || :active,
      metadata: opts[:metadata] || %{}
    }
  end

  @doc """
  Checks if the provider supports a specific capability.
  """
  def supports?(%__MODULE__{capabilities: capabilities}, capability) do
    capability in capabilities
  end

  @doc """
  Checks if the provider supports a specific model.
  """
  def has_model?(%__MODULE__{models: models}, model) do
    model in models
  end

  @doc """
  Checks if the provider is active.
  """
  def active?(%__MODULE__{status: :active}), do: true
  def active?(%__MODULE__{}), do: false

  @doc """
  Gets the authentication type for the provider.
  """
  def auth_type(%__MODULE__{auth_config: %{type: type}}), do: type
  def auth_type(%__MODULE__{}), do: nil

  @doc """
  Updates the provider status.
  """
  def set_status(%__MODULE__{} = provider, status) do
    %{provider | status: status}
  end

  @doc """
  Adds a capability to the provider.
  """
  def add_capability(%__MODULE__{capabilities: capabilities} = provider, capability) do
    if capability in capabilities do
      provider
    else
      %{provider | capabilities: [capability | capabilities]}
    end
  end

  @doc """
  Adds a model to the provider.
  """
  def add_model(%__MODULE__{models: models} = provider, model) do
    if model in models do
      provider
    else
      %{provider | models: [model | models]}
    end
  end
end
