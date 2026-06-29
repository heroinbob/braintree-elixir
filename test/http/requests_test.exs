defmodule Braintree.HTTP.RequestsTest do
  # Do not use async while working with tests that do config changes!
  use ExUnit.Case

  import Braintree.Test.Support.ConfigHelper

  alias Braintree.ConfigError
  alias Braintree.HTTP.Requests

  # describe "build_headers/1" do
  #   test "building an auth header from application config" do
  #     with_application_config(:private_key, "the_private_key", fn ->
  #       with_application_config(:public_key, "the_public_key", fn ->
  #         {_, auth_header} = List.keyfind(Requests.build_headers([]), "Authorization", 0)
  #
  #         assert auth_header == "Basic dGhlX3B1YmxpY19rZXk6dGhlX3ByaXZhdGVfa2V5"
  #       end)
  #     end)
  #   end
  #
  #   test "building an auth header from only an access token" do
  #     with_application_config(:access_token, "special_access_token", fn ->
  #       {_, auth_header} = List.keyfind(Requests.build_headers([]), "Authorization", 0)
  #
  #       assert auth_header == "Bearer special_access_token"
  #     end)
  #   end
  #
  #   test "building an auth header from provided options" do
  #     headers =
  #       Requests.build_headers(
  #         access_token: nil,
  #         private_key: "dynamic_key",
  #         public_key: "dyn_pub_key"
  #       )
  #
  #     {_, auth_header} = List.keyfind(headers, "Authorization", 0)
  #
  #     assert auth_header == "Basic ZHluX3B1Yl9rZXk6ZHluYW1pY19rZXk="
  #   end
  #
  #   test "build_headers/1 raises a helpful error message without config" do
  #     assert_config_error(:public_key, fn ->
  #       Requests.build_headers([])
  #     end)
  #   end
  # end

  # describe "build_options/1" do
  #   test "adds the cacertfile for production" do
  #     options = Requests.build_options(url: "https://api.braintreegateway.com/merchants/123foo/")
  #
  #     assert {:ssl_options, ssl_options} = :lists.keyfind(:ssl_options, 1, options)
  #     ssl_options = Map.new(ssl_options)
  #     assert %{cacertfile: _} = ssl_options
  #     assert %{server_name_indication: ~c"api.braintreegateway.com"} = ssl_options
  #     assert %{verify: :verify_peer} = ssl_options
  #   end
  #
  #   test "adds the cacertfile for sandbox" do
  #     options =
  #       Requests.build_options(url: "https://api.sandbox.braintreegateway.com/merchants/123foo/")
  #
  #     assert {:ssl_options, ssl_options} = :lists.keyfind(:ssl_options, 1, options)
  #     ssl_options = Map.new(ssl_options)
  #     assert %{cacertfile: _} = ssl_options
  #     assert %{server_name_indication: ~c"api.sandbox.braintreegateway.com"} = ssl_options
  #     assert %{verify: :verify_peer} = ssl_options
  #   end
  #
  #   test "does not add the cacertfile for other endpoints" do
  #     options = Requests.build_options(url: "http://localhost:5000/merchants/123foo/")
  #
  #     refute :lists.keyfind(:ssl_options, 1, options)
  #   end
  #
  #   test "sets default timeouts" do
  #     options = Requests.build_options([])
  #
  #     assert :with_body in options
  #     assert {:recv_timeout, 30_000} in options
  #     assert {:connect_timeout, 10_000} in options
  #   end
  #
  #   test "allows overriding timeout defaults via config" do
  #     with_application_config(:http_options, [recv_timeout: 15_000, connect_timeout: 5_000], fn ->
  #       options = Requests.build_options([])
  #
  #       assert :with_body in options
  #       assert {:recv_timeout, 15_000} in options
  #       assert {:connect_timeout, 5_000} in options
  #     end)
  #   end
  #
  #   test "merges custom options with defaults" do
  #     with_application_config(:http_options, [recv_timeout: 20_000, custom_option: :value], fn ->
  #       options = Requests.build_options([])
  #
  #       assert :with_body in options
  #       assert {:recv_timeout, 20_000} in options
  #       assert {:connect_timeout, 10_000} in options
  #       assert {:custom_option, :value} in options
  #     end)
  #   end
  # end

  describe "build_url/2" do
    test "builds a url from application config without options" do
      with_application_config(:merchant_id, "qwertyid", fn ->
        assert Requests.build_url("customer", []) =~
                 "sandbox.braintreegateway.com/merchants/qwertyid/customer"
      end)
    end

    test "builds a url from provided options" do
      assert Requests.build_url("customer", environment: "production", merchant_id: "opts_merchant_id") =~
               "api.braintreegateway.com/merchants/opts_merchant_id/customer"
    end

    test "raises a helpful error message without config" do
      assert_config_error(:merchant_id, fn ->
        Requests.build_url("customer", [])
      end)
    end
  end

  describe "code_to_reason/1" do
    test "supports common HTTP statuses" do
      for {status, reason} <- [
            {400, :bad_request},
            {401, :unauthorized},
            {403, :forbidden},
            {404, :not_found},
            {406, :not_acceptable},
            {422, :unprocessable_entity},
            {426, :upgrade_required},
            {429, :too_many_requests},
            {500, :server_error},
            {501, :not_implemented},
            {502, :bad_gateway},
            {503, :service_unavailable},
            {504, :connect_timeout}
          ] do
        assert Requests.code_to_reason(status) == reason
      end
    end
  end

  # describe "decode_body/1" do
  #   test "converts the request back from xml" do
  #     xml =
  #       Test.HTTP.compress(~s|<?xml version="1.0" encoding="UTF-8" ?>\n<company><name>Soren</name></company>|)
  #
  #     assert Requests.decode_body(xml) == %{"company" => %{"name" => "Soren"}}
  #   end
  #
  #   test "safely handles empty responses" do
  #     assert "" |> Test.HTTP.compress() |> Requests.decode_body() == %{}
  #     assert " " |> Test.HTTP.compress() |> Requests.decode_body() == %{}
  #   end
  #
  #   test "logs unhandled errors" do
  #     assert ExUnit.CaptureLog.capture_log(fn ->
  #              Requests.decode_body("asdf")
  #            end) =~ "unprocessable response"
  #   end
  # end

  describe "endecode_body/1" do
    test "converts the request body to xml" do
      params = %{company: "Soren", first_name: "Parker"}

      assert [xml_tag | nodes] = params |> Requests.encode_body() |> String.split("\n")

      assert xml_tag == ~s|<?xml version="1.0" encoding="UTF-8" ?>|
      assert ~s|<company>Soren</company>| in nodes
      assert ~s|<first-name>Parker</first-name>| in nodes
    end

    test "ignores empty bodies" do
      assert Requests.encode_body("") == ""
      assert Requests.encode_body(%{}) == ""
    end
  end

  describe "production_endpoint/0" do
    test "returns a pre-defined value" do
      assert Requests.production_endpoint() == "https://api.braintreegateway.com/merchants/"
    end

    test "returns the configured value when present" do
      with_application_config(:production_endpoint, "https://test.com/", fn ->
        assert Requests.production_endpoint() == "https://test.com/"
      end)
    end
  end

  describe "sandbox_endpoint/0" do
    test "returns a pre-defined value" do
      assert Requests.sandbox_endpoint() == "https://api.sandbox.braintreegateway.com/merchants/"
    end

    test "returns the configured value when present" do
      with_application_config(:sandbox_endpoint, "https://test.com/", fn ->
        assert Requests.sandbox_endpoint() == "https://test.com/"
      end)
    end
  end

  defp assert_config_error(key, fun) do
    value = Braintree.get_env(key)

    try do
      Application.delete_env(:braintree, key)
      assert_raise ConfigError, "missing config for :#{key}", fun
    after
      Braintree.put_env(key, value)
    end
  end
end
