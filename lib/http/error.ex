defmodule Braintree.HTTP.Error do
  @moduledoc """
  Represents an unexpected exception that took place during an HTTP request.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          error: any()
        }

  defexception [:message, :error]
end
