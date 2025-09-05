defmodule TabletAuth.MixProject do
  use Mix.Project

  def project do
    [
      app: :tablet_auth,
      version: "0.1.4",
      elixir: "~> 1.16",
      description: description(),
      package: package(),
      deps: deps(),
      name: "TabletAuth",
      source_url: "https://github.com/semdinsp/tablet_auth",
      docs: [
        main: "TabletAuth",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"},
      {:bcrypt_elixir, "~> 3.0"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    A secure authentication system designed for tablet and mobile device applications
    requiring simple PIN-based access with device registration capabilities.
    """
  end

  defp package do
    [
      name: "tablet_auth",
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/semdinsp/tablet_auth",
        "Documentation" => "https://hexdocs.pm/tablet_auth"
      },
      maintainers: ["Scott Sproule"]
    ]
  end
end
