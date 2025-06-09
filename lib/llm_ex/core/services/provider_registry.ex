defmodule LLMEx.Core.Services.ProviderRegistry do
  @moduledoc """
  Service for managing and accessing LLM provider adapters.
  """

  use GenServer

  alias LLMEx.Core.Entities.Provider

  @doc """
  Starts the provider registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a provider adapter.
  """
  def register_provider(provider_name, adapter_module, config \\ %{}) do
    GenServer.call(__MODULE__, {:register, provider_name, adapter_module, config})
  end

  @doc """
  Gets the adapter module for a provider.
  """
  def get_adapter(provider_name) do
    GenServer.call(__MODULE__, {:get_adapter, provider_name})
  end

  @doc """
  Gets the provider configuration.
  """
  def get_provider(provider_name) do
    GenServer.call(__MODULE__, {:get_provider, provider_name})
  end

  @doc """
  Lists all registered providers.
  """
  def list_providers do
    GenServer.call(__MODULE__, :list_providers)
  end

  @doc """
  Checks if a provider is registered.
  """
  def provider_registered?(provider_name) do
    GenServer.call(__MODULE__, {:provider_registered?, provider_name})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %{
      providers: %{},
      adapters: %{}
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:register, provider_name, adapter_module, config}, _from, state) do
    provider = Provider.new(provider_name, config)

    new_state = %{state |
      providers: Map.put(state.providers, provider_name, provider),
      adapters: Map.put(state.adapters, provider_name, adapter_module)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_adapter, provider_name}, _from, state) do
    case Map.get(state.adapters, provider_name) do
      nil -> {:reply, {:error, :provider_not_found}, state}
      adapter -> {:reply, {:ok, adapter}, state}
    end
  end

  @impl true
  def handle_call({:get_provider, provider_name}, _from, state) do
    case Map.get(state.providers, provider_name) do
      nil -> {:reply, {:error, :provider_not_found}, state}
      provider -> {:reply, {:ok, provider}, state}
    end
  end

  @impl true
  def handle_call(:list_providers, _from, state) do
    providers = Map.keys(state.providers)
    {:reply, {:ok, providers}, state}
  end

  @impl true
  def handle_call({:provider_registered?, provider_name}, _from, state) do
    registered = Map.has_key?(state.providers, provider_name)
    {:reply, registered, state}
  end
end
