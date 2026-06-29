defmodule Braintree.HTTP do
  @moduledoc """
  Base client for all server interaction, used by all endpoint specific
  modules.

  This request wrapper coordinates the remote server, headers, authorization
  and SSL options.

  Using `Braintree.HTTP` requires the presence of three config values:

  * `merchant_id` - Braintree merchant id
  * `private_key` - Braintree private key
  * `public_key` - Braintree public key

  All three values must be set or a `Braintree.ConfigError` will be raised at
  runtime. All those config values support the `{:system, "VAR_NAME"}` as a
  value - in which case the value will be read from the system environment with
  `System.get_env("VAR_NAME")`.

  Hackney is used by default as the HTTP adapter. You can change this by
  setting the `:http_adapter` config value to the adapter you wish to use.
  """

  alias Braintree.HTTP.HackneyAdapter

  @type error ::
          {:error, atom}
          | {:error, Error.t()}
          | {:error, binary}

  @type response :: {:ok, map} | error

  @type adapter_config :: %{
          module: atom(),
          options: keyword()
        }

  @doc """
  Returns the currently configured adapter. This is runtime safe
  so any changes to the config will be reflected here in real time.
  """
  @spec adapter() :: atom()
  def adapter do
    Braintree.get_env(:http_adapter, HackneyAdapter)
  end

  @doc """
  Returns the configuration options for the current adapter.
  """
  @spec adapter_options() :: keyword()
  def adapter_options do
    Braintree.get_env(:http_options, [])
  end

  @doc """
  Returns the host portion of the URI for production.
  """
  def production_host, do: Braintree.get_env(:production_endpoint)

  @doc """
  Returns the host portion of the URI for non-prod environments.
  """
  def sandbox_host, do: Braintree.get_env(:sandbox_endpoint)

  @doc """
  Centralized request handling function. All convenience structs use this
  function to interact with the Braintree servers. This function can be used
  directly to supplement missing functionality.

  ## Example

      defmodule MyApp.Disbursement do
        alias Braintree.HTTP

        def disburse(params \\ %{}) do
          HTTP.request(:get, "disbursements", params)
        end
      end
  """
  def request(method, path), do: adapter().request(method, path)

  def request(method, path, body_or_opts) do
    adapter().request(method, path, body_or_opts)
  end

  def request(method, path, body, opts) do
    adapter().request(method, path, body, opts)
  end

  for method <- ~w(get delete post put)a do
    def unquote(method)(path) do
      request(unquote(method), path, %{}, [])
    end

    def unquote(method)(path, payload) when is_map(payload) do
      request(unquote(method), path, payload, [])
    end

    def unquote(method)(path, opts) when is_list(opts) do
      request(unquote(method), path, %{}, opts)
    end

    def unquote(method)(path, payload, opts) do
      request(unquote(method), path, payload, opts)
    end
  end
end
