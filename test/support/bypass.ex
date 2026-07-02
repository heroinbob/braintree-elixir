defmodule Braintree.Test.Bypass do
  @moduledoc """
  Logic for working with Bypass in a test.
  """

  def expect(bypass, method, path, expectation) when is_function(expectation, 1) do
    Bypass.expect(bypass, method, path, expectation)
  end

  @doc """
  Set an expectation for a delete request. Returns the bypass instance.
  """
  def expect_delete_request(path, expectation, bypass \\ nil) when is_function(expectation, 1) do
    bypass = bypass || Bypass.open()

    expect(bypass, "DELETE", path, expectation)

    bypass
  end

  @doc """
  Set an expectation for a get request. Returns the bypass instance.
  """
  def expect_get_request(path, expectation, bypass \\ nil) when is_function(expectation, 1) do
    bypass = bypass || Bypass.open()

    expect(bypass, "GET", path, expectation)

    bypass
  end

  @doc """
  Set an expectation for a post request. Returns the bypass instance.
  """
  def expect_post_request(path, expectation, bypass \\ nil) when is_function(expectation, 1) do
    bypass = bypass || Bypass.open()

    expect(bypass, "POST", path, expectation)

    bypass
  end

  @doc """
  Set an expectation for a put request. Returns the bypass instance.
  """
  def expect_put_request(path, expectation, bypass \\ nil) when is_function(expectation, 1) do
    bypass = bypass || Bypass.open()

    expect(bypass, "PUT", path, expectation)

    bypass
  end
end
