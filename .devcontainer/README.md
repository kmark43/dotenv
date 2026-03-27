# Dev Container

Base devcontainer config managed by [dotenv](https://github.com/kyler/dotenv).

## Per-project overrides

1. Copy `overrides.example.json` to `overrides.json`
2. Add project-specific features, ports, env vars, etc.
3. Run `merge-devcontainer.sh overrides.json devcontainer.json` to apply

`overrides.json` is gitignored so each machine can customize independently.
