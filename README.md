<div align="center">

# asdf-pyapp ![Build](https://github.com/rynkowsg/asdf-pyapp/workflows/Build/badge.svg) ![Lint](https://github.com/rynkowsg/asdf-pyapp/workflows/Lint/badge.svg)

A generic Python Application plugin the [asdf version manager](https://asdf-vm.com).

</div>

**What is a "Python Application"?**

For purposes of this plugin, a Python Application is program that _happens_ to be written in Python, but otherwise behaves like a regular command-line tool. The term "Python Application" comes from [pipx](https://pypa.github.io/pipx/).

Examples of Python Applications are [awscli](https://pypi.org/project/awscli/) and [conan](https://pypi.org/project/conan/). See below for more compatible applications.

# Dependencies

- `python`/`python3` >= 3.6 with pip and venv
- OR [asdf-python](https://github.com/danhper/asdf-python) installed

# Install

Plugin:

```shell
asdf plugin add <python app> https://github.com/rynkowsg/asdf-pyapp.git
# for example
asdf plugin add cowsay https://github.com/rynkowsg/asdf-pyapp.git
```

Example using `cowsay`:

```shell
# Show all installable versions
asdf list-all cowsay

# Install specific version
asdf install cowsay latest

# Set a version globally (on your ~/.tool-versions file)
asdf global cowsay latest

# Now cowsay commands are available
cowsay "Hi!"
```

## Compatible Python Applications

This is a non-exhaustive list of Python Applications that work with this plugin.

| App                                                      | Command to add Plugin                                                                          | Notes                                                              |
|----------------------------------------------------------|------------------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| [ansible](https://pypi.org/project/ansible/)             | `ASDF_PYAPP_INCLUDE_DEPS=1 asdf plugin add ansible https://github.com/rynkowsg/asdf-pyapp.git` | [(info)](#environment-variables)                                   |
| [awscli](https://pypi.org/project/awscli/)               | `asdf plugin add awscli https://github.com/rynkowsg/asdf-pyapp.git`                            |                                                                    |
| [awsebcli](https://pypi.org/project/awsebcli/)           | `asdf plugin add awsebcli https://github.com/rynkowsg/asdf-pyapp.git`                          |                                                                    |
| [aws-sam-cli](https://pypi.org/project/aws-sam-cli/)     | `asdf plugin add aws-sam-cli https://github.com/rynkowsg/asdf-pyapp.git`                       |                                                                    |
| [aws-ssm-tools](https://pypi.org/project/aws-ssm-tools/) | `asdf plugin add aws-ssm-tools https://github.com/rynkowsg/asdf-pyapp.git`                     |                                                                    |
| [black](https://pypi.org/project/black/)                 | `asdf plugin add black https://github.com/rynkowsg/asdf-pyapp.git`                             |                                                                    |
| [bpython](https://pypi.org/project/bpython/)             | `asdf plugin add bpython https://github.com/rynkowsg/asdf-pyapp.git`                           |                                                                    |
| [conan](https://pypi.org/project/conan/)                 | `asdf plugin add conan https://github.com/rynkowsg/asdf-pyapp.git`                             |                                                                    |
| [cowsay](https://pypi.org/project/cowsay/)               | `asdf plugin add cowsay https://github.com/rynkowsg/asdf-pyapp.git`                            |                                                                    |
| [dbt](https://pypi.org/project/dbt/)                     | `ASDF_PYAPP_INCLUDE_DEPS=1 asdf plugin add dbt https://github.com/rynkowsg/asdf-pyapp.git`     | [(info)](#environment-variables)                                   |
| [doit](https://pypi.org/project/doit/)                   | `asdf plugin add doit https://github.com/rynkowsg/asdf-pyapp.git`                              |                                                                    |
| [flake8](https://pypi.org/project/flake8/)               | `asdf plugin add flake8 https://github.com/rynkowsg/asdf-pyapp.git`                            |                                                                    |
| [hy](https://pypi.org/project/hy/)                       | `asdf plugin add hy https://github.com/rynkowsg/asdf-pyapp.git`                                | The latest stable version of hy (0.20.0 atm) requires python > 3.8 |
| [meson](https://pypi.org/project/meson/)                 | `asdf plugin add meson https://github.com/rynkowsg/asdf-pyapp.git`                             |                                                                    |
| [mypy](https://pypi.org/project/mypy/)                   | `asdf plugin add mypy https://github.com/rynkowsg/asdf-pyapp.git`                              |                                                                    |
| [pipenv](https://pypi.org/project/pipenv/)               | `asdf plugin add pipenv https://github.com/rynkowsg/asdf-pyapp.git`                            |                                                                    |
| [pre-commit](https://pypi.org/project/pre-commit/)       | `asdf plugin add pre-commit https://github.com/rynkowsg/asdf-pyapp.git`                        |                                                                    |
| [salt](https://pypi.org/project/salt/)                   | `asdf plugin add salt https://github.com/rynkowsg/asdf-pyapp.git`                              |                                                                    |
| [sphinx](https://pypi.org/project/Sphinx/)               | `asdf plugin add sphinx https://github.com/rynkowsg/asdf-pyapp.git`                            |                                                                    |
| [yawsso](https://pypi.org/project/yawsso/)               | `asdf plugin add sphinx https://github.com/rynkowsg/asdf-pyapp.git`                            |                                                                    |
| [youtube-dl](https://pypi.org/project/youtube-dl/)       | `asdf plugin add sphinx https://github.com/rynkowsg/asdf-pyapp.git`                            |                                                                    |

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to install & manage versions.

# How it Works

asdf-pyapp is a lot more complex than most asdf plugins since it's designed to work with generic Python Applications, and challenges that come with Python itself.

asdf-pyapp uses the same technique as [asdf-hashicorp](https://github.com/asdf-community/asdf-hashicorp) to use a single plugin for multiple tools.

When installing a tool, asdf-pyapp creates a fresh [virtual environment](https://docs.python.org/3/tutorial/venv.html) and pip-installs the package matching the plugin name. Then it uses pipx under the hood to extract the entrypoints for the package exposes them to asdf.

## Python Resolution

To run Python Applications, you need Python:

1. If `ASDF_PYAPP_DEFAULT_PYTHON_PATH` is set - use it
1. Else if the `asdf-python` plugin is installed - use the **global** `python3`\*\*.
1. Finally, just use `python3` in our path.

\*\* _We use the global `python3` to avoid picking up local python versions inside projects, which would result in inconsistent tool installations. If you want to install a tool with a specific version of Python see the following section on asdf-python Integration._

## asdf-python Integration (Experimental)

Here we color outside the lines a bit :)

asdf-python supports installing a Python App with a _specific_ Python version using a special syntax. This feature requires the [asdf-python](https://github.com/danhper/asdf-python) plugin to be installed.

The general form is:

```shell
asdf <app> install <app-version>@<python-version>
```

For example, to install `cowsay` 3.0 with Python 3.9.1:

```shell
asdf cowsay install 3.0@3.9.1
```

Python Apps with different python versions and python itself can all happily co-exist in the same project. For example, take this `.tool-versions`:

```shell
python 3.8.5
awscli 1.19.93
cowsay 3.0@3.9.1
conan 1.36.0@3.8.5
```

- `awscli` will be installed with the global Python (see Python Resolution), in an isolated virtual environment
- Python 3.9.1 will be installed, and then `cowsay` will be installed using that Python (in a venv)
- `conan` will be installed with Python 3.8.5, but isolated from the project's Python, which is also 3.8.5.

# Configuration

## Environment Variables

- `ASDF_PYAPP_INCLUDE_DEPS` - when set to `1`, this plugin will consider the executables of the dependencies of the installed package as well. For example, when installing `ansible`, the `ansible` command actually comes from its depency, `ansible-core`. This is the same as Pipx's `--include-deps` flag.
- `ASDF_PYAPP_DEFAULT_PYTHON_PATH` - Path to a `python`/`python3` binary this plugin should use. Default is unset. See Python Resolution section for more details.
- `ASDF_PYAPP_VENV_COPY_MODE`:
  - `0`: (default) Add `--copies` flag to venvs created with a specific Python version. Symlinks otherwise.
  - `1`: Prefer `--copies` whenever possible (`--copies` does not work with `/usr/bin/python3` on macOS).
- `ASDF_PYAPP_DEBUG` - Set to `1` for additional logging

# Background and Inspiration

asdf-pyapp was created by [Andy Mroczkowski](https://github.com/amrox).
It was inspired by [asdf-hashicorp](https://github.com/asdf-community/asdf-hashicorp) and [pipx](https://pypa.github.io/pipx/) - which is also used under the hood.
This fork was created as a response to original repository not responding to PRs trying to address an issue that surfaced up with pip v24.

# TODO

- [ ] fix integration-tests.bats

# License

See [LICENSE](LICENSE).

Copyright (c) 2021 [Andy Mroczkowski](https://github.com/amrox)
Copyright (c) 2025 [Greg Rynkowski](https://github.com/rynkowsg)
