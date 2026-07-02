defmodule Braintree.Test.HTTP do
  @moduledoc """
  Logic for working with HTTP requests in a test.
  """
  alias Braintree.HTTP.MockAdapter
  alias Braintree.Test.Support.ConfigHelper
  alias ExUnit.Assertions

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

  def statuses, do: @statuses

  def assert_headers(%Plug.Conn{req_headers: headers}) do
    username = Application.fetch_env!(:braintree, :public_key)
    password = Application.fetch_env!(:braintree, :private_key)

    for value <- [
          {"accept", "application/xml"},
          {"accept-encoding", "gzip"},
          {"authorization", "Basic #{:base64.encode("#{username}:#{password}")}"},
          {"content-type", "application/xml"},
          {"user-agent", "Braintree Elixir/0.1"},
          {"x-apiversion", "4"}
        ] do
      Assertions.assert(
        Enum.any?(headers, &(&1 == value)),
        "expected #{inspect(value)} to be present in #{inspect(headers)}"
      )
    end
  end

  def compress(string), do: :zlib.gzip(string)

  def expect(call, expectation), do: Hammox.expect(MockAdapter, call, expectation)

  def expect_request(expectation)
      when is_function(expectation, 2) or
             is_function(expectation, 3) or
             is_function(expectation, 4) do
    expect(:request, expectation)
  end

  @doc """
  Send a typical Braintree response. This includes the content type, content encoding
  headers and the body is gzip compressed. Optionally pass an HTTP status if you
  want something other than `200`.
  """
  def send_response(%Plug.Conn{} = conn, body, http_status \\ 200) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/xml")
    |> Plug.Conn.put_resp_header("content-encoding", "gzip")
    |> Plug.Conn.resp(http_status, compress(body))
  end

  @doc """
  Execute the given function using the mock adapter.
  """
  def with_mock_adapter(test_fn) when is_function(test_fn, 0) do
    ConfigHelper.with_application_config(
      [http_adapter: MockAdapter],
      test_fn
    )
  end

  @doc """
  Execute the given function using the mock adapter. It will intercept HTTP requests
  made to the given bypass instance.
  """
  def with_mock_adapter(bypass, test_fn, other_opts \\ []) when is_function(test_fn, 0) do
    ConfigHelper.with_application_config(
      Keyword.merge(
        [
          http_adapter: MockAdapter,
          sandbox_endpoint: "http://localhost:#{bypass.port}/"
        ],
        other_opts
      ),
      test_fn
    )
  end
end
