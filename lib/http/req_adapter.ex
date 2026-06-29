defmodule Braintree.HTTP.ReqAdapter do
  @moduledoc """
  HTTP adapter that relies on Req for transport.

  ## Options

  * `:access_token` - Override the token used for authentication. Supercedes private and public token.
  * `:environment` - determines the url used (prod/sandbox)
  * `:merchart_id` - The Braintree account merchant ID.
  * `:private_key` - Override the private key used for authentication.
  * `:public_key` - Override the public used for authentication.

  The configuration also will supercede anything passed in. Anything Req supports can be configured.

  ## Response Handling

  Responses are handled in the same way that the HackneyAdapter does in order
  to provide the ability to swap between them with zero overhead.
  """
  @behaviour Braintree.HTTP.AdapterBehaviour

  use Braintree.HTTP.Requests

  import Braintree.HTTP.Telemetry

  alias Braintree.HTTP
  alias Braintree.HTTP.Error
  alias Braintree.XML.Decoder

  require Logger

  @standard_headers [
    accept_header(),
    api_version_header(),
    content_type_header(),
    user_agent_header()
  ]

  @impl Braintree.HTTP.AdapterBehaviour
  def request(method, path, body \\ %{}, opts \\ []) do
    start_time = System.monotonic_time()

    try do
      emit_start(method, path)

      %{
        body: body,
        method: method,
        opts: opts,
        path: path
      }
      |> build_options()
      |> build_client()
      |> Req.request(telemetry: %{path: path, start_time: start_time})
      |> parse_response()
    catch
      kind, reason ->
        # Catch any unexpected exception, including exits.
        # This is important because :xmerl_scan emits fatal errors
        # when the given string is invalid XML. Let the caller
        # determine what to do with the issue.
        duration = System.monotonic_time() - start_time

        emit_exception(
          duration,
          method,
          path,
          %{
            kind: kind,
            reason: reason,
            stacktrace: __STACKTRACE__
          }
        )

        {
          :error,
          Error.exception(
            message: "Unexpected Error",
            error: %{kind: kind, reason: reason}
          )
        }
    end
  end

  defp build_client(opts) do
    opts
    |> Req.new()
    |> Req.Request.register_options([:telemetry])
    |> Req.Request.append_response_steps(send_telemetry: &stop_telemetry_step/1)
    |> Req.Request.append_error_steps(send_telemetry: &error_telemetry_step/1)
  end

  defp build_options(%{
         body: body,
         method: method,
         opts: runtime_opts,
         path: path
       }) do
    [
      auth: {:basic, get_auth_token(runtime_opts)},
      # The encode_body step doesn't support setting a custom encoder. So we have
      # to do this manually.
      body: encode_body(body),
      # Set the accepts gzip header on request and trigger decommression for responses
      compressed: true,
      # Content decoding is performed based on the application content. XML is not supported
      # so we must provide our own decoder.
      decoders: [{:xml, &{:ok, decode_xml(&1)}}],
      headers: @standard_headers,
      method: method,
      url: build_url(path, runtime_opts),
      retry: false
    ]
    |> add_ssl_options(runtime_opts)
    |> add_configuration_options()
  end

  defp add_configuration_options(opts) do
    Keyword.merge(opts, HTTP.adapter_options())
  end

  # Finch options that allow us some control over SSL.
  # https://req.hexdocs.pm/Req.html#new/1-options
  # https://mint.hexdocs.pm/1.8.0/Mint.HTTP.html#connect/4-transport-options
  #
  # These are only used by HTTPS connections
  defp add_ssl_options(opts, override_opts) do
    Keyword.merge(
      opts,
      connect_options: [
        transport_opts: [
          cacertfile: get_cacertfile_path(override_opts),
          verify: :verify_peer
        ]
      ]
    )
  end

  defp decode_xml(body) do
    body
    |> String.trim()
    |> Decoder.load()
  end

  defp parse_response(req_response) do
    case req_response do
      {:ok, %Req.Response{body: body, status: status}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} when status in 300..399 ->
        {:ok, ""}

      {:ok, %Req.Response{body: body, status: 422}} ->
        {:error, resolve_error_response(body)}

      {:ok, %Req.Response{status: status}} when status in 400..504 ->
        {:error, code_to_reason(status)}

      {:error, %Req.TransportError{reason: error}} ->
        {:error, error}
    end
  end

  defp error_telemetry_step({
         %Req.Request{method: method, options: %{telemetry: telemetry}} = request,
         %Req.TransportError{reason: reason} = error
       }) do
    emit_error(
      System.monotonic_time() - telemetry.start_time,
      method,
      telemetry.path,
      reason
    )

    {request, error}
  end

  defp stop_telemetry_step({
         %Req.Request{method: method, options: %{telemetry: telemetry}} = request,
         %Req.Response{status: status} = response
       }) do
    emit_stop(
      System.monotonic_time() - telemetry.start_time,
      method,
      telemetry.path,
      status
    )

    {request, response}
  end
end
