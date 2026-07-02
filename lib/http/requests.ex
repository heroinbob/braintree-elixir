defmodule Braintree.HTTP.Requests do
  @moduledoc """
  Logic necessary for HTTP request needs when communicating with Braintree.
  """

  alias Braintree.ErrorResponse
  alias Braintree.XML.Encoder

  @cacertfile_path "/certs/api_braintreegateway_com.ca.crt"
  @default_cacertfile_path Path.join(:code.priv_dir(:braintree), @cacertfile_path)
  @default_production_host "https://api.braintreegateway.com/"
  @default_sandbox_host "https://api.sandbox.braintreegateway.com/"

  @statuses %{
    400 => :bad_request,
    401 => :unauthorized,
    403 => :forbidden,
    404 => :not_found,
    406 => :not_acceptable,
    422 => :unprocessable_entity,
    426 => :upgrade_required,
    429 => :too_many_requests,
    500 => :server_error,
    501 => :not_implemented,
    502 => :bad_gateway,
    503 => :service_unavailable,
    504 => :connect_timeout
  }

  @accept_encoding_header {"Accept-Encoding", "gzip"}
  @accept_header {"Accept", "application/xml"}
  @api_version_header {"X-ApiVersion", "4"}
  @content_type_header {"Content-Type", "application/xml"}
  @user_agent_header {"User-Agent", "Braintree Elixir/0.1"}

  def accept_encoding_header, do: @accept_encoding_header
  def accept_header, do: @accept_header
  def api_version_header, do: @api_version_header
  def content_type_header, do: @content_type_header
  def user_agent_header, do: @user_agent_header

  defmacro __using__(_opts) do
    method_defs =
      for method <- ~w(get delete post put)a do
        quote do
          # Only import once...
          if unquote(method) == "get", do: import(Braintree.HTTP.Requests)

          @impl Braintree.HTTP.AdapterBehaviour
          def unquote(method)(path) do
            request(unquote(method), path, %{}, [])
          end

          @impl Braintree.HTTP.AdapterBehaviour
          def unquote(method)(path, payload) when is_map(payload) do
            request(unquote(method), path, payload, [])
          end

          @impl Braintree.HTTP.AdapterBehaviour
          def unquote(method)(path, opts) when is_list(opts) do
            request(unquote(method), path, %{}, opts)
          end

          @impl Braintree.HTTP.AdapterBehaviour
          def unquote(method)(path, payload, opts) do
            request(unquote(method), path, payload, opts)
          end
        end
      end

    quote do
      import Braintree.HTTP.Requests

      unquote(method_defs)
    end
  end

  @doc """
  Build a full URL based on the given path and environment configuration.

  ## Options
  * `:environment` - Specify `:production` or `:sandbox`. Defaults to the configured ENV.
  * `:merchant_id` - Specify a custom merchant ID. Defaults to what's configured.
  """
  @spec build_url(binary, Keyword.t()) :: binary
  def build_url(path, opts) do
    environment = get_environment(opts)
    merchant_id = get_lazy_env(opts, :merchant_id)

    Keyword.fetch!(endpoints(), environment) <> merchant_id <> "/" <> path
  end

  @doc """
  Convert an HTTP status code to an atom. Helpful for error handling.
  """
  @spec code_to_reason(integer) :: atom
  def code_to_reason(code) do
    Map.fetch!(@statuses, code)
  end

  @doc """
  XML encode a given body.
  """
  @spec encode_body(String.t() | map()) :: String.t()
  def encode_body(body) when body == "" or body == %{}, do: ""
  def encode_body(body), do: Encoder.dump(body)

  @doc """
  Returns the value to use for the authorization header.
  """
  @spec get_auth_header(opts :: keyword()) :: {String.t(), String.t()}
  def get_auth_header(opts \\ []) do
    token = opts |> get_auth_token() |> :base64.encode()

    {"Authorization", "Basic " <> token}
  end

  @doc """
  Returns the raw auth token. This must be Base64 encoded before
  placing in the header. The value is a basic username and password
  string using the public and private keys - `"public_key:private_key"`.

  ## Options
  * `:access_token` - When defined this value will be returned and supercedes public and private key.
  * `:public_key` - When defined will override the value used in the config.
  * `:private_key` - When defined will override the value used in the config.
  """
  @spec get_auth_token(opts :: keyword()) :: String.t()
  def get_auth_token(opts \\ []) do
    case get_lazy_env(opts, :access_token, :none) do
      token when is_binary(token) ->
        token

      _ ->
        username = get_lazy_env(opts, :public_key)
        password = get_lazy_env(opts, :private_key)

        username <> ":" <> password
    end
  end

  @doc """
  Return the certfile to use for production. You can pass in
  opts to override the configured value.
  """
  @spec get_production_cacertfile_path(opts :: keyword()) :: String.t()
  def get_production_cacertfile_path(opts \\ []) do
    get_lazy_env(
      opts,
      :cacertfile,
      fn -> @default_cacertfile_path end
    )
  end

  @doc """
  Return the certfile to use for the sandox. You can pass in
  opts to override the configured value.
  """
  @spec get_sandbox_cacertfile_path(opts :: keyword()) :: String.t()
  def get_sandbox_cacertfile_path(opts \\ []) do
    get_lazy_env(
      opts,
      :sandbox_cacertfile,
      fn -> @default_cacertfile_path end
    )
  end

  @doc """
  Return the path to the cacertfile. This will return the path
  based on the currently configured environment. You can pass
  in opts to override the ENV and/or the certfile you wish to
  use.
  """
  @spec get_cacertfile_path(opts :: keyword()) :: String.t()
  def get_cacertfile_path(opts \\ []) when is_list(opts) do
    case get_environment(opts) do
      :production -> get_production_cacertfile_path()
      _ -> get_sandbox_cacertfile_path()
    end
  end

  def get_environment(opts \\ []) do
    opts |> get_lazy_env(:environment) |> maybe_to_atom()
  end

  @doc """
  Return the value for the given key from either opts or the configuration.
  """
  @spec get_lazy_env(opts :: keyword(), default :: any()) :: any()
  def get_lazy_env(opts, key, default \\ nil) do
    Keyword.get_lazy(opts, key, fn -> Braintree.get_env(key, default) end)
  end

  @doc """
  Returns the configured production endpoint to use as the base for request urls.
  """
  @spec production_endpoint() :: String.t()
  def production_endpoint do
    Application.get_env(
      :braintree,
      :production_endpoint,
      @default_production_host <> "merchants/"
    )
  end

  @doc """
  Convert a raw error response into an ErrorResponse struct.
  """
  @spec resolve_error_response(map()) :: ErrorResponse.t()
  def resolve_error_response(%{"api_error_response" => api_error_response}) do
    ErrorResponse.new(api_error_response)
  end

  def resolve_error_response(%{"unprocessable_entity" => _}) do
    ErrorResponse.new(%{message: "Unprocessable Entity"})
  end

  @doc """
  Returns the configured sandbox endpoint to use as the base for request urls.
  """
  @spec sandbox_endpoint() :: String.t()
  def sandbox_endpoint do
    Application.get_env(
      :braintree,
      :sandbox_endpoint,
      @default_sandbox_host <> "merchants/"
    )
  end

  defp endpoints do
    [
      production: production_endpoint(),
      sandbox: sandbox_endpoint()
    ]
  end

  defp maybe_to_atom(value) when is_binary(value), do: String.to_existing_atom(value)
  defp maybe_to_atom(value) when is_atom(value), do: value
end
