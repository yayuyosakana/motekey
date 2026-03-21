.PHONY: bootstrap-check test

bootstrap-check:
	./scripts/bootstrap_check.sh

test: bootstrap-check
