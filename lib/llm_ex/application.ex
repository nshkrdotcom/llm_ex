defmodule LLMEx.Application do
  @moduledoc """
  The LLMEx application supervisor implementing Clean Architecture.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Core services will be added as they're implemented
      # LLMEx.Application.Supervisors.CoreServicesSupervisor,
      # LLMEx.Application.Supervisors.AuthSupervisor,
      # LLMEx.Application.Supervisors.StreamingSupervisor,
      # LLMEx.Application.Supervisors.AdaptersSupervisor
    ]

    opts = [strategy: :one_for_one, name: LLMEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
