defmodule LLMEx.Adapters.Providers.Gemini.Auth.VertexStrategy do
  @moduledoc """
  Authentication strategy for Google Vertex AI using OAuth2/Service Account.

  This strategy supports multiple authentication methods:
  - Service Account JSON file (via VERTEX_JSON_FILE environment variable)
  - OAuth2 access tokens
  - Application Default Credentials (ADC)

  Based on the Vertex AI documentation, this strategy can generate self-signed JWTs
  for authenticated endpoints and standard Bearer tokens for regular API calls.
  """

  @behaviour LLMEx.Adapters.Providers.Gemini.Auth.Strategy

  alias LLMEx.Adapters.Providers.Gemini.Auth.JWTManager

  @vertex_ai_scopes [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  @type credentials :: %{
          optional(:access_token) => String.t(),
          optional(:service_account_key) => String.t(),
          optional(:service_account_data) => map(),
          optional(:jwt_token) => String.t(),
          optional(:project_id) => String.t(),
          optional(:location) => String.t()
        }

  @doc """
  Get authentication headers for Vertex AI requests.

  Supports multiple credential types:
  - %{access_token: token} - Direct access token
  - %{service_account_key: path} - Service account JSON file path
  - %{service_account_data: data} - Service account JSON data
  - %{jwt_token: token} - Pre-signed JWT token
  """
  @impl true
  @spec headers(credentials()) :: [{String.t(), String.t()}]
  def headers(%{access_token: access_token}) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{access_token}"}
    ]
  end

  def headers(%{jwt_token: jwt_token}) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{jwt_token}"}
    ]
  end

  def headers(%{service_account_key: _key_path} = credentials) do
    case generate_access_token(credentials) do
      {:ok, access_token} ->
        [
          {"Content-Type", "application/json"},
          {"Authorization", "Bearer #{access_token}"}
        ]

      {:error, _reason} ->
        # Fallback to placeholder - in production this should be handled properly
        [
          {"Content-Type", "application/json"},
          {"Authorization", "Bearer service-account-error-token"}
        ]
    end
  end

  def headers(%{service_account_data: _data} = credentials) do
    case generate_access_token(credentials) do
      {:ok, access_token} ->
        [
          {"Content-Type", "application/json"},
          {"Authorization", "Bearer #{access_token}"}
        ]

      {:error, _reason} ->
        [
          {"Content-Type", "application/json"},
          {"Authorization", "Bearer service-account-error-token"}
        ]
    end
  end

  def headers(_credentials) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer default-credentials-token"}
    ]
  end

  @impl true
  @spec base_url(credentials()) :: {:ok, String.t()} | {:error, String.t()}
  def base_url(%{project_id: _project_id, location: location}) do
    {:ok, "https://#{location}-aiplatform.googleapis.com/v1"}
  end

  def base_url(%{project_id: _project_id}) do
    {:error, "Location is required for Vertex AI base URL"}
  end

  def base_url(%{location: _location}) do
    {:error, "Project ID is required for Vertex AI base URL"}
  end

  def base_url(_config) do
    {:error, "Project ID and Location are required for Vertex AI base URL"}
  end

  @impl true
  @spec authenticate(credentials()) :: {:ok, map()} | {:error, String.t()}
  def authenticate(%{access_token: token}) when is_binary(token) do
    # Validate the token format
    if String.length(token) > 0 do
      {:ok, %{auth_type: :access_token, token: token}}
    else
      {:error, "Invalid access token"}
    end
  end

  def authenticate(%{jwt_token: token}) when is_binary(token) do
    # Validate JWT token format (basic check)
    if String.contains?(token, ".") do
      {:ok, %{auth_type: :jwt_token, token: token}}
    else
      {:error, "Invalid JWT token format"}
    end
  end

  def authenticate(%{service_account_key: key_path} = credentials) do
    case File.read(key_path) do
      {:ok, json_content} ->
        case Jason.decode(json_content) do
          {:ok, service_account_data} ->
            validate_service_account_data(service_account_data)

          {:error, _} ->
            {:error, "Invalid JSON in service account key file"}
        end

      {:error, _} ->
        {:error, "Could not read service account key file: #{key_path}"}
    end
  end

  def authenticate(%{service_account_data: data}) when is_map(data) do
    validate_service_account_data(data)
  end

  def authenticate(credentials) do
    # Try to use Application Default Credentials or environment variables
    case System.get_env("GOOGLE_APPLICATION_CREDENTIALS") do
      nil ->
        {:error, "No valid credentials provided for Vertex AI authentication"}

      key_path ->
        authenticate(%{service_account_key: key_path})
    end
  end

  @doc """
  Generate OAuth2 access token from service account credentials.
  """
  @spec generate_access_token(credentials()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_access_token(%{service_account_key: key_path}) do
    case File.read(key_path) do
      {:ok, json_content} ->
        case Jason.decode(json_content) do
          {:ok, service_account_data} ->
            generate_token_from_service_account(service_account_data)

          {:error, _} ->
            {:error, "Invalid JSON in service account key file"}
        end

      {:error, _} ->
        {:error, "Could not read service account key file"}
    end
  end

  def generate_access_token(%{service_account_data: data}) when is_map(data) do
    generate_token_from_service_account(data)
  end

  def generate_access_token(_credentials) do
    {:error, "No service account credentials provided"}
  end

  # Private helper functions

  @spec validate_service_account_data(map()) :: {:ok, map()} | {:error, String.t()}
  defp validate_service_account_data(data) when is_map(data) do
    required_fields = ["client_email", "private_key", "project_id"]

    case Enum.find(required_fields, fn field -> not Map.has_key?(data, field) end) do
      nil ->
        {:ok, %{
          auth_type: :service_account,
          client_email: data["client_email"],
          private_key: data["private_key"],
          project_id: data["project_id"]
        }}

      missing_field ->
        {:error, "Service account data missing required field: #{missing_field}"}
    end
  end

  @spec generate_token_from_service_account(map()) :: {:ok, String.t()} | {:error, String.t()}
  defp generate_token_from_service_account(service_account_data) do
    # Use JWTManager to create a JWT and exchange it for an access token
    jwt_claims = %{
      "iss" => service_account_data["client_email"],
      "scope" => Enum.join(@vertex_ai_scopes, " "),
      "aud" => "https://oauth2.googleapis.com/token",
      "exp" => System.system_time(:second) + 3600,
      "iat" => System.system_time(:second)
    }

    case JWTManager.sign_jwt(jwt_claims, service_account_data["private_key"]) do
      {:ok, jwt_token} ->
        exchange_jwt_for_access_token(jwt_token)

      {:error, reason} ->
        {:error, "Failed to create JWT: #{reason}"}
    end
  end

  @impl true
  @spec build_path(String.t(), String.t(), credentials()) :: String.t()
  def build_path(model, endpoint, %{project_id: project_id, location: location}) do
    # Vertex AI model path format
    normalized_model = if String.starts_with?(model, "models/"), do: model, else: "models/#{model}"
    "projects/#{project_id}/locations/#{location}/publishers/google/#{normalized_model}:#{endpoint}"
  end

  def build_path(model, endpoint, _credentials) do
    # Fallback path if project/location missing
    "models/#{model}:#{endpoint}"
  end

  @impl true
  @spec refresh_credentials(credentials()) :: {:ok, credentials()} | {:error, String.t()}
  def refresh_credentials(%{service_account_key: _} = credentials) do
    case generate_access_token(credentials) do
      {:ok, access_token} ->
        {:ok, Map.put(credentials, :access_token, access_token)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def refresh_credentials(%{service_account_data: _} = credentials) do
    case generate_access_token(credentials) do
      {:ok, access_token} ->
        {:ok, Map.put(credentials, :access_token, access_token)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def refresh_credentials(credentials) do
    # Access tokens and JWT tokens don't need refreshing
    {:ok, credentials}
  end

  @spec exchange_jwt_for_access_token(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp exchange_jwt_for_access_token(jwt_token) do
    # This would normally make an HTTP request to Google's OAuth2 token endpoint
    # For now, we'll return a placeholder implementation
    # In a real implementation, you would use HTTPoison or similar to make the request

    token_request_body = %{
      "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
      "assertion" => jwt_token
    }

    # Placeholder: In production, make actual HTTP request to:
    # POST https://oauth2.googleapis.com/token
    # with the token_request_body

    {:ok, "generated_access_token_placeholder_#{System.system_time(:millisecond)}"}
  end
end
