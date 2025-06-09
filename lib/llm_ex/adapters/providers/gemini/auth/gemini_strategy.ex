defmodule LLMEx.Adapters.Providers.Gemini.Auth.GeminiStrategy do
  @moduledoc """
  Authentication strategy for Google Gemini API using API key.

  This strategy uses the simple x-goog-api-key header authentication
  method used by the Gemini API.
  """

  @behaviour LLMEx.Adapters.Providers.Gemini.Auth.Strategy

  @base_url "https://generativelanguage.googleapis.com/v1beta"

  @doc """
  Authenticate with Gemini API using API key.
  """
  @spec authenticate(map()) :: {:ok, map()} | {:error, String.t()}
  def authenticate(%{api_key: api_key}) when is_binary(api_key) and api_key != "" do
    {:ok, %{api_key: api_key}}
  end

  def authenticate(%{api_key: nil}) do
    {:error, "API key is nil"}
  end

  def authenticate(%{api_key: ""}) do
    {:error, "API key is empty"}
  end

  def authenticate(%{}) do
    {:error, "API key is missing"}
  end

  def authenticate(_config) do
    {:error, "Invalid configuration for Gemini authentication"}
  end

  @impl true
  def headers(%{api_key: api_key}) do
    [
      {"Content-Type", "application/json"},
      {"x-goog-api-key", api_key}
    ]
  end

  @impl true
  def base_url(_credentials) do
    {:ok, @base_url}
  end

  @impl true
  def build_path(model, endpoint, _credentials) do
    # Normalize model name - add "models/" prefix if not present
    normalized_model =
      if String.starts_with?(model, "models/"), do: model, else: "models/#{model}"

    "#{normalized_model}:#{endpoint}"
  end

  @impl true
  def refresh_credentials(credentials) do
    # API keys don't need refreshing
    {:ok, credentials}
  end
end
