# Only include when :hackney is available.
if match?({:module, :fart}, Code.ensure_compiled(:hackney)) do
  defmodule Braintree.HTTP.HackneyAdapter do
    @moduledoc """
    HTTP adapter that relies on Hackney for transport.
    """
    @behaviour Braintree.HTTP.AdapterBehaviour

    use Braintree.HTTP.Requests

    import Braintree.HTTP.Telemetry

    alias Braintree.XML.Decoder

    require Logger

    @headers [
      accept_header(),
      api_version_header(),
      accept_encoding_header(),
      content_type_header(),
      user_agent_header()
    ]

    @impl Braintree.HTTP.AdapterBehaviour
    def request(method, path, body \\ %{}, opts \\ []) do
      emit_start(method, path)

      start_time = System.monotonic_time()

      try do
        url = build_url(path, opts)

        case :hackney.request(
               method,
               url,
               [get_auth_header(opts) | @headers],
               encode_body(body),
               build_options([{:url, url} | opts])
             ) do
          {:ok, code, _headers, body} when code in 200..299 ->
            duration = System.monotonic_time() - start_time
            emit_stop(duration, method, path, code)
            decode_xml(body)

          {:ok, code, _headers, _body} when code in 300..399 ->
            duration = System.monotonic_time() - start_time
            emit_stop(duration, method, path, code)
            {:ok, ""}

          {:ok, 422, _headers, body} ->
            duration = System.monotonic_time() - start_time
            emit_stop(duration, method, path, 422)

            with {:ok, xml} <- decode_xml(body),
                 resolved <- resolve_error_response(xml) do
              {:error, resolved}
            end

          {:ok, code, _headers, _body} when code in 400..504 ->
            duration = System.monotonic_time() - start_time
            emit_stop(duration, method, path, code)
            {:error, code_to_reason(code)}

          {:error, reason} ->
            duration = System.monotonic_time() - start_time
            emit_error(duration, method, path, reason)
            {:error, reason}
        end
      catch
        kind, reason ->
          duration = System.monotonic_time() - start_time

          emit_exception(duration, method, path, %{
            kind: kind,
            reason: reason,
            stacktrace: __STACKTRACE__
          })

          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end

    defp build_options(opts) do
      http_opts =
        :http_options
        |> Braintree.get_env([])
        |> Keyword.put_new(:recv_timeout, 30_000)
        |> Keyword.put_new(:connect_timeout, 10_000)

      [:with_body] ++ ssl_opts(opts) ++ http_opts
    end

    defp decode_xml(body) do
      {
        :ok,
        body
        |> :zlib.gunzip()
        |> String.trim()
        |> Decoder.load()
      }
    rescue
      error ->
        Logger.error("Braintree unable to decode response: #{inspect(error)}")
        {:error, :invalid_response}
    end

    defp ssl_opts(opts) do
      production = production_endpoint()
      sandbox = sandbox_endpoint()

      # NOTE: this pivots on URL (not env) due to the hackney 1.23.0 bug.
      case opts[:url] do
        ^production <> _ ->
          [
            ssl_options: [
              verify: :verify_peer,
              # avoid bug in hackney 1.23.0 that compares SSL hostname to resolved IP
              server_name_indication: String.to_charlist("api.braintreegateway.com"),
              cacertfile: get_production_cacertfile_path(opts)
            ]
          ]

        ^sandbox <> _ ->
          [
            ssl_options: [
              verify: :verify_peer,
              # avoid bug in hackney 1.23.0 that compares SSL hostname to resolved IP
              server_name_indication: String.to_charlist("api.sandbox.braintreegateway.com"),
              cacertfile: get_sandbox_cacertfile_path(opts)
            ]
          ]

        _ ->
          []
      end
    end
  end
end
