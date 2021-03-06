defmodule AeppSDK.GeneralizedAccount do
  @moduledoc """
  Contains all generalized accounts functionalities.

  In order for its functions to be used, a client must be defined first.
  Client example can be found at: `AeppSDK.Client.new/4`.

  For more information: [https://github.com/aeternity/protocol/blob/master/generalized_accounts/generalized_accounts.md](https://github.com/aeternity/protocol/blob/master/generalized_accounts/generalized_accounts.md)
  """

  alias AeppSDK.{Client, Contract}
  alias AeppSDK.Utils.Account, as: AccountUtils
  alias AeppSDK.Utils.{Encoding, Hash, Serialization, Transaction}
  alias AeternityNode.Api.Chain, as: ChainApi
  alias AeternityNode.Model.Error

  @init_function "init"
  @default_gas 50_000

  @doc """
  Attach a generalized account to a basic account. After a generalized account has been attached, it's possible
  pass an :auth option to transaction related functions in order to authorize them through the attached contract.
  A transaction is authorized whenever the call to the auth function returns true (and unauthorized when false).

  The option looks like this:
  auth: [
    auth_contract_source: "contract Authorization =

      function auth(auth_value : bool) =
        auth_value",
    auth_args: ["true"],
    fee: 1_000_000_000_000_00,
    gas: 50_000,
    gas_price: 1_000_000_000,
    ttl: 0
  ]
  where gas, gas_price and ttl are optional.

  ## Examples
      iex> source_code = "contract Authorization =

        entrypoint auth(auth_value : bool) =
          auth_value"
      iex> auth_fun = "auth"
      iex> init_args = []
      iex> AeppSDK.GeneralizedAccount.attach(client, source_code, auth_fun, init_args)
      {:ok,
       %{
         block_hash: "mh_CfEuHm4V2omAQGNAxcdPARrkfnYbKuuF1HpGhG5oQvoVC34nD",
         block_height: 92967,
         tx_hash: "th_9LutrWD1FuFyx4MUUeMcfyF3uebfaP8t5gzatWDLyFYsqK744"
       }}
  """
  @spec attach(Client.t(), String.t(), String.t(), list(String.t()), list()) ::
          {:ok,
           %{
             block_hash: Encoding.base58c(),
             block_height: non_neg_integer(),
             tx_hash: Encoding.base58c()
           }}
          | {:error, String.t()}
          | {:error, Env.t()}
  def attach(
        %Client{
          keypair: %{public: public_key},
          connection: connection,
          network_id: network_id,
          gas_price: gas_price
        } = client,
        source_code,
        auth_fun,
        init_args,
        opts \\ []
      ) do
    user_fee = Keyword.get(opts, :fee, Transaction.dummy_fee())
    vm = Keyword.get(opts, :vm, :fate)

    with {:ok, nonce} <- AccountUtils.next_valid_nonce(client, public_key),
         {:ok, ct_version} <- Contract.get_ct_version(opts),
         {:ok,
          %{
            byte_code: byte_code,
            compiler_version: compiler_version,
            type_info: type_info,
            payable: payable
          }} <-
           Contract.compile(source_code, vm),
         {:ok, calldata} <- Contract.create_calldata(source_code, @init_function, init_args, vm),
         {:ok, function_hash} <- hash_from_function_name(auth_fun, type_info, vm),
         {:ok, source_hash} <- Hash.hash(source_code),
         byte_code_fields = [
           source_hash,
           type_info,
           byte_code,
           compiler_version,
           payable
         ],
         serialized_wrapped_code = Serialization.serialize(byte_code_fields, :sophia_byte_code),
         ga_attach_tx = %{
           owner_id: public_key,
           nonce: nonce,
           code: serialized_wrapped_code,
           auth_fun: function_hash,
           ct_version: ct_version,
           fee: user_fee,
           ttl: Keyword.get(opts, :ttl, Transaction.default_ttl()),
           gas: Keyword.get(opts, :gas, Contract.default_gas()),
           gas_price: Keyword.get(opts, :gas_price, Contract.default_gas_price()),
           call_data: calldata
         },
         {:ok, %{height: height}} <- ChainApi.get_current_key_block_height(connection),
         new_fee <-
           Transaction.calculate_n_times_fee(
             ga_attach_tx,
             height,
             network_id,
             user_fee,
             gas_price,
             Transaction.default_fee_calculation_times()
           ),
         {:ok, response} <-
           Transaction.post(
             client,
             %{ga_attach_tx | fee: new_fee},
             Keyword.get(opts, :auth, :no_auth),
             :one_signature
           ) do
      {:ok, response}
    else
      {:ok, %Error{reason: message}} ->
        {:error, message}

      {:error, _} = error ->
        error
    end
  end

  @doc """
     Computes an authorization id for given GA meta tx

  ## Examples
      iex> meta_tx = %{
                        abi_version: 3,
                        auth_data: <<43, 17, 244, 119, 202, 45, 27, 127>>,
                        fee: 100000000000000,
                        ga_id: "ak_wuLXPE5pd2rvFoxHxvenBgp459rW6Y1cZ6cYTZcAcLAevPE5M",
                        gas: 50000,
                        gas_price: 1000000,
                        ttl: 0,
                        tx: <<248, 87, 11, 1, 192, 184, 82, 248, 80, 12, 1, 161, 1, 124, 169, 154,
                          140, 216, 36, 178, 163, 239, 195, 198, 197, 213, 0, 88, 87, 19, 67, 5, 117,
                          212, 206, 105, 153, 178, 2, 203, 32, 248, 96, 25, 216, 161, 1, 11, 180, 237,
                          121, 39, 249, 123, 81, 225, 188, 181, 225, 52, 13, 18, 51, 91, 42, 43, 18,
                          200, 188, 82, 33, 214, 60, 75, 203, 57, 212, 30, 97, 100, 133, 3, 223, 210,
                          64, 0, 0, 0, 128>>
                      }
      iex> AeppSDK.GeneralizedAccount.compute_auth_id(meta_tx)
      {:ok,
       <<141, 79, 64, 237, 32, 190, 35, 175, 230, 66, 224, 247, 43, 83, 109, 142, 1,
         161, 69, 1, 114, 107, 20, 99, 55, 155, 198, 212, 142, 147, 104, 117>>}
  """
  @spec compute_auth_id(map()) :: {:ok, binary()}
  def compute_auth_id(%{ga_id: ga_id, auth_data: auth_data} = _meta_tx) do
    decoded_ga_id = Encoding.prefix_decode_base58c(ga_id)
    {:ok, _auth_id} = Hash.hash(decoded_ga_id <> auth_data)
  end

  @doc """
  false
  """
  def default_gas, do: @default_gas

  defp hash_from_function_name(auth_fun, type_info, vm) do
    case vm do
      :aevm ->
        :aeb_aevm_abi.type_hash_from_function_name(auth_fun, type_info)

      :fate ->
        Hash.hash(auth_fun)
    end
  end
end
