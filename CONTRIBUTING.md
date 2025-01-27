# Contributing to MidiStems

We love your input! We want to make contributing to MidiStems as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Environment Setup

1. Follow the setup instructions in the [README.md](README.md)
2. Install development dependencies:
   ```bash
   flutter pub get
   dart pub global activate flutter_lints
   ```
3. Enable pre-commit hooks:
   ```bash
   git config core.hooksPath .github/hooks
   ```

## Code Style

- Follow the official [Flutter style guide](https://flutter.dev/docs/development/tools/formatting)
- Run `flutter analyze` before submitting PRs
- Write meaningful commit messages following [conventional commits](https://www.conventionalcommits.org/)
- Add tests for new features

## We Develop with Github
We use Github to host code, to track issues and feature requests, as well as accept pull requests.

## We Use [Github Flow](https://guides.github.com/introduction/flow/index.html)
Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests:

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Testing

- Run the Flutter test suite: `flutter test`
- Run Python tests: `python -m pytest python/tests`
- Add tests for new features
- Maintain or improve test coverage

## Documentation

- Update documentation for any changed functionality
- Document new features
- Keep code comments clear and up-to-date
- Follow dartdoc conventions for API documentation

## Report bugs using Github's [issue tracker](https://github.com/midistems/midistems/issues)
We use GitHub issues to track public bugs. Report a bug by [opening a new issue](https://github.com/midistems/midistems/issues/new); it's that easy!

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can.
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Pull Request Process

1. Update the README.md with details of changes to the interface, if applicable.
2. Update the CHANGELOG.md with a note describing your changes.
3. The PR will be merged once you have the sign-off of at least one other developer.

## License
By contributing, you agree that your contributions will be licensed under its MIT License. See the [LICENSE](LICENSE) file for details.