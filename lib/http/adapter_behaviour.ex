defmodule Braintree.HTTP.AdapterBehaviour do
  @moduledoc """
  Behavior for an HTTP adapter. This describes what an adapter
  must implement.
  """
  @type error ::
          {:error, atom}
          | {:error, Error.t()}
          | {:error, binary}

  @type response :: {:ok, map} | error

  @callback request(method :: atom(), path :: binary()) :: response()

  @callback request(
              method :: atom(),
              path :: binary(),
              body_or_opts :: binary() | map() | Keyword.t()
            ) :: response()

  @callback request(
              method :: atom(),
              path :: binary(),
              body :: binary() | map(),
              opts :: Keyword.t()
            ) :: response()

  for method <- ~w(get delete post put)a do
    @callback unquote(method)(binary()) :: response()
    @callback unquote(method)(binary(), map() | list()) :: response()
    @callback unquote(method)(binary(), map(), list()) :: response()
  end
end
