# pgvector-rag-stack

> Infraestrutura **Plug & Play** para RAG: PostgreSQL 16 + pgvector em Docker Compose.
> Clone, suba com um comando e tenha um banco vetorizado pronto para `text-embedding-3-small` (1536 dims).

**Autor:** Gabriel Fernandes Carvalho — Matrícula **2320142**
**Disciplina:** Arquitetura de Software — UniEVANGÉLICA 2026.1
**Atividade:** APS 16 — Banco Vetorizado para IA (Aula 15 — Cloud Native, 12-Factor App)

---

## 🎯 Propósito

Sistemas modernos com IA usam **RAG (Retrieval-Augmented Generation)** em vez de busca por palavra-chave: o texto vira **embedding** (vetor numérico), o vetor é guardado no banco e a consulta retorna os vetores matematicamente mais próximos do vetor da pergunta. Para isso, o banco precisa entender matemática vetorial — papel do **pgvector**.

Este repositório entrega essa camada de infraestrutura pronta:

- ✅ PostgreSQL 16 com `pgvector` pré-compilado (sem compilar nada na sua máquina)
- ✅ Bootstrap automático na primeira subida via `init.sql`
- ✅ Schema `rag` com tabelas `documents` e `chunks(embedding vector(1536))`
- ✅ Dados de smoke test (5 cores RGB) para validar similaridade imediatamente
- ✅ Healthcheck, limites de recurso e `.env` para configuração 12-Factor
- ✅ Makefile com atalhos operacionais

Qualquer projeto que precise de IA + busca semântica clona, roda `make up` e tem o banco.

---

## ⚡ Quick start

```bash
# 1. Clone
git clone https://github.com/GabrielGFC/pgvector-rag-stack.git
cd pgvector-rag-stack

# 2. (Opcional) configure credenciais — sem isso, usa os defaults
cp .env.example .env

# 3. Sobe
docker compose up -d        # ou: make up

# 4. Verifica que pgvector está ativo
docker exec ia-vector-db psql -U admin -d vector_db -c "\dx"
# ou: make check
```

Saída esperada (resumo):

```
                                  List of installed extensions
   Name    | Version |   Schema   |                     Description
-----------+---------+------------+-------------------------------------------------------
 btree_gin | 1.3     | public     | support for indexing common datatypes in GIN
 pg_trgm   | 1.6     | public     | text similarity measurement and index searching
 plpgsql   | 1.0     | pg_catalog | PL/pgSQL procedural language
 uuid-ossp | 1.1     | public     | generate universally unique identifiers (UUIDs)
 vector    | 0.7.x   | public     | vector data type and ivfflat and hnsw access methods
```

### Derrubar

```bash
docker compose down          # preserva o volume (dados continuam lá)
docker compose down -v       # apaga TUDO (volume incluso) — re-executa init.sql na próxima subida
# ou: make down  /  make reset
```

---

## 🔐 Credenciais padrão

| Item | Valor |
|---|---|
| Host | `localhost` |
| Porta | `5432` (configurável via `POSTGRES_PORT`) |
| Usuário | `admin` |
| Senha | `senha123` |
| Banco | `vector_db` |
| Container | `ia-vector-db` |

> **Troque a senha em qualquer ambiente real.** Copie `.env.example` para `.env` e edite — o `.env` está no `.gitignore`.

---

## 🧪 Smoke test — validar busca por similaridade

A tabela `demo_vectors` foi populada com 5 cores RGB representadas como `vector(3)`. Vamos pedir as 3 cores **mais próximas do vermelho puro** `[1, 0, 0]`:

```bash
make smoke
# ou:
docker exec ia-vector-db psql -U admin -d vector_db -c \
  "SELECT label, embedding <=> '[1,0,0]' AS distancia
   FROM demo_vectors
   ORDER BY embedding <=> '[1,0,0]' LIMIT 3;"
```

Saída esperada:

```
  label   |     distancia
----------+--------------------
 vermelho |                  0
 roxo     | 0.1339745962155614
 amarelo  | 0.1339745962155614
```

O operador `<=>` é **cosine distance** do pgvector. Outras opções: `<->` (euclidiana), `<#>` (negative inner product).

