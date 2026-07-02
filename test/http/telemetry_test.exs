defmodule Braintree.HTTP.TelemetryTest do
  use ExUnit.Case, async: true

  alias Braintree.HTTP.Telemetry
  alias Braintree.Test

  describe "emit_error/4" do
    test "sends the expected event with scope and payload" do
      ref = Test.Telemetry.listen_for_error()
      scope = Test.Telemetry.error_scope()
      reason = RuntimeError.exception("test")

      assert Telemetry.emit_error(
               42,
               :get,
               "path",
               reason
             ) == :ok

      assert_receive {
        ^scope,
        ^ref,
        %{duration: 42},
        %{method: :get, path: "path", error: ^reason}
      }
    end
  end

  describe "emit_exception/4" do
    test "sends the expected event with scope and payload" do
      ref = Test.Telemetry.listen_for_exception()
      scope = Test.Telemetry.exception_scope()
      error_data = RuntimeError.exception("test")

      assert Telemetry.emit_exception(
               42,
               :get,
               "path",
               error_data
             ) == :ok

      assert_receive {
        ^scope,
        ^ref,
        %{duration: 42},
        %{method: :get, path: "path", error: ^error_data}
      }
    end
  end

  describe "emit_start/2" do
    test "emits an event with the correct scope and data" do
      ref = Test.Telemetry.listen_for_start_request()
      scope = Test.Telemetry.start_scope()

      assert Telemetry.emit_start(:get, "path") == :ok

      assert_receive {
        ^scope,
        ^ref,
        %{system_time: time},
        %{method: :get, path: "path"}
      }

      diff =
        System.system_time(:millisecond) - System.convert_time_unit(time, :native, :millisecond)

      assert diff >= 0 and diff <= 100
    end
  end

  describe "emit_stop/4" do
    test "emits an event with the correct scope and data" do
      ref = Test.Telemetry.listen_for_stop_request()
      scope = Test.Telemetry.stop_scope()

      assert Telemetry.emit_stop(42, :get, "path", 200) == :ok

      assert_receive {
        ^scope,
        ^ref,
        %{duration: 42},
        %{method: :get, path: "path", http_status: 200}
      }
    end
  end
end
