defmodule AeternityNode.Model.OracleExtendTx do
  @moduledoc """

  """

  @derive [Poison.Encoder]
  defstruct [
    :fee,
    :oracle_ttl,
    :oracle_id,
    :nonce,
    :ttl
  ]

  @type t :: %__MODULE__{
          :fee => integer(),
          :oracle_ttl => RelativeTtl,
          :oracle_id => String.t(),
          :nonce => integer() | nil,
          :ttl => integer() | nil
        }
end

defimpl Poison.Decoder, for: AeternityNode.Model.OracleExtendTx do
  import AeternityNode.Deserializer

  def decode(value, options) do
    value
    |> deserialize(:oracle_ttl, :struct, AeternityNode.Model.RelativeTtl, options)
  end
end