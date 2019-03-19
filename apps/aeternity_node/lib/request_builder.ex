defmodule AeternityNode.RequestBuilder do
  @moduledoc """
  Helper functions for building Tesla requests
  """

  alias AeternityNode.Client

  @doc """
  Specify the request method when building a request

  ## Parameters

  - request (Map) - Collected request options
  - m (atom) - Request method

  ## Returns

  Map
  """
  @spec method(map(), atom) :: map()
  def method(request, m) do
    Map.put_new(request, :method, m)
  end

  @doc """
  Specify the request method when building a request

  ## Parameters

  - request (Map) - Collected request options
  - u (String) - Request URL

  ## Returns

  Map
  """
  @spec url(map(), String.t()) :: map()
  def url(request, u) do
    Map.put_new(request, :url, u)
  end

  @doc """
  Add optional parameters to the request

  ## Parameters

  - request (Map) - Collected request options
  - definitions (Map) - Map of parameter name to parameter location.
  - options (KeywordList) - The provided optional parameters

  ## Returns

  Map
  """
  @spec add_optional_params(map(), %{optional(atom) => atom}, keyword()) :: map()
  def add_optional_params(request, _, []), do: request

  def add_optional_params(request, definitions, [{key, value} | tail]) do
    case definitions do
      %{^key => location} ->
        request
        |> add_param(location, key, value)
        |> add_optional_params(definitions, tail)

      _ ->
        add_optional_params(request, definitions, tail)
    end
  end

  @doc """
  Add optional parameters to the request

  ## Parameters

  - request (Map) - Collected request options
  - location (atom) - Where to put the parameter
  - key (atom) - The name of the parameter
  - value (any) - The value of the parameter

  ## Returns

  Map
  """
  @spec add_param(map(), atom, atom, any()) :: map()
  def add_param(request, :body, :body, value), do: Map.put(request, :body, value)

  def add_param(request, :body, key, value) do
    request
    |> Map.put_new_lazy(:body, &Tesla.Multipart.new/0)
    |> Map.update!(
      :body,
      &Tesla.Multipart.add_field(
        &1,
        key,
        Poison.encode!(value),
        headers: [{:"Content-Type", "application/json"}]
      )
    )
  end

  def add_param(request, :file, name, path) do
    request
    |> Map.put_new_lazy(:body, &Tesla.Multipart.new/0)
    |> Map.update!(:body, &Tesla.Multipart.add_file(&1, path, name: name))
  end

  def add_param(request, :form, name, value) do
    request
    |> Map.update(:body, %{name => value}, &Map.put(&1, name, value))
  end

  def add_param(request, location, key, value) do
    Map.update(request, location, [{key, value}], &(&1 ++ [{key, value}]))
  end

  @doc """
  Handle the response for a Tesla request

  ## Parameters

  - arg1 ({:ok, Tesla.Env.t} | term) - The response object
  - arg2 (:false | struct | [struct]) - The shape of the struct to deserialize into

  ## Returns

  {:ok, struct} on success
  {:error, term} on failure
  """
  @spec decode({:ok, Tesla.Env.t()} | term()) ::
          {:ok, struct()} | {:error, Tesla.Env.t()} | {:error, term()}
  def decode({:ok, %Tesla.Env{status: 200, body: body}}), do: Poison.decode(body)
  def decode({_, response}), do: {:error, response}

  @spec decode({:ok, Tesla.Env.t()} | term(), false | struct() | [struct()]) ::
          {:ok, struct()} | {:error, Tesla.Env.t()} | {:error, term()}
  def decode({:ok, %Tesla.Env{status: 200} = env}, false), do: {:ok, env}

  def decode({:ok, %Tesla.Env{status: 200, body: body}}, struct),
    do: Poison.decode(body, as: struct)

  def decode({:ok, %Tesla.Env{body: body}}, _struct) do
    case Poison.decode(body) do
      {:ok, error_response} -> {:error, error_response}
      decode_error -> decode_error
    end
  end

  @spec process_request(map(), Tesla.Env.client()) ::
          {:ok, struct()} | {:error, Tesla.Env.t()} | {:error, term()}
  def process_request(map, connection) do
    map
    |> Enum.into([])
    |> (&Client.request(connection, &1)).()
    |> decode()
  end
end
