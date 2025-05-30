#* Variables
SHELL := /usr/bin/env bash

THIS_MAKEFILE := $(realpath $(lastword $(MAKEFILE_LIST)))
REPO_DIR := $(patsubst %/,%,$(dir $(THIS_MAKEFILE)))
REPO_PREFIX := ../$(notdir $(abspath $(REPO_DIR)))

PYTHON := python3
PYTHONPATH := $(REPO_DIR)/git-revision-graph

#* Makefile debugging
print-%: ; @$(warning $* is $($*) ($(value $*)) (from $(origin $*)))

define message
@echo -n "make[top]: "
@echo $(1)
endef

#* Grphviz
.PHONY: dot-install
dot-install:
	sudo apt install -y graphviz

#* Poetry
.PHONY: poetry-download
poetry-download:
	curl -sSL https://install.python-poetry.org | $(PYTHON) -

.PHONY: poetry-remove
poetry-remove:
	curl -sSL https://install.python-poetry.org | $(PYTHON) - --uninstall

#* Installation
.PHONY: install
install:
	poetry lock -n && poetry export --without-hashes > requirements.txt
	poetry install -n
	-poetry run mypy --install-types --non-interactive ./

.PHONY: pre-commit-install
pre-commit-install:
	poetry run pre-commit install

#* Formatters
.PHONY: codestyle
codestyle:
	poetry run pyupgrade --exit-zero-even-if-changed --py38-plus git_revision_graph/*.py
	poetry run isort --settings-path pyproject.toml ./
	poetry run black --config pyproject.toml ./

.PHONY: formatting
formatting: codestyle

#* Linting
.PHONY: test
test:
	PYTHONPATH=$(PYTHONPATH) poetry run pytest -c pyproject.toml --cov-report=html --cov=git_revision_graph tests/
	poetry run coverage-badge -o assets/images/coverage.svg -f
	poetry run python -m git_revision_graph -o assets/images/graph.svg

.PHONY: check-codestyle
check-codestyle:
	poetry run isort --diff --check-only --settings-path pyproject.toml ./
	poetry run black --diff --check --config pyproject.toml ./
	poetry run darglint --verbosity 2 git-revision-graph tests

.PHONY: mypy
mypy:
	poetry run mypy --config-file pyproject.toml ./

.PHONY: check-safety
check-safety:
	poetry check
	-poetry run safety check --full-report
	poetry run bandit -ll --recursive git-revision-graph tests

.PHONY: lint
lint: test check-codestyle mypy check-safety

.PHONY: update-dev-deps
update-dev-deps:
	poetry add -D bandit@latest darglint@latest "isort[colors]@latest" mypy@latest pre-commit@latest pydocstyle@latest pylint@latest pytest@latest pyupgrade@latest safety@latest coverage@latest coverage-badge@latest pytest-html@latest pytest-cov@latest
	poetry add -D --allow-prereleases black@latest

#* Cleaning
.PHONY: pycache-remove
pycache-remove:
	find . | grep -E "(__pycache__|\.pyc|\.pyo$$)" | xargs rm -rf

.PHONY: dsstore-remove
dsstore-remove:
	find . | grep -E ".DS_Store" | xargs rm -rf

.PHONY: mypycache-remove
mypycache-remove:
	find . | grep -E ".mypy_cache" | xargs rm -rf

.PHONY: ipynbcheckpoints-remove
ipynbcheckpoints-remove:
	find . | grep -E ".ipynb_checkpoints" | xargs rm -rf

.PHONY: pytestcache-remove
pytestcache-remove:
	find . | grep -E ".pytest_cache" | xargs rm -rf

.PHONY: build-dist
build-dist:
	$(PYTHON) -m build --outdir dist/

.PHONY: build-remove
build-remove:
	rm -rf dist/

.PHONY: cleanup
cleanup: pycache-remove dsstore-remove mypycache-remove ipynbcheckpoints-remove pytestcache-remove
