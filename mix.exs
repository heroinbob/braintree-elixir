defmodule Braintree.Mixfile do
  use Mix.Project

  @version "0.16.0"

  def project do
    [
      app: :braintree,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      description: description(),
      package: package(),
      name: "Braintree",
      deps: deps(),
      docs: docs(),
      dialyzer: [
        flags: [:unmatched_returns, :error_handling]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :xmerl, :telemetry],
      env: [
        environment: :sandbox,
        master_merchant_id: {:system, "BRAINTREE_MASTER_MERCHANT_ID"},
        merchant_id: {:system, "BRAINTREE_MERCHANT_ID"},
        private_key: {:system, "BRAINTREE_PRIVATE_KEY"},
        public_key: {:system, "BRAINTREE_PUBLIC_KEY"}
      ]
    ]
  end

  defp description do
    """
    Native Braintree client library for Elixir
    """
  end

  defp package do
    [
      maintainers: ["Parker Selbert"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sorentwo/braintree-elixir"},
      files: ~w(lib priv mix.exs README.md CHANGELOG.md LICENSE.txt)
    ]
  end

  defp deps do
    [
      {:hackney, ">= 1.15.0", optional: true},
      {:plug, ">= 1.12.0"},
      {:req, ">= 0.5.0", optional: true},
      {:telemetry, "~> 1.3"},
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: [:dev, :test], runtime: false},
      {:hammox, "~> 0.7", only: :test}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: @version,
      formatters: ["html"],
      extras: [
        "CHANGELOG.md",
        "README.md"
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
