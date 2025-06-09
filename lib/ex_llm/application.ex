defmodule ExLLM.Application do
  @moduledoc """
  The ExLLM application supervisor.

  This application follows Clean Architecture principles with a hierarchical
  supervision tree that manages all core services, adapters, and infrastructure
  components of the unified LLM library.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Core Services Supervisor - Domain layer services
      ExLLM.Application.Supervisors.CoreServicesSupervisor,

      # Authentication Supervisor - Multi-provider auth coordination
      ExLLM.Application.Supervisors.AuthSupervisor,

      # Streaming Supervisor - Advanced streaming architecture
      ExLLM.Application.Supervisors.StreamingSupervisor,

      # Adapters Supervisor - Provider adapters and external integrations
      ExLLM.Application.Supervisors.AdaptersSupervisor
    ]

    opts = [
      strategy: :one_for_one,
      name: ExLLM.Application.Supervisor,
      max_restarts: 3,
      max_seconds: 5
    ]

    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    :ok
  end
end
