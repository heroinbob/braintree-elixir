import Config

config :braintree,
  environment: :sandbox,
  master_merchant_id: System.get_env("BRAINTREE_MASTER_MERCHANT_ID"),
  merchant_id: System.get_env("BRAINTREE_MERCHANT_ID"),
  private_key: System.get_env("BRAINTREE_PRIVATE_KEY"),
  public_key: System.get_env("BRAINTREE_PUBLIC_KEY")

if Mix.env() == :test do
  import_config "test.exs"
end

try do
  import_config "#{Mix.env()}.secret.exs"
rescue
  [Code.LoadError, File.Error] -> IO.puts("No secret file for #{Mix.env()}")
end
