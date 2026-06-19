## Summary

<!-- What does this PR do? One paragraph is fine. -->

## Type of change

- [ ] Bug fix
- [ ] New app added to catalogue
- [ ] New feature or panel
- [ ] OS compatibility improvement
- [ ] Refactor / cleanup
- [ ] Documentation update
- [ ] CI / build improvement

## Testing

<!-- How did you test this? Which OS and GPU did you test on? -->

**OS tested on:**
**GPU:**

- [ ] `bash -n scripts/*.sh` passes (all shell scripts syntax-check clean)
- [ ] `npm run build` completes without errors
- [ ] `cargo check` passes in `src-tauri/`
- [ ] Manually tested the affected feature end-to-end

## Checklist

- [ ] No hardcoded paths, usernames, or machine-specific values
- [ ] New app entries include `installMethods` for all relevant OS families
- [ ] New app entries include `osSupport` entries with plain-English notes
- [ ] `--dry-run` behaviour is correct for any new install commands
- [ ] CHANGELOG.md updated (under `## [Unreleased]`)

## Related issues

<!-- Closes #XX / Related to #XX -->
