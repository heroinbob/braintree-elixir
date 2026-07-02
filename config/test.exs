import Config

# This allows us to define what adapter is used in integration tests
# for a run. for example:
#
# BRAINTREE_HTTP_ADAPTER=req mix test test/integration
adapter_lookup = %{
  "hackney" => Braintree.HTTP.HackneyAdapter,
  "req" => Braintree.HTTP.ReqAdapter
}

adapter = System.get_env("BRAINTREE_HTTP_ADAPTER", "hackney")
adapter = Map.fetch!(adapter_lookup, adapter)

config :braintree,
  environment: :sandbox,
  http_adapter: adapter
