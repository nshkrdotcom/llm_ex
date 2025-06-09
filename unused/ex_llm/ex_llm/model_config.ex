defmodule ExLLM.ModelConfig do
  @moduledoc """
  Model configuration loader for ExLLM.

  Loads model information from external YAML configuration files including:
  - Model pricing information
  - Context window sizes
  - Model capabilities
  - Default models per provider

  Configuration files are located in `config/models/` and organized by provider.
  """

  alias ExLLM.Logger

  # Get the config directory path
  defp config_dir do
    # Try to find the config directory relative to the current file
    case File.exists?("config/models") do
      true ->
        Path.expand("config/models")

      false ->
        # Fallback: look for it relative to the compiled beam file
        :code.priv_dir(:ex_llm)
        |> Path.join("../../config/models")
        |> Path.expand()
    end
  end

  @providers [
    :anthropic,
    :openai,
    :openrouter,
    :gemini,
    :ollama,
    :bedrock,
    :mistral,
    :perplexity,
    :bumblebee,
    :lmstudio,
    :xai
  ]

  # Cache configuration to avoid repeated file reads
  @config_cache :model_config_cache

  @doc """
  Gets the pricing information for a specific provider and model.

  Returns a map with `:input` and `:output` pricing per 1M tokens,
  or `nil` if the model is not found.

  ## Examples

      iex> ExLLM.ModelConfig.get_pricing(:openai, "gpt-4o")
      %{input: 2.50, output: 10.00}

      iex> ExLLM.ModelConfig.get_pricing(:anthropic, "claude-3-5-sonnet-20241022")
      %{input: 3.00, output: 15.00}

      iex> ExLLM.ModelConfig.get_pricing(:unknown_provider, "model")
      nil
  """
  def get_pricing(provider, model) when is_atom(provider) and is_binary(model) do
    case get_model_config(provider, model) do
      nil -> nil
      model_config -> Map.get(model_config, :pricing)
    end
  end

  @doc """
  Gets the context window size for a specific provider and model.

  Returns the context window size in tokens, or `nil` if not found.

  ## Examples

      iex> ExLLM.ModelConfig.get_context_window(:openai, "gpt-4o")
      128000

      iex> ExLLM.ModelConfig.get_context_window(:anthropic, "claude-3-5-sonnet-20241022")
      200000
  """
  def get_context_window(provider, model) when is_atom(provider) and is_binary(model) do
    case get_model_config(provider, model) do
      nil -> nil
      model_config -> Map.get(model_config, :context_window)
    end
  end

  @doc """
  Gets the capabilities for a specific provider and model.

  Returns a list of capability atoms, or `nil` if not found.

  ## Examples

      iex> ExLLM.ModelConfig.get_capabilities(:openai, "gpt-4o")
      [:text, :vision, :function_calling, :streaming]
  """
  def get_capabilities(provider, model) when is_atom(provider) and is_binary(model) do
    case get_model_config(provider, model) do
      nil -> nil
      model_config -> Map.get(model_config, :capabilities, [])
    end
  end

  @doc """
  Gets the default model for a provider.

  Returns the default model name as a string, or `nil` if not found.

  ## Examples

      iex> ExLLM.ModelConfig.get_default_model(:openai)
      "gpt-4.1-mini"

      iex> ExLLM.ModelConfig.get_default_model(:anthropic)
      "claude-sonnet-4-20250514"
  """
  def get_default_model(provider) when is_atom(provider) do
    case get_provider_config(provider) do
      nil ->
        raise "Missing configuration file: config/models/#{provider}.yml. " <>
                "Please ensure the YAML configuration file exists and is properly formatted."

      config ->
        case Map.get(config, :default_model) do
          nil ->
            raise "Missing 'default_model' in config/models/#{provider}.yml. " <>
                    "Please add a default_model field to the configuration."

          model ->
            model
        end
    end
  end

  @doc """
  Gets all models for a provider.

  Returns a map of model names to their configurations.

  ## Examples

      iex> models = ExLLM.ModelConfig.get_all_models(:anthropic)
      iex> Map.keys(models)
      ["claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022", ...]
  """
  def get_all_models(provider) when is_atom(provider) do
    case get_provider_config(provider) do
      nil -> %{}
      config -> Map.get(config, :models, %{})
    end
  end

  @doc """
  Gets all pricing information for a provider.

  Returns a map of model names to pricing maps (with `:input` and `:output` keys).

  ## Examples

      iex> pricing = ExLLM.ModelConfig.get_all_pricing(:openai)
      iex> pricing["gpt-4o"]
      %{input: 2.50, output: 10.00}
  """
  def get_all_pricing(provider) when is_atom(provider) do
    case get_provider_config(provider) do
      nil ->
        %{}

      config ->
        models = Map.get(config, :models, %{})

        models
        |> Enum.map(fn {model_name, model_config} ->
          pricing = Map.get(model_config, :pricing)
          {model_name, pricing}
        end)
        |> Enum.reject(fn {_model, pricing} -> is_nil(pricing) end)
        |> Map.new()
    end
  end

  @doc """
  Gets all context window information for a provider.

  Returns a map of model names to context window sizes.

  ## Examples

      iex> contexts = ExLLM.ModelConfig.get_all_context_windows(:anthropic)
      iex> contexts["claude-3-5-sonnet-20241022"]
      200000
  """
  def get_all_context_windows(provider) when is_atom(provider) do
    case get_provider_config(provider) do
      nil ->
        %{}

      config ->
        models = Map.get(config, :models, %{})

        models
        |> Enum.map(fn {model_name, model_config} ->
          context_window = Map.get(model_config, :context_window)
          {model_name, context_window}
        end)
        |> Enum.reject(fn {_model, context_window} -> is_nil(context_window) end)
        |> Map.new()
    end
  end

  @doc """
  Gets the full configuration for a specific model.

  Returns the model configuration map or nil if not found.

  ## Examples

      iex> ExLLM.ModelConfig.get_model_config(:openai, "gpt-4o")
      %{
        context_window: 128000,
        pricing: %{input: 2.50, output: 10.00},
        capabilities: [:streaming, :function_calling]
      }
  """
  def get_model_config(provider, model) when is_atom(provider) and is_binary(model) do
    case get_provider_config(provider) do
      nil ->
        nil

      config ->
        models = Map.get(config, :models, %{})
        # Models should be keyed by strings
        Map.get(models, model)
    end
  end

  @doc """
  Reloads all configuration from files.

  Clears the cache and forces a reload of all configuration files.
  Useful during development or when configuration files are updated.
  """
  def reload_config do
    # Clear the cache
    try do
      :ets.delete(@config_cache)
    catch
      :error, :badarg -> :ok
    end

    # Recreate the cache table
    :ets.new(@config_cache, [:set, :public, :named_table])

    # Preload all provider configs
    Enum.each(@providers, &get_provider_config/1)

    :ok
  end

  # Private functions

  defp get_provider_config(provider) do
    # Initialize cache table if it doesn't exist
    ensure_cache_table()

    # Try to get from cache first
    try do
      case :ets.lookup(@config_cache, provider) do
        [{^provider, config}] ->
          config

        [] ->
          # Load from file and cache result
          config = load_provider_config(provider)

          try do
            :ets.insert(@config_cache, {provider, config})
          catch
            :error, :badarg ->
              # Table doesn't exist, ensure it's created and retry
              ensure_cache_table()
              :ets.insert(@config_cache, {provider, config})
          end

          config
      end
    catch
      :error, :badarg ->
        # Table doesn't exist, load from file without caching
        load_provider_config(provider)
    end
  end

  def ensure_cache_table do
    case :ets.info(@config_cache) do
      :undefined ->
        try do
          :ets.new(@config_cache, [:set, :public, :named_table])
        catch
          :error, :badarg ->
            # Table might have been created by another process in the meantime
            case :ets.info(@config_cache) do
              :undefined ->
                # Still doesn't exist, re-raise the error
                :ets.new(@config_cache, [:set, :public, :named_table])

              _ ->
                :ok
            end
        end

      _ ->
        :ok
    end
  end

  defp load_provider_config(provider) do
    config_file = Path.join(config_dir(), "#{provider}.yml")

    Logger.debug("Loading config for #{provider} from #{config_file}")
    Logger.debug("File exists? #{File.exists?(config_file)}")

    if File.exists?(config_file) do
      case YamlElixir.read_from_file(config_file) do
        {:ok, config} ->
          Logger.debug("Loaded YAML config for #{provider}, keys: #{inspect(Map.keys(config))}")
          # Convert string keys to atoms for easier access
          normalized = normalize_config(config)
          Logger.debug("Normalized config keys: #{inspect(Map.keys(normalized))}")
          normalized

        {:error, reason} ->
          Logger.warn("Failed to load model config for #{provider}: #{inspect(reason)}")
          nil
      end
    else
      Logger.debug("Model config file not found: #{config_file}")
      nil
    end
  end

  # Recursively convert string keys to atoms for nested maps
  defp normalize_config(config) when is_map(config) do
    config
    |> Enum.map(fn {key, value} ->
      atom_key = if is_binary(key), do: safe_atomize_key(key), else: key
      {atom_key, normalize_config(value)}
    end)
    |> Map.new()
  end

  defp normalize_config(config) when is_list(config) do
    Enum.map(config, &normalize_config/1)
  end

  defp normalize_config(config), do: config

  # Safe atomization of known configuration keys
  defp safe_atomize_key(key) when is_binary(key) do
    # Known top-level and nested keys in model configs
    case key do
      # Top-level config fields
      "provider" -> :provider
      "default_model" -> :default_model
      "models" -> :models
      "metadata" -> :metadata
      # Top-level model fields
      "name" -> :name
      "context_window" -> :context_window
      "max_output_tokens" -> :max_output_tokens
      "capabilities" -> :capabilities
      "pricing" -> :pricing
      "default" -> :default
      "architecture" -> :architecture
      "quantization" -> :quantization
      "supports_streaming" -> :supports_streaming
      "supports_tools" -> :supports_tools
      "features" -> :features
      # Pricing fields
      "input" -> :input
      "output" -> :output
      # Capability fields  
      "vision" -> :vision
      "function_calling" -> :function_calling
      "streaming" -> :streaming
      "embeddings" -> :embeddings
      "audio" -> :audio
      "tools" -> :tools
      # Feature flags
      "supported" -> :supported
      "formats" -> :formats
      # Keep model IDs as strings since they're dynamic
      _ -> key
    end
  end
end
