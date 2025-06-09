defmodule LLMEx.Adapters.Providers.Gemini.Auth.MultiAuthCoordinator do
  @moduledoc """
  Coordinates multiple authentication strategies for concurrent usage.

  Enables per-request auth strategy selection while maintaining
  independent credential management and request routing.

  This module serves as the central coordination point for the Gemini
  implementation's multi-auth capability, allowing applications to use both
  Gemini API and Vertex AI authentication strategies simultaneously.
  """

  alias LLMEx.Adapters.Providers.Gemini.Auth.{GeminiStrategy, VertexStrategy}
  alias LLMEx.Core.Entities.Provider

  @type auth_strategy :: :gemini | :vertex_ai
  @type credentials :: map()
  @type auth_result :: {:ok, auth_strategy(), headers :: list()} | {:error, term()}
  @type request_opts :: keyword()

  @doc """
  Coordinates authentication for the specified strategy.

  This is the main entry point for multi-auth coordination. It routes
  authentication requests to the appropriate strategy while maintaining
  independent credential management.

  ## Parameters
  - `strategy`: The authentication strategy (`:gemini` or `:vertex_ai`)
  - `opts`: Request options (may include configuration overrides)

  ## Returns
  - `{:ok, strategy, headers}` on successful authentication
  - `{:error, reason}` on authentication failure

  ## Examples

      # Coordinate Gemini API authentication
      {:ok, :gemini, headers} = MultiAuthCoordinator.coordinate_auth(:gemini, [])

      # Coordinate Vertex AI authentication
      {:ok, :vertex_ai, headers} = MultiAuthCoordinator.coordinate_auth(:vertex_ai, [])

      # With configuration overrides
      {:ok, :gemini, headers} = MultiAuthCoordinator.coordinate_auth(:gemini, [api_key: "override"])
  """
  @spec coordinate_auth(auth_strategy(), request_opts()) :: auth_result()
  def coordinate_auth(strategy, opts \\ [])

  def coordinate_auth(:gemini, opts) do
    with {:ok, credentials} <- get_credentials(:gemini, opts) do
      case GeminiStrategy.authenticate(credentials) do
        {:ok, _auth_data} ->
          headers = GeminiStrategy.headers(credentials)
          {:ok, :gemini, headers}

        {:error, reason} ->
          {:error, "Gemini auth failed: #{reason}"}
      end
    else
      {:error, reason} -> {:error, "Gemini auth failed: #{reason}"}
    end
  end

  def coordinate_auth(:vertex_ai, opts) do
    with {:ok, credentials} <- get_credentials(:vertex_ai, opts) do
      case VertexStrategy.authenticate(credentials) do
        {:ok, _auth_data} ->
          headers = VertexStrategy.headers(credentials)
          {:ok, :vertex_ai, headers}

        {:error, reason} ->
          {:error, "Vertex AI auth failed: #{reason}"}
      end
    else
      {:error, reason} -> {:error, "Vertex AI auth failed: #{reason}"}
    end
  end

  def coordinate_auth(strategy, _opts) do
    {:error, "Unknown authentication strategy: #{inspect(strategy)}"}
  end

  @doc """
  Retrieves credentials for the specified authentication strategy.

  Loads credentials from configuration, with optional overrides from request options.

  ## Parameters
  - `strategy`: The authentication strategy
  - `opts`: Optional configuration overrides

  ## Returns
  - `{:ok, credentials}` on success
  - `{:error, reason}` on failure
  """
  @spec get_credentials(auth_strategy(), request_opts()) ::
          {:ok, credentials()} | {:error, term()}
  def get_credentials(strategy, opts \\ [])

  def get_credentials(:gemini, opts) do
    base_config = get_auth_config(:gemini)

    # Allow api_key override from opts
    api_key = Keyword.get(opts, :api_key, base_config[:api_key])

    case api_key do
      key when is_binary(key) and key != "" ->
        {:ok, %{api_key: key}}

      _ ->
        {:error, "Missing or invalid Gemini API key"}
    end
  end

  def get_credentials(:vertex_ai, opts) do
    base_config = get_auth_config(:vertex_ai)

    # Build credentials from config and opts
    credentials = %{}

    # Project ID (required)
    project_id = Keyword.get(opts, :project_id, base_config[:project_id])

    credentials =
      if project_id, do: Map.put(credentials, :project_id, project_id), else: credentials

    # Location (required)
    location = Keyword.get(opts, :location, base_config[:location] || "us-central1")
    credentials = Map.put(credentials, :location, location)

    # Auth method - prioritize opts, then config
    cond do
      access_token = Keyword.get(opts, :access_token) ->
        {:ok, Map.put(credentials, :access_token, access_token)}

      service_account_key =
          Keyword.get(opts, :service_account_key, base_config[:service_account_key]) ->
        {:ok, Map.put(credentials, :service_account_key, service_account_key)}

      service_account_data =
          Keyword.get(opts, :service_account_data, base_config[:service_account_data]) ->
        {:ok, Map.put(credentials, :service_account_data, service_account_data)}

      base_config[:access_token] ->
        {:ok, Map.put(credentials, :access_token, base_config[:access_token])}

      true ->
        case {credentials[:project_id], credentials[:location]} do
          {nil, _} -> {:error, "Missing Vertex AI project_id"}
          {_, nil} -> {:error, "Missing Vertex AI location"}
          _ -> {:error, "Missing Vertex AI authentication method"}
        end
    end
  end

  def get_credentials(strategy, _opts) do
    {:error, "Unknown authentication strategy: #{inspect(strategy)}"}
  end

  @doc """
  Determine the appropriate authentication strategy from credentials.

  Analyzes provided credentials to determine which auth strategy should be used.
  """
  @spec determine_strategy(Provider.credentials()) ::
    {:ok, auth_strategy()} | {:error, term()}
  def determine_strategy(credentials) when is_map(credentials) do
    cond do
      Map.has_key?(credentials, :api_key) ->
        {:ok, :gemini}

      Map.has_key?(credentials, :project_id) ->
        {:ok, :vertex_ai}

      true ->
        {:error, "Cannot determine auth strategy from credentials"}
    end
  end

  @doc """
  Get authentication base URL for the strategy.
  """
  @spec get_base_url(auth_strategy(), credentials()) :: String.t()
  def get_base_url(:gemini, _credentials) do
    GeminiStrategy.base_url(%{})
  end

  def get_base_url(:vertex_ai, credentials) do
    VertexStrategy.base_url(credentials)
  end

  @doc """
  Build API path for the given strategy and parameters.
  """
  @spec build_path(auth_strategy(), String.t(), String.t(), credentials()) :: String.t()
  def build_path(:gemini, model, endpoint, credentials) do
    GeminiStrategy.build_path(model, endpoint, credentials)
  end

  def build_path(:vertex_ai, model, endpoint, credentials) do
    VertexStrategy.build_path(model, endpoint, credentials)
  end

  @doc """
  Refresh credentials for the specified authentication strategy.

  ## Returns
  - `{:ok, refreshed_credentials}` on success
  - `{:error, reason}` on failure
  """
  @spec refresh_credentials(auth_strategy()) :: {:ok, credentials()} | {:error, term()}
  def refresh_credentials(:gemini) do
    # Gemini API keys don't need refreshing
    get_credentials(:gemini)
  end

  def refresh_credentials(:vertex_ai) do
    with {:ok, credentials} <- get_credentials(:vertex_ai) do
      VertexStrategy.refresh_credentials(credentials)
    end
  end

  def refresh_credentials(strategy) do
    {:error, "Unknown authentication strategy: #{inspect(strategy)}"}
  end

  # Private helper functions

  defp get_auth_config(:gemini) do
    case System.get_env("GEMINI_API_KEY") do
      nil ->
        # Check application config
        case Application.get_env(:llm_ex, :gemini_api_key) do
          nil -> %{}
          api_key -> %{api_key: api_key}
        end

      api_key ->
        %{api_key: api_key}
    end
  end

  defp get_auth_config(:vertex_ai) do
    config = %{}

    # Add project_id if available
    config =
      case System.get_env("VERTEX_PROJECT_ID") || System.get_env("GOOGLE_CLOUD_PROJECT") do
        nil -> config
        project_id -> Map.put(config, :project_id, project_id)
      end

    # Add location
    location = System.get_env("VERTEX_LOCATION") || System.get_env("GOOGLE_CLOUD_LOCATION") || "us-central1"
    config = Map.put(config, :location, location)

    # Add authentication method
    cond do
      System.get_env("VERTEX_ACCESS_TOKEN") ->
        Map.put(config, :access_token, System.get_env("VERTEX_ACCESS_TOKEN"))

      System.get_env("VERTEX_SERVICE_ACCOUNT") || System.get_env("VERTEX_JSON_FILE") ->
        service_account = System.get_env("VERTEX_SERVICE_ACCOUNT") || System.get_env("VERTEX_JSON_FILE")
        Map.put(config, :service_account_key, service_account)

      true ->
        # Check application config
        app_config = Application.get_env(:llm_ex, :vertex_ai, %{})
        Map.merge(config, app_config)
    end
  end
end
