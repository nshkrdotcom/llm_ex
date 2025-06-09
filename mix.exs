defmodule LLMEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :llm_ex,
      version: "1.0.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Unified Elixir client library for Large Language Models",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :ssl],
      mod: {LLMEx.Application, []}
    ]
  end

  defp deps do
    [
      # Core HTTP and JSON
      {:req, "~> 0.4.0"},
      {:finch, "~> 0.18.0"},
      {:jason, "~> 1.4"},

      # Authentication (Gemini Vertex AI)
      {:joken, "~> 2.6"},
      {:goth, "~> 1.4"},

      # Streaming and WebSockets
      {:websockex, "~> 0.4.3"},

      # Telemetry
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6"},

      # Optional: Local models
      {:bumblebee, "~> 0.5.0", optional: true},
      {:nx, "~> 0.7.0", optional: true},
      {:exla, "~> 0.7.0", optional: true},

      # Optional: Structured output
      {:instructor, "~> 0.0.4", optional: true},

      # Dev/Test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["LLMEx Team"],
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "LLMEx",
      source_ref: "v1.0.0"
    ]
  end
end
