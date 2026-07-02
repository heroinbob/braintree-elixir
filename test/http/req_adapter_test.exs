defmodule Braintree.HTTP.ReqAdapterTest do
  # Do not use async while working with tests that do config changes!
  use ExUnit.Case, async: false

  alias Braintree.ErrorResponse
  alias Braintree.HTTP.Error
  alias Braintree.HTTP.ReqAdapter
  alias Braintree.Test
  alias ExUnit.CaptureLog

  @merchant_id Braintree.get_env(:merchant_id)
  @customer_path "/#{@merchant_id}/customers"
  @customer_xml ~s|<?xml version="1.0" encoding="UTF-8" ?>\n<company><name>Soren</name></company>|
  @statuses Test.HTTP.statuses()

  for test_method <- [:delete, :get, :post, :put] do
    describe "#{test_method}/1" do
      test "responds with request/2 result" do
        Test.Bypass
        |> apply(
          :"expect_#{unquote(test_method)}_request",
          [
            @customer_path,
            fn %Plug.Conn{} = conn ->
              assert conn.method == unquote(test_method) |> Atom.to_string() |> String.upcase()

              Test.HTTP.send_response(conn, @customer_xml)
            end
          ]
        )
        |> Test.HTTP.with_mock_adapter(fn ->
          assert apply(
                   ReqAdapter,
                   unquote(test_method),
                   ["customers"]
                 ) == {:ok, %{"company" => %{"name" => "Soren"}}}
        end)
      end
    end

    describe "#{test_method}/2" do
      test "responds with request/3 result" do
        Test.Bypass
        |> apply(
          :"expect_#{unquote(test_method)}_request",
          [
            @customer_path,
            fn %Plug.Conn{} = conn ->
              assert {:ok, xml, conn} = Plug.Conn.read_body(conn)

              assert String.split(xml, "\n") == [
                       ~s(<?xml version="1.0" encoding="UTF-8" ?>),
                       "<customer>",
                       "<is>always wrong</is>",
                       "</customer>"
                     ]

              Test.HTTP.send_response(conn, @customer_xml)
            end
          ]
        )
        |> Test.HTTP.with_mock_adapter(fn ->
          assert apply(
                   ReqAdapter,
                   unquote(test_method),
                   ["customers", %{customer: %{is: "always wrong"}}]
                 ) == {:ok, %{"company" => %{"name" => "Soren"}}}
        end)
      end
    end

    describe "#{test_method}/3" do
      test "responds with request/4 result" do
        Test.Bypass
        |> apply(
          :"expect_#{unquote(test_method)}_request",
          [
            "/abc/customers",
            fn %Plug.Conn{} = conn ->
              Test.HTTP.send_response(conn, @customer_xml)
            end
          ]
        )
        |> Test.HTTP.with_mock_adapter(fn ->
          assert apply(
                   ReqAdapter,
                   unquote(test_method),
                   [
                     "customers",
                     %{the_price: %{is: "wrong, Bob!"}},
                     [merchant_id: "abc"]
                   ]
                 ) == {:ok, %{"company" => %{"name" => "Soren"}}}
        end)
      end
    end
  end

  describe "request/2" do
    test "makes an HTTP request to the correct URL with the given body and returns the result" do
      @customer_path
      |> Test.Bypass.expect_get_request(fn %Plug.Conn{} = conn ->
        assert conn.method == "GET"
        assert conn.params == %{}
        assert conn.query_string == ""
        assert conn.request_path == @customer_path
        assert {:ok, "", conn} = Plug.Conn.read_body(conn)
        Test.HTTP.assert_headers(conn)

        Test.HTTP.send_response(conn, @customer_xml)
      end)
      |> Test.HTTP.with_mock_adapter(fn ->
        start_ref = Test.Telemetry.listen_for_start_request()
        stop_ref = Test.Telemetry.listen_for_stop_request()
        start_scope = Test.Telemetry.start_scope()
        stop_scope = Test.Telemetry.stop_scope()

        assert ReqAdapter.request(:get, "customers") ==
                 {:ok, %{"company" => %{"name" => "Soren"}}}

        assert_receive {
          ^start_scope,
          ^start_ref,
          %{system_time: _time},
          %{method: :get, path: "customers"}
        }

        assert_receive {
          ^stop_scope,
          ^stop_ref,
          %{duration: _duration},
          %{method: :get, path: "customers", http_status: 200}
        }
      end)
    end

    test "ignores the body and returns an empty string when the result is 3XX" do
      bypass =
        Test.Bypass.expect_get_request(
          "/#{@merchant_id}/three-hundred",
          fn %Plug.Conn{} = conn ->
            Test.HTTP.send_response(conn, "<error/>", 300)
          end
        )

      # 308 is the highest documented 3xx code for http
      Test.Bypass.expect_get_request(
        "/#{@merchant_id}/three-oh-eight",
        fn %Plug.Conn{} = conn ->
          Test.HTTP.send_response(conn, "<error/>", 308)
        end,
        bypass
      )

      Test.HTTP.with_mock_adapter(
        bypass,
        fn ->
          stop_ref = Test.Telemetry.listen_for_stop_request()
          stop_scope = Test.Telemetry.stop_scope()

          assert ReqAdapter.request(:get, "three-hundred") == {:ok, ""}
          assert ReqAdapter.request(:get, "three-oh-eight") == {:ok, ""}

          assert_receive {
            ^stop_scope,
            ^stop_ref,
            %{duration: _duration},
            %{method: :get, path: "three-hundred", http_status: 300}
          }

          assert_receive {
            ^stop_scope,
            ^stop_ref,
            %{duration: _duration},
            %{method: :get, path: "three-oh-eight", http_status: 308}
          }
        end
      )
    end

    test "returns an ErrorResponse when the response is 422" do
      bypass =
        Test.Bypass.expect_get_request(
          "/#{@merchant_id}/api-error-response",
          fn %Plug.Conn{} = conn ->
            Test.HTTP.send_response(
              conn,
              "<api-error-response><message>test!</message></api-error-response>",
              422
            )
          end
        )

      Test.Bypass.expect_get_request(
        "/#{@merchant_id}/unprocessable-entity",
        fn %Plug.Conn{} = conn ->
          Test.HTTP.send_response(
            conn,
            "<unprocessable-entity><message>fail!</message></unprocessable-entity>",
            422
          )
        end,
        bypass
      )

      Test.HTTP.with_mock_adapter(
        bypass,
        fn ->
          stop_ref = Test.Telemetry.listen_for_stop_request()
          stop_scope = Test.Telemetry.stop_scope()

          assert {:error, %ErrorResponse{message: "test!"}} =
                   ReqAdapter.request(:get, "api-error-response")

          assert {:error, %ErrorResponse{message: "Unprocessable Entity"}} =
                   ReqAdapter.request(:get, "unprocessable-entity")

          assert_receive {
            ^stop_scope,
            ^stop_ref,
            %{duration: _duration},
            %{method: :get, path: "api-error-response", http_status: 422}
          }

          assert_receive {
            ^stop_scope,
            ^stop_ref,
            %{duration: _duration},
            %{method: :get, path: "unprocessable-entity", http_status: 422}
          }
        end
      )
    end

    test "returns an error with an atom representing the code for status 400 to 504" do
      statuses = Enum.filter(@statuses, fn {code, _} -> code > 399 and code != 422 end)

      for {code, atom} <- statuses do
        path = Atom.to_string(atom)

        "/#{@merchant_id}/#{path}"
        |> Test.Bypass.expect_get_request(fn %Plug.Conn{} = conn ->
          Test.HTTP.send_response(
            conn,
            "<api-error-response><message>test!</message></api-error-response>",
            code
          )
        end)
        |> Test.HTTP.with_mock_adapter(fn ->
          stop_ref = Test.Telemetry.listen_for_stop_request()
          stop_scope = Test.Telemetry.stop_scope()

          assert ReqAdapter.request(:get, path) == {:error, atom}

          assert_receive {
            ^stop_scope,
            ^stop_ref,
            %{duration: _duration},
            %{method: :get, path: ^path, http_status: ^code}
          }
        end)
      end
    end

    test "returns an atom when the connection fails" do
      bypass = Bypass.open()

      Test.HTTP.with_mock_adapter(
        bypass,
        fn ->
          Bypass.down(bypass)
          telemetry_ref = Test.Telemetry.listen_for_error()
          telemetry_scope = Test.Telemetry.error_scope()

          assert ReqAdapter.request(:get, "path") == {:error, :econnrefused}

          assert_receive {
            ^telemetry_scope,
            ^telemetry_ref,
            %{duration: _duration},
            %{method: :get, path: "path", error: :econnrefused}
          }
        end
      )
    end

    test "processes the XML and returns the data when the response is not compressed" do
      @customer_path
      |> Test.Bypass.expect_get_request(fn %Plug.Conn{} = conn ->
        # Don't compress the response. Send it!
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/xml")
        |> Plug.Conn.resp(200, @customer_xml)
      end)
      |> Test.HTTP.with_mock_adapter(fn ->
        assert ReqAdapter.request(:get, "customers") ==
                 {:ok, %{"company" => %{"name" => "Soren"}}}
      end)
    end

    @tag capture_log: true
    test "emits telemetry and returns an error when XML is invalid and/or an exit is caught" do
      @customer_path
      |> Test.Bypass.expect_get_request(fn %Plug.Conn{} = conn ->
        Test.HTTP.send_response(conn, "asdf")
      end)
      |> Test.HTTP.with_mock_adapter(fn ->
        telemetry_ref = Test.Telemetry.listen_for_exception()
        telemetry_scope = Test.Telemetry.exception_scope()

        assert {
                 :error,
                 %Error{
                   message: "Unexpected Error",
                   error: %{
                     kind: :exit,
                     reason: {:fatal, {:expected_element_start_tag, _, _, _}}
                   }
                 }
               } = ReqAdapter.request(:get, "customers")

        assert_receive {
          ^telemetry_scope,
          ^telemetry_ref,
          %{duration: _duration},
          %{
            error: %{
              kind: :exit,
              reason: {:fatal, {:expected_element_start_tag, _, _, _}},
              stacktrace: _
            },
            method: :get,
            path: "customers"
          }
        }

        # Set an invalid environment. This will trigger a KeyError.
        assert {:error, %Error{}} =
                 ReqAdapter.request(:get, "die-in-a-fire", %{}, environment: :foo)

        assert_receive {
          ^telemetry_scope,
          ^telemetry_ref,
          %{duration: _duration},
          %{method: :get, path: "die-in-a-fire", error: error}
        }

        assert error.kind == :error
        assert %KeyError{key: :foo} = error.reason
        assert [{Keyword, :fetch!, 2, _} | _] = error.stacktrace
      end)
    end

    test "applies the options provided in the adapter config" do
      @customer_path
      |> Test.Bypass.expect_get_request(fn %Plug.Conn{} = conn ->
        Test.HTTP.send_response(
          conn,
          "<api-error-response><message>try again</message></api-error-response>",
          503
        )
      end)
      |> Test.HTTP.with_mock_adapter(
        fn ->
          log =
            CaptureLog.capture_log(fn ->
              assert ReqAdapter.request(:get, "customers") == {:error, :service_unavailable}
            end)

          assert log =~ "got response with status 503, will retry in 20ms, 3 attempts left"
          assert log =~ "got response with status 503, will retry in 20ms, 2 attempts left"
          assert log =~ "got response with status 503, will retry in 20ms, 1 attempt left"
        end,
        http_options: [retry: :safe_transient, retry_delay: 20]
      )
    end
  end

  describe "request/3" do
    test "encodes the given payload" do
      @customer_path
      |> Test.Bypass.expect_get_request(fn %Plug.Conn{} = conn ->
        assert {:ok, xml, conn} = Plug.Conn.read_body(conn)

        assert String.split(xml, "\n") == [
                 ~s(<?xml version="1.0" encoding="UTF-8" ?>),
                 "<customer>",
                 "<is>always wrong</is>",
                 "</customer>"
               ]

        Test.HTTP.send_response(conn, @customer_xml)
      end)
      |> Test.HTTP.with_mock_adapter(fn ->
        assert ReqAdapter.request(
                 :get,
                 "customers",
                 %{customer: %{is: "always wrong"}}
               ) == {:ok, %{"company" => %{"name" => "Soren"}}}
      end)
    end
  end

  describe "request/4" do
    test "utilizes the given opts when provided" do
      "/abc/customers"
      |> Test.Bypass.expect_get_request(fn %Plug.Conn{} = conn ->
        Test.HTTP.send_response(conn, @customer_xml)
      end)
      |> Test.HTTP.with_mock_adapter(fn ->
        assert ReqAdapter.request(
                 :get,
                 "customers",
                 %{the_price: %{is: "wrong, Bob!"}},
                 merchant_id: "abc"
               )
      end)
    end
  end
end
