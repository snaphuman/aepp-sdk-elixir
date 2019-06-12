defmodule AeternityNode.Model.OracleQueryTx do
  @moduledoc """

  """

  @derive [Poison.Encoder]
  defstruct [
    :oracle_id,
    :query,
    :query_fee,
    :query_ttl,
    :response_ttl,
    :fee,
    :ttl,
    :sender_id,
    :nonce
  ]

  @type t :: %__MODULE__{
          :oracle_id => String.t(),
          :query => String.t(),
          :query_fee => integer(),
          :query_ttl => Ttl,
          :response_ttl => RelativeTtl,
          :fee => integer(),
          :ttl => integer() | nil,
          :sender_id => String.t(),
          :nonce => integer() | nil
        }
end

defimpl Poison.Decoder, for: AeternityNode.Model.OracleQueryTx do
  import AeternityNode.Deserializer

  def decode(value, options) do
    value
    |> deserialize(:query_ttl, :struct, AeternityNode.Model.Ttl, options)
    |> deserialize(:response_ttl, :struct, AeternityNode.Model.RelativeTtl, options)
  end
end
