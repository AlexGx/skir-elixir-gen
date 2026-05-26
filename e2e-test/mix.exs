defmodule E2ETest.MixProject do
  use Mix.Project

  def project do
    [
      app: :e2e_test,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_skir, git: "https://github.com/AlexGx/ex_skir.git"} # tag: "0.1.0"
    ]
  end
end