---

## 🗄️ Schema entregue

```text
rag.documents (id UUID, title, source_uri, mime_type, metadata JSONB)
rag.chunks    (id UUID, document_id FK, chunk_index, content, embedding vector(1536))
              └── índice IVFFlat cosine (lists=100) em embedding
public.demo_vectors (id, label, embedding vector(3))   ← smoke test
```

Dimensão **1536** = padrão das APIs OpenAI (`text-embedding-3-small`, `ada-002`). Trocar para 768 (BGE, MiniLM) ou 3072 (`text-embedding-3-large`) é alterar a coluna e recriar o índice.

---

## 🏛️ Conexão com a teoria (Aula 15)

| Conceito da disciplina | Como aparece neste stack |
|---|---|
| **12-Factor — III. Config** | Credenciais via `.env`, nunca em código (`docker-compose.yml` lê `${POSTGRES_USER}` etc.) |
| **12-Factor — IV. Backing services** | O banco é um *attached resource*: a aplicação consumidora trata Postgres como recurso plugável via URL |
| **12-Factor — VI. Processes (stateless)** | O *container* é stateless; estado vive no **volume** `pg_data`, isolado e descartável independentemente |
| **12-Factor — X. Dev/prod parity** | Mesma imagem `pgvector/pgvector:pg16` roda local e em prod — zero divergência |
| **PaaS / IaaS / SaaS** | Este repo entrega **PaaS auto-hospedado** (Docker) — mesma interface lógica do RDS/Cloud SQL gerenciado, sem o lock-in |
| **Bounded Context (DDD)** | Schema `rag` isola o contexto de retrieval do `public`; tabelas, índices e migrações desse contexto vivem juntas |
| **Cloud Native** | Imagem versionada, healthcheck, restart policy, IaC declarativo via Compose, network isolada |

---

## 🐛 Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `Bind for 0.0.0.0:5432 failed: port is already allocated` | PostgreSQL local rodando | `POSTGRES_PORT=5433 docker compose up -d` ou ajustar no `.env` |
| `ERROR: extension "vector" is not available` | Imagem errada (`postgres:latest` não tem pgvector) | Confirme `image: pgvector/pgvector:pg16` no compose |
| `init.sql` não rodou após mudança | Compose só executa `/docker-entrypoint-initdb.d` em PGDATA **vazio** | `make reset` (ou `docker compose down -v && docker compose up -d`) |
| `FATAL: the database system is starting up` | Banco ainda subindo | Aguardar o healthcheck — `make up` já espera por você |
| `permission denied` no volume (Linux SELinux) | Contexto do SELinux | Adicionar `:Z` ao bind mount do `init.sql` |

---

## 📁 Estrutura

```text
pgvector-rag-stack/
├── README.md
├── docker-compose.yml      # serviço pgvector-db com healthcheck e .env
├── init.sql                # bootstrap: extension + schema rag + smoke data
├── .env.example            # template de configuração 12-Factor
├── .gitignore
└── Makefile                # atalhos: up, down, reset, psql, check, smoke
```

---

## 📚 Referências

- [pgvector — repositório oficial](https://github.com/pgvector/pgvector)
- [A Guide to Embeddings and pgvector — dev.to/googleai](https://dev.to/googleai/a-guide-to-embeddings-and-pgvector-df0)
- [Introduction to RAG and Vector Database — Medium](https://medium.com/@sachinsoni600517/introduction-to-rag-retrieval-augmented-generation-and-vector-database-b593e8eb6a94)
- [The Twelve-Factor App](https://12factor.net/)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)

---

## ✅ Checklist de entrega (APS 16)

- [x] Imagem `pgvector/pgvector:pg16`
- [x] Porta `5432:5432` (configurável)
- [x] `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` definidos
- [x] Volume mapeado em `/var/lib/postgresql/data`
- [x] `init.sql` mapeado em `/docker-entrypoint-initdb.d/`
- [x] `CREATE EXTENSION IF NOT EXISTS vector;` em `init.sql`
- [x] Tabela de exemplo com coluna `vector`
- [x] README com comando de subir e derrubar
- [x] README com credenciais padrão
