defmodule Braintree.HTTP.RequestsTest do
  # Do not use async while working with tests that do config changes!
  use ExUnit.Case

  import Braintree.Test.Support.ConfigHelper

  alias Braintree.ConfigError
  alias Braintree.HTTP.Requests

  @cacertfile_path :braintree
                   |> :code.priv_dir()
                   |> Path.join("/certs/api_braintreegateway_com.ca.crt")

  describe "build_url/2" do
    test "builds a url from application config without options" do
      with_application_config(:merchant_id, "qwertyid", fn ->
        assert Requests.build_url("customer", []) =~
                 "sandbox.braintreegateway.com/merchants/qwertyid/customer"
      end)
    end

    test "builds a url from provided options" do
      assert Requests.build_url("customer",
               environment: "production",
               merchant_id: "opts_merchant_id"
             ) =~
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

  describe "get_auth_header/0" do
    test "returns the auth header as a tuple" do
      pub = Braintree.get_env(:public_key)
      priv = Braintree.get_env(:private_key)
      token = Base.encode64(pub <> ":" <> priv)

      assert Requests.get_auth_header() == {"Authorization", "Basic #{token}"}
    end
  end

  describe "get_auth_header/1" do
    test "returns a token based on the given options" do
      pub = "apple"
      priv = "orange"

      assert Requests.get_auth_header(
               public_key: pub,
               private_key: priv
             ) == {"Authorization", "Basic #{Base.encode64(pub <> ":" <> priv)}"}

      assert Requests.get_auth_header(access_token: "token") ==
               {"Authorization", "Basic #{Base.encode64("token")}"}
    end

    test "returns the configured auth header when opts doesn't have anything" do
      pub = Braintree.get_env(:public_key)
      priv = Braintree.get_env(:private_key)

      assert Requests.get_auth_header(foo: "bar") == {
               "Authorization",
               "Basic #{Base.encode64(pub <> ":" <> priv)}"
             }
    end
  end

  describe "get_auth_token/0" do
    test "returns the raw auth token" do
      pub = Braintree.get_env(:public_key)
      priv = Braintree.get_env(:private_key)

      assert Requests.get_auth_token() == pub <> ":" <> priv
    end
  end

  describe "get_auth_token/1" do
    test "returns the auth token based on the given options" do
      assert Requests.get_auth_token(public_key: "a", private_key: "b") == "a:b"
      assert Requests.get_auth_token(access_token: "a") == "a"
    end

    test "returns the configured auth token when the options don't specify it" do
      pub = Braintree.get_env(:public_key)
      priv = Braintree.get_env(:private_key)

      assert Requests.get_auth_token(foo: "a", a_key: "b") == pub <> ":" <> priv
    end
  end

  describe "get_cacertfile_path/0" do
    test "returns the path for the current env" do
      # Default is to return the expected one
      assert Requests.get_cacertfile_path() == @cacertfile_path

      with_application_config(
        [
          sandbox_cacertfile: "/sandbox/cacertfile",
          environment: :sandbox
        ],
        fn ->
          assert Requests.get_cacertfile_path() == "/sandbox/cacertfile"
        end
      )

      with_application_config(
        [
          cacertfile: "/prod/cacertfile",
          environment: :production
        ],
        fn ->
          assert Requests.get_cacertfile_path() == "/prod/cacertfile"
        end
      )
    end
  end

  describe "get_cacertfile_path/1" do
    test "returns the certfile based on the given env in the options" do
      with_application_config(
        [
          cacertfile: "/prod/cacertfile",
          sandbox_cacertfile: "/sandbox/cacertfile",
          environment: :sandbox
        ],
        fn ->
          assert Requests.get_cacertfile_path(environment: :production) == "/prod/cacertfile"
        end
      )
    end

    test "returns the configured value when options aren't specific" do
      assert Requests.get_cacertfile_path(foo: :test) == @cacertfile_path
    end
  end

  describe "get_environment/0" do
    test "returns the configured environment" do
      :sandbox = Braintree.get_env(:environment)
      assert Requests.get_environment() == :sandbox
    end
  end

  describe "get_environment/1" do
    test "returns the env in the opts" do
      assert Requests.get_environment(environment: :foo) == :foo
    end

    test "returns the configured env when opts doesn't have the value" do
      assert Requests.get_environment(test: :foo) == :sandbox
    end
  end

  describe "get_production_cacertfile_path/0" do
    test "returns the default path when not configured" do
      assert Requests.get_production_cacertfile_path() == @cacertfile_path
    end

    test "returns the configured production value" do
      with_application_config(
        [
          cacertfile: "/prod/cacertfile",
          sandbox_cacertfile: "/sandbox/cacertfile",
          environment: :sandbox
        ],
        fn ->
          assert Requests.get_production_cacertfile_path() == "/prod/cacertfile"
        end
      )
    end
  end

  describe "get_production_cacertfile_path/1" do
    test "returns the value from the opts when present" do
      assert Requests.get_production_cacertfile_path(cacertfile: "yay") == "yay"
    end

    test "returns the configured value when opts doesn't specify it" do
      with_application_config(
        [
          cacertfile: "/prod/cacertfile",
          sandbox_cacertfile: "/sandbox/cacertfile",
          environment: :sandbox
        ],
        fn ->
          assert Requests.get_production_cacertfile_path(test: "file") == "/prod/cacertfile"
        end
      )
    end
  end

  describe "get_sandbox_cacertfile_path/0" do
    test "returns the default path when not configured" do
      assert Requests.get_sandbox_cacertfile_path() == @cacertfile_path
    end

    test "returns the configured sandbox value" do
      with_application_config(
        [
          cacertfile: "/prod/cacertfile",
          sandbox_cacertfile: "/sandbox/cacertfile",
          environment: :production
        ],
        fn ->
          assert Requests.get_sandbox_cacertfile_path() == "/sandbox/cacertfile"
        end
      )
    end
  end

  describe "get_sandbox_cacertfile_path/1" do
    test "returns the value from the opts when present" do
      assert Requests.get_sandbox_cacertfile_path(sandbox_cacertfile: "yay") == "yay"
    end

    test "returns the configured value when opts doesn't specify it" do
      with_application_config(
        [
          cacertfile: "/prod/cacertfile",
          sandbox_cacertfile: "/sandbox/cacertfile",
          environment: :production
        ],
        fn ->
          assert Requests.get_sandbox_cacertfile_path(test: "file") == "/sandbox/cacertfile"
        end
      )
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
