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
  http_adapter: adapter,
  master_merchant_id: System.get_env("BRAINTREE_MASTER_MERCHANT_ID"),
  merchant_id: System.get_env("BRAINTREE_MERCHANT_ID"),
  private_key: System.get_env("BRAINTREE_PRIVATE_KEY"),
  public_key: System.get_env("BRAINTREE_PUBLIC_KEY")
