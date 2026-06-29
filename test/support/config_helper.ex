defmodule Braintree.Test.Support.ConfigHelper do
  @moduledoc false
  @app_key :braintree

  def with_application_config(temp_config, fun) when is_list(temp_config) do
    original = Application.get_all_env(@app_key)

    try do
      for {key, value} <- temp_config, do: Braintree.put_env(key, value)
      fun.()
    after
      # put_all_env merges, it doesn't replace.
      # Make sure any new keys get destroyed.
      for {key, _} <- temp_config, do: Application.delete_env(@app_key, key)
      Application.put_all_env([{@app_key, original}])
    end
  end

  def with_application_config(key, value, fun) when is_atom(key) do
    original = Braintree.get_env(key, :none)

    try do
      Braintree.put_env(key, value)
      fun.()
    after
      case original do
        :none -> :ok = Application.delete_env(@app_key, key)
        _ -> :ok = Braintree.put_env(key, original)
      end
    end
  end
end
