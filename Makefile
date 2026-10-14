# Development shortcuts. To install, see the README (./install.sh).
VENV := .venv
PY := $(VENV)/bin/python

.PHONY: help dev app install uninstall clean

help:
	@echo "make dev          create .venv with the package in editable mode"
	@echo "make app          build Clima.app into ~/Applications"
	@echo "make install      ./install.sh"
	@echo "make uninstall    ./uninstall.sh"
	@echo "make clean        remove .venv and build artifacts"

$(PY):
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install --quiet -e ".[midea]"

dev: $(PY)

app:
	scripts/build_app.sh

install:
	./install.sh

uninstall:
	./uninstall.sh

clean:
	rm -rf $(VENV) app/.build build dist src/*.egg-info
