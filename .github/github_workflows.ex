defmodule GithubWorkflows do
    @moduledoc """
    Run `mix github_workflows.generate` after updating this module.
    See https://hexdocs.pm/github_workflows_generator.
    """
  
    def get do
      %{
        "master.yml" => master_workflow(),
        "pr.yml" => pr_workflow()
      }
    end
  
    defp master_workflow do
      [
        [
          name: "master",
          on: [
            push: [
              branches: ["master"]
            ]
          ],
          jobs: elixir_ci_jobs()
        ]
      ]
    end
  
    defp pr_workflow do
      [
        [
          name: "PR",
          on: [
            pull_request: [
              branches: ["master"],
              types: ["opened", "reopened", "synchronize"]
            ]
          ],
          jobs: elixir_ci_jobs()
        ]
      ]
    end
  
    defp elixir_ci_jobs do
      [
        compile: compile_job(),
        credo: credo_job(),
        deps_audit: deps_audit_job(),
        # dialyzer: dialyzer_job(),
        format: format_job(),
        hex_audit: hex_audit_job(),
        # migrations: migrations_job(),
        prettier: prettier_job(),
        sobelow: sobelow_job(),
        # test: test_job(),
        unused_deps: unused_deps_job()
      ]
    end
  
    defp compile_job do
      elixir_job("Install deps and compile",
        steps: [
          [
            name: "Install Elixir dependencies",
            env: [MIX_ENV: "test"],
            run: "mix deps.get"
          ],
          [
            name: "Compile",
            env: [MIX_ENV: "test"],
            run: "mix compile --warnings-as-errors"
          ]
        ]
      )
    end
  
    defp deps_audit_job do
      elixir_job("Deps audit",
        needs: :compile,
        steps: [
          [
            name: "Check for vulnerable Mix dependencies",
            env: [MIX_ENV: "test"],
            run: "mix deps.audit"
          ]
        ]
      )
    end
  
    defp elixir_job(name, opts) do
      needs = Keyword.get(opts, :needs)
      services = Keyword.get(opts, :services)
      steps = Keyword.get(opts, :steps, [])
  
      cache_key_prefix =
        "${{ runner.os }}-${{ steps.setup-beam.outputs.elixir-version }}-${{ steps.setup-beam.outputs.otp-version }}-mix"
  
      job = [
        name: name,
        "runs-on": "ubuntu-latest",
        steps:
          [
            checkout_step(),
            [
              id: "setup-beam",
              name: "Set up Elixir",
              uses: "erlef/setup-beam@v1",
              with: [
                "version-file": ".tool-versions",
                "version-type": "strict"
              ]
            ],
            [
              uses: "actions/cache@v3",
              with:
                [
                  path: ~S"""
                  _build
                  deps
                  """
                ] ++ cache_opts(cache_key_prefix)
            ]
          ] ++ steps
      ]
  
      job
      |> then(fn job ->
        if needs do
          Keyword.put(job, :needs, needs)
        else
          job
        end
      end)
      |> then(fn job ->
        if services do
          Keyword.put(job, :services, services)
        else
          job
        end
      end)
    end
  
    defp format_job do
      elixir_job("Format",
        needs: :compile,
        steps: [
          [
            name: "Check Elixir formatting",
            env: [MIX_ENV: "test"],
            run: "mix format --check-formatted"
          ]
        ]
      )
    end
  
    defp hex_audit_job do
      elixir_job("Hex audit",
        needs: :compile,
        steps: [
          [
            name: "Check for retired Hex packages",
            env: [MIX_ENV: "test"],
            run: "mix hex.audit"
          ]
        ]
      )
    end

    defp credo_job do
        elixir_job("Credo",
          needs: :compile,
          steps: [
            [
              name: "Check code style",
              env: [MIX_ENV: "test"],
              run: "mix credo --strict"
            ]
          ]
        )
      end

  
    # defp migrations_job do
    #   elixir_job("Migrations",
    #     needs: :compile,
    #     services: [
    #       db: db_service()
    #     ],
    #     steps: [
    #       [
    #         name: "Setup DB",
    #         env: [MIX_ENV: "test"],
    #         run: "mix do ecto.create --quiet, ecto.migrate --quiet"
    #       ],
    #       [
    #         name: "Check if migrations are reversible",
    #         env: [MIX_ENV: "test"],
    #         run: "mix ecto.rollback --all --quiet"
    #       ]
    #     ]
    #   )
    # end
  
    defp prettier_job do
      [
        name: "Check formatting using Prettier",
        "runs-on": "ubuntu-latest",
        steps: [
          checkout_step(),
          [
            name: "Restore npm cache",
            uses: "actions/cache@v3",
            id: "npm-cache",
            with: [
              path: "node_modules",
              key: "${{ runner.os }}-prettier"
            ]
          ],
          [
            name: "Install Prettier",
            if: "steps.npm-cache.outputs.cache-hit != 'true'",
            run: "npm i -D prettier prettier-plugin-toml"
          ],
          [
            name: "Run Prettier",
            run: "npx prettier -c ."
          ]
        ]
      ]
    end
  
    defp sobelow_job do
      elixir_job("Security check",
        needs: :compile,
        steps: [
          [
            name: "Check for security issues using sobelow",
            env: [MIX_ENV: "test"],
            run: "mix sobelow --config .sobelow-conf"
          ]
        ]
      )
    end
  
    defp unused_deps_job do
      elixir_job("Check unused deps",
        needs: :compile,
        steps: [
          [
            name: "Check for unused Mix dependencies",
            env: [MIX_ENV: "test"],
            run: "mix deps.unlock --check-unused"
          ]
        ]
      )
    end
  
    defp checkout_step do
      [
        name: "Checkout",
        uses: "actions/checkout@v4"
      ]
    end
  
    defp cache_opts(prefix) do
      [
        key: "#{prefix}-${{ github.sha }}",
        "restore-keys": ~s"""
        #{prefix}-
        """
      ]
    end
  end
  