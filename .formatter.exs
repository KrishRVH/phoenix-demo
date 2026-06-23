[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "{mix,.formatter,.credo}.exs",
    "config/*.exs",
    "lib/**/*.{heex,ex,exs}",
    "test/**/*.{heex,ex,exs}",
    "apps/*/{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/*/seeds.exs",
    "rel/**/*.exs"
  ]
]
