# Contributing to Psitta

Thank you for considering contributing to Psitta!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/psitta.git`
3. Run `./scripts/bootstrap.sh` to set up your environment
4. Create a feature branch: `git checkout -b feat/your-feature`

## Development Workflow

1. Make your changes
2. Run linters: `pre-commit run --all-files`
3. Run tests: `cd core/backend && pytest`
4. Commit using [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `ci:`
5. Push and open a Pull Request against `develop`

## Code Standards

- **Python**: Ruff for linting/formatting, mypy for type checking
- **Dart**: `dart format` and `dart analyze` with strict rules
- **Tests**: All new features require tests. Minimum coverage: 80%
- **Documentation**: Update relevant docs for API or architecture changes

## Open-Core Boundary

Before contributing, review [OPEN_CORE_BOUNDARY.md](OPEN_CORE_BOUNDARY.md):
- Core features → `core/` directory (Apache 2.0)
- Premium features → `extensions/` directory (requires CLA)

## Pull Request Checklist

- [ ] Tests pass locally
- [ ] Linters pass (`pre-commit run --all-files`)
- [ ] Documentation updated if needed
- [ ] Commit messages follow Conventional Commits
- [ ] PR targets `develop` branch (not `main`)
