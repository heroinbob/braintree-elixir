defmodule Braintree.HTTP.Telemetry do
  @moduledoc"""
  Context for working with HTTP telemetry.
  """

  @type method :: :get | :delete | :put | :post

  @spec emit_start(method :: method(), path :: String.t()) :: :ok
  def emit_start(method, path) do
    :telemetry.execute(
      [:braintree, :request, :start],
      %{system_time: System.system_time()},
      %{method: method, path: path}
    )
  end

  @spec emit_exception(
    duration :: non_neg_integer(),
    method :: method(),
    path :: String.t(),
    error_data :: term()
  ) :: :ok
  def emit_exception(duration, method, path, error_data) do
    :telemetry.execute(
      [:braintree, :request, :exception],
      %{duration: duration},
      %{method: method, path: path, error: error_data}
    )
  end

  @spec emit_error(
    duration :: non_neg_integer(),
    method :: method(),
    path :: String.t(),
    error_reason :: term()
  ) :: :ok
  def emit_error(duration, method, path, error_reason) do
    :telemetry.execute(
      [:braintree, :request, :error],
      %{duration: duration},
      %{method: method, path: path, error: error_reason}
    )
  end

  @spec emit_stop(
    duration :: non_neg_integer,
    method :: method(),
    path :: String.t(),
    http_status :: non_neg_integer()
  ) :: :ok
  def emit_stop(duration, method, path, http_status) do
    :telemetry.execute(
      [:braintree, :request, :stop],
      %{duration: duration},
      %{method: method, path: path, http_status: http_status}
    )
  end
end
