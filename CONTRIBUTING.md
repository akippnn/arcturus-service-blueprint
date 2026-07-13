# Contributing

Changes should preserve the blueprint's role as a generator and adapter, not create an alternative production deployment engine.

## Validation

```bash
./tests/test-setup.sh
./scripts/arcturus-guard
bash -n scripts/arcturus-setup scripts/arcturus-tool scripts/arcturus-ci \
  scripts/arcturus-lifecycle scripts/arcturus-acceptance \
  scripts/arcturus-host-acceptance scripts/arcturus-release \
  scripts/arcturus-deploy scripts/arcturus-service scripts/arcturus-guard \
  examples/ci/generic.sh
```

Validate every JSON example with `python3 -m json.tool` and run a secret scan before submission.

Pull requests should describe generator compatibility, project-file ownership, migration effects, security implications, and tests performed.
