defmodule Braintree.HTTPTest do
  # Do not use async when usig configuration changes
  use ExUnit.Case, async: false

  alias Braintree.HTTP
  alias Braintree.Test

  for test_method <- [:delete, :get, :post, :put] do
    describe "#{test_method}/1" do
      test "delegates to the configured adapter" do
        request_path = "/customers"
        response = {:ok, %{"foo" => "bar"}}

        Test.HTTP.expect_request(fn method, path, body, opts ->
          assert method == unquote(test_method)
          assert path == request_path
          assert body == %{}
          assert opts == []

          response
        end)

        Test.HTTP.with_mock_adapter(fn ->
          assert apply(HTTP, unquote(test_method), [request_path]) == response
        end)
      end
    end

    describe "#{test_method}/2" do
      test "passes the body and delegates to the configured adapter" do
        payload = %{ima: "lil-teapot"}
        request_path = "/customers"
        response = {:ok, %{"foo" => "bar"}}

        Test.HTTP.expect_request(fn method, path, body, opts ->
          assert method == unquote(test_method)
          assert path == request_path
          assert body == payload
          assert opts == []

          response
        end)

        Test.HTTP.with_mock_adapter(fn ->
          assert apply(HTTP, unquote(test_method), [request_path, payload]) == response
        end)
      end
    end

    describe "#{test_method}/3" do
      test "passes the options and delegates to the configured adapter" do
        payload = %{ima: "lil-teapot"}
        request_path = "/customers"
        response = {:ok, %{"foo" => "bar"}}
        opts = [timeout: 500]

        Test.HTTP.expect_request(fn method, path, body, opts ->
          assert method == unquote(test_method)
          assert path == request_path
          assert body == payload
          assert opts == opts

          response
        end)

        Test.HTTP.with_mock_adapter(fn ->
          assert apply(
                   HTTP,
                   unquote(test_method),
                   [request_path, payload, opts]
                 ) == response
        end)
      end
    end
  end

  describe "request/2" do
    test "delegates to the configured adapter" do
      response = {:ok, %{}}

      Test.HTTP.expect_request(fn method, path ->
        assert method == :get
        assert path == "customers"

        response
      end)

      Test.HTTP.with_mock_adapter(fn ->
        assert HTTP.request(:get, "customers") == response
      end)
    end
  end

  describe "request/3" do
    test "delegates to the configured adapter" do
      response = {:ok, %{}}

      Test.HTTP.expect_request(fn method, path, opts ->
        assert method == :get
        assert path == "customers"
        assert opts == [foo: "yes"]

        response
      end)

      Test.HTTP.with_mock_adapter(fn ->
        assert HTTP.request(:get, "customers", foo: "yes") == response
      end)
    end
  end

  describe "request/4" do
    test "delegates to the configured adapter" do
      response = {:ok, %{}}

      Test.HTTP.expect_request(fn method, path, body, opts ->
        assert method == :get
        assert path == "customers"
        assert body == "ima-body"
        assert opts == [foo: "yes"]

        response
      end)

      Test.HTTP.with_mock_adapter(fn ->
        assert HTTP.request(:get, "customers", "ima-body", foo: "yes") == response
      end)
    end
  end
end
