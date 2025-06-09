defmodule LLMEx.Adapters.Providers.Gemini.Auth.Strategy do
  @moduledoc """
  Behavior for authentication strategies in the Gemini adapter.

  Defines the contract that both Gemini API key and Vertex AI
  authentication strategies must implement.
  """

  @doc """
  Authenticate with the given credentials.
  """
  @callback authenticate(credentials :: map()) :: {:ok, map()} | {:error, term()}

  @doc """
  Build authentication headers for requests.
  """
  @callback headers(credentials :: map()) :: [{String.t(), String.t()}]

  @doc """
  Get the base URL for the authentication strategy.
  """
  @callback base_url(credentials :: map()) :: {:ok, String.t()} | {:error, String.t()} | String.t()

  @doc """
  Build the API path for a given model and endpoint.
  """
  @callback build_path(model :: String.t(), endpoint :: String.t(), credentials :: map()) :: String.t()

  @doc """
  Refresh credentials if needed (for token-based auth).
  """
  @callback refresh_credentials(credentials :: map()) :: {:ok, map()} | {:error, term()}
end
