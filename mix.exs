defmodule AeppSdkElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :aepp_sdk_elixir,
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      aliases: aliases(),
      elixir: "~> 1.8",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:aesophia,
       git: "https://github.com/aeternity/aesophia.git",
       manager: :rebar,
       ref: "dcae96ed21580b3b081cb955da9d8e6fd6879da1"},
      {:distillery, "~> 2.0"},
      {:enacl, github: "aeternity/enacl", ref: "26180f42c0b3a450905d2efd8bc7fd5fd9cece75"},
      {:erl_base58, "~> 0.0.1"},
      {:tesla, "~> 1.2.1"},
      {:poison, "~> 3.0.0"}
    ]
  end

  defp description(), do:
  "Elixir SDK targeting the Æternity node implementation."

  defp aliases do
    [build_api: &build_api/1]
  end

  defp build_api([generator_version, api_specification_version]) do
    Enum.each(
      [
        {"wget",
         [
           "--verbose",
           "https://github.com/aeternity/openapi-generator/releases/download/#{generator_version}/#{
             get_file_name(:generator)
           }-#{generator_version}-ubuntu-x86_64.tar.gz"
         ]},
        {"wget",
         [
           "--verbose",
           "https://raw.githubusercontent.com/aeternity/aeternity/#{api_specification_version}/config/#{
             get_file_name(:specification)
           }.yaml"
         ]},
        {"tar",
         ["zxvf", "#{get_file_name(:generator)}-#{generator_version}-ubuntu-x86_64.tar.gz"]},
        {"rm", ["#{get_file_name(:generator)}-#{generator_version}-ubuntu-x86_64.tar.gz"]},
        {"java",
         [
           "-jar",
           "./#{get_file_name(:generator)}.jar",
           "generate",
           "--skip-validate-spec",
           "-i",
           "./#{get_file_name(:specification)}.yaml",
           "-g",
           "elixir",
           "-o",
           "./apps/aeternity_node/"
         ]},
        {"mix", ["format"]},
        {"rm", ["-f", "#{get_file_name(:generator)}.jar"]},
        {"rm", ["-f", "#{get_file_name(:specification)}.yaml"]}
      ],
      fn {com, args} -> System.cmd(com, args) end
    )
  end

  defp get_file_name(:specification) do
    "swagger"
  end

  defp get_file_name(:generator) do
    "openapi-generator-cli"
  end
end
