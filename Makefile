.PHONY: test compose-up compose-down build smoke zip

test:
	python -m pytest -q

compose-up:
	docker compose up --build

compose-down:
	docker compose down --remove-orphans

build:
	docker build -t greenscale-orchestrator:dev ./orchestrator
	docker build -t greenscale-worker:dev ./worker

smoke:
	bash scripts/smoke_test.sh

zip:
	cd .. && zip -r greenscale.zip greenscale -x 'greenscale/.venv/*' 'greenscale/__pycache__/*'
