defmodule LLMEx.Core.Ports.AuthProvider do
  @moduledoc """
  Port defining the contract for authentication providers.
  """

  @callback authenticate(map()) :: {:ok, map()} | {:error, term()}

  @callback refresh_token(map()) :: {:ok, map()} | {:error, term()}

  @callback validate_credentials(map()) :: :ok | {:error, term()}

  @optional_callbacks [refresh_token: 1]
end
