defmodule Braintree.HTTP.AdapterBehaviour do
  @moduledoc """
  Behavior for an HTTP adapter. This describes what an adapter
  must implement.
  """

  @type response :: {:ok, map()} | {:error, term()}

  @callback request(method :: atom(), path :: String.t()) :: response()

  @callback request(
              method :: atom(),
              path :: String.t(),
              body_or_opts :: String.t() | map() | Keyword.t()
            ) :: response()

  @callback request(
              method :: atom(),
              path :: String.t(),
              body :: String.t() | map(),
              opts :: Keyword.t()
            ) :: response()

  for method <- ~w(get delete post put)a do
    @callback unquote(method)(String.t()) :: response()
    @callback unquote(method)(String.t(), map() | list()) :: response()
    @callback unquote(method)(String.t(), map(), list()) :: response()
  end
end
