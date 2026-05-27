# pgvector-rag-stack - atalhos operacionais
# Uso: make <alvo>   (ou veja a lista com: make help)

CONTAINER ?= ia-vector-db
USER      ?= admin
DB        ?= vector_db

.PHONY: help up down reset logs psql check smoke seed-reset

help:
	@echo "Alvos disponiveis:"
	@echo "  make up         - sobe o banco em background"
	@echo "  make down       - para containers (preserva volume)"
	@echo "  make reset      - para containers E apaga o volume (re-executa init.sql)"
	@echo "  make logs       - segue os logs do container"
	@echo "  make psql       - abre shell psql interativo"
	@echo "  make check      - verifica extensao vector ativa (\\dx)"
	@echo "  make smoke      - roda query de similaridade no demo_vectors"

up:
	docker compose up -d
	@echo "Aguardando healthcheck..."
	@until [ "$$(docker inspect -f '{{.State.Health.Status}}' $(CONTAINER) 2>/dev/null)" = "healthy" ]; do sleep 1; done
	@echo "Banco pronto em localhost:5432 (db=$(DB), user=$(USER))"

down:
	docker compose down

reset:
	docker compose down -v
	docker compose up -d

logs:
	docker compose logs -f pgvector-db

psql:
	docker exec -it $(CONTAINER) psql -U $(USER) -d $(DB)

check:
	docker exec $(CONTAINER) psql -U $(USER) -d $(DB) -c "\dx"

smoke:
	docker exec $(CONTAINER) psql -U $(USER) -d $(DB) -c \
	  "SELECT label, embedding <=> '[1,0,0]' AS distancia FROM demo_vectors ORDER BY embedding <=> '[1,0,0]' LIMIT 3;"
