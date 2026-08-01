# Contributing

Thanks for contributing! This project uses **automated releases**
(semantic-release): the **commit message** determines the next version, so please
follow the convention below.

## Commit convention (Conventional Commits)

Format: `<type>(optional scope): description`

| Type | Version bump | Example |
|------|--------------|---------|
| `feat:` | **minor** (1.**X**.0) | `feat: add p4d healthcheck` |
| `fix:` | **patch** (1.0.**X**) | `fix: correct unicode bootstrap` |
| `docs:` `refactor:` `perf:` `build:` `ci:` | patch / none | `docs: update README` |
| `chore:` | none (hidden in the changelog) | `chore: tidy comments` |
| `BREAKING CHANGE:` in the body | **major** (**X**.0.0) | incompatible change |

- Branch **`master`** = stable release → `latest` tag on Docker Hub.
- Branch **`beta`** = prerelease → `beta` tag on Docker Hub.

When you push a `feat:` or `fix:`, GitHub Actions will:

1. compute the new version,
2. update `CHANGELOG.md`,
3. create the GitHub release,
4. build + push the image to Docker Hub (`finallf/perforce`).

## Pull requests

1. Open an issue/discussion before large changes.
2. Update `README.md` if you change variables, ports or parameters.
3. Use the commit convention above — it is what drives the versioning.

## Code of Conduct

We follow the [Contributor Covenant](https://www.contributor-covenant.org/version/1/4/code-of-conduct/).
Please be respectful and welcoming in all interactions with the project.
