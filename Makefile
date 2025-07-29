.PHONY: migrations
migrations:
	uv run manage.py makemigrations

.PHONY: migrate
migrate:
	uv run manage.py migrate

.PHONY: superuser
superuser:
	uv run manage.py createsuperuser

.PHONY: run
run:
	uv run manage.py runserver

.PHONY: clean
clean:
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -exec rm -rf {} +
	find . -name ".ruff_cache" -exec rm -rf {} +
	find . -name ".pytest_cache" -delete
	find . -name ".coverage" -delete
	find . -name "htmlcov" -delete

.PHONY: shell
shell:
	uv run manage.py shell --force-color

.PHONY: check
check:
	uv run manage.py check