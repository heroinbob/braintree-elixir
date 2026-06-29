defmodule Braintree.Test.Telemetry do
  @error_scope [:braintree, :request, :error]
  @exception_scope [:braintree, :request, :exception]
  @start_scope [:braintree, :request, :start]
  @stop_scope [:braintree, :request, :stop]

  def error_scope, do: @error_scope
  def exception_scope, do: @exception_scope
  def start_scope, do: @start_scope
  def stop_scope, do: @stop_scope

  def listen_for_error(pid \\ self()) do
    :telemetry_test.attach_event_handlers(pid, [@error_scope])
  end

  def listen_for_exception(pid \\ self()) do
    :telemetry_test.attach_event_handlers(pid, [@exception_scope])
  end

  def listen_for_start_request(pid \\ self()) do
    :telemetry_test.attach_event_handlers(pid, [@start_scope])
  end

  def listen_for_stop_request(pid \\ self()) do
    :telemetry_test.attach_event_handlers(pid, [@stop_scope])
  end
end
