# Banco de Dados Vetorizado para IA (PostgreSQL + pgvector)

> **Autor:** Gabriel Fernandes Carvalho — Matrícula **2320142**
> **Disciplina:** Arquitetura de Software — UniEVANGÉLICA 2026.1
> **Atividade:** APS 16 — Aula 15 (Cloud Native, 12-Factor App, IaaS/PaaS/SaaS)
> **Repositório:** https://github.com/GabrielGFC/Banco-Vetorizado-para-IA

## 📋 Descrição

Este repositório contém a infraestrutura **"Plug & Play"** para um banco de dados PostgreSQL com suporte a **embeddings** e **busca semântica** usando a extensão `pgvector`. É o ponto de partida para projetos que utilizam **RAG (Retrieval-Augmented Generation)** com Inteligência Artificial.

O fluxo RAG implementado: (1) texto vira **embedding** de 1536 dimensões, (2) vetor é salvo no banco, (3) na consulta, a IA busca os vetores **matematicamente mais próximos** (cosine / euclidiana / inner product) — o pgvector adiciona ao PostgreSQL a matemática vetorial necessária.

**Diferenciais deste repositório em relação a um setup mínimo:**

- Healthcheck nativo do Compose (espera o Postgres ficar pronto antes de declarar "up")
- Configuração via `.env` (12-Factor — III. Config), com `.env.example` versionado
- Schema dedicado `rag` separando o contexto de retrieval (Bounded Context)
- Tabelas `documents` + `chunks` com FK e índice IVFFlat para cosine
- Dados de smoke test (5 cores RGB em `vector(3)`) para validar similaridade imediatamente
- Extensões auxiliares úteis em RAG: `pg_trgm`, `uuid-ossp`, `btree_gin`
- `Makefile` com atalhos: `up`, `down`, `reset`, `psql`, `check`, `smoke`

## 🚀 Como Usar

### Pré-requisitos

- Docker instalado na sua máquina
- Docker Compose v2 (`docker compose`, sem hífen — Compose v1 com hífen também funciona)

### Subir o Banco de Dados

```bash
# Clone este repositório
git clone https://github.com/GabrielGFC/Banco-Vetorizado-para-IA.git
cd Banco-Vetorizado-para-IA

# (Opcional) personalize credenciais — sem isso usa os defaults
cp .env.example .env

# Suba o banco de dados
docker-compose up -d

# Aguarde 5 segundos para o banco inicializar completamente
sleep 5

# Verifique se a extensão pgvector foi criada
docker exec ia-vector-db psql -U admin -d vector_db -c "\dx"
```

Você deve ver a extensão `vector` listada (junto de `pg_trgm`, `uuid-ossp`, `btree_gin`).

### Conectar ao Banco de Dados

```bash
# Acesse o banco via psql
docker exec -it ia-vector-db psql -U admin -d vector_db

# Smoke test: 3 cores mais próximas do vermelho puro [1,0,0]
SELECT label, embedding <=> '[1,0,0]' AS distancia
FROM demo_vectors
ORDER BY embedding <=> '[1,0,0]'
LIMIT 3;

# Consultar o schema RAG (vazio até você inserir embeddings)
SELECT * FROM rag.documents;
SELECT * FROM rag.chunks;
```

### Derrubar o Banco de Dados

```bash
# Parar e remover containers (preserva o volume — dados continuam)
docker-compose down

# Se quiser remover também os volumes (CUIDADO: deleta os dados!)
docker-compose down -v
```

## 🔧 Configuração

### Credenciais Padrão

- **Usuário:** `admin`
- **Senha:** `senha123` (MUDE ISSO EM PRODUÇÃO! Edite `.env`)
- **Banco de Dados:** `vector_db`
- **Porta:** `5432` (configurável via `POSTGRES_PORT` no `.env`)
- **Host:** `localhost`
- **Container:** `ia-vector-db`

### Arquivo `docker-compose.yml`

O arquivo define:
- **Imagem:** `pgvector/pgvector:pg16` (PostgreSQL 16 com pgvector pré-compilado)
- **Volumes:** Persistência de dados em `pg_data` e injeção do script `init.sql` em `/docker-entrypoint-initdb.d/`
- **Portas:** Mapeamento da porta 5432
- **Healthcheck:** `pg_isready` a cada 10s (Compose só marca "healthy" quando o banco aceita conexões)
- **Limites de recurso:** 1 GB de RAM e 1.5 CPU para não competir com a máquina local
- **Restart policy:** `unless-stopped`
- **Network:** `rag-net` (bridge nomeada)

### Arquivo `init.sql`

Executado automaticamente na primeira inicialização (apenas se PGDATA estiver vazio). Contém:
- Criação da extensão `pgvector` e auxiliares (`pg_trgm`, `uuid-ossp`, `btree_gin`)
- Schema `rag` separando o contexto de retrieval
- Tabela `rag.documents` (metadados das fontes)
- Tabela `rag.chunks` (fatias com `embedding vector(1536)` — padrão OpenAI)
- Índice IVFFlat para cosine similarity
- Tabela `public.demo_vectors` populada com 5 cores RGB para smoke test

## 📚 Próximos Passos

1. **Integrar com sua aplicação:** Use `psycopg2` (Python) ou `pg` (Node.js) com a string `postgresql://admin:senha123@localhost:5432/vector_db`.
2. **Gerar embeddings:** APIs OpenAI (`text-embedding-3-small`, 1536 dims), Hugging Face, ou modelos locais (BGE, MiniLM).
3. **Implementar RAG:** Inserir chunks em `rag.chunks` com seus embeddings e consultar com `ORDER BY embedding <=> '[...]' LIMIT k`.

## 🐛 Troubleshooting

### "Erro: porta 5432 já está em uso"
Você já tem um PostgreSQL rodando. Opções:
- Parar o PostgreSQL existente
- Mudar a porta no `.env`: `POSTGRES_PORT=5433` e subir novamente

### "Erro: extensão vector não encontrada"
Você usou a imagem `postgres:latest` em vez de `pgvector/pgvector:pg16`. Confirme `image: pgvector/pgvector:pg16` no `docker-compose.yml`.

### "Erro: init.sql não foi executado"
O script só roda na **primeira** inicialização (PGDATA vazio). Se você já tinha subido o container antes:
```bash
docker-compose down -v  # Remove volume (apaga dados)
docker-compose up -d    # Re-executa init.sql
```

### "Erro: container sobe mas banco recusa conexão"
Aguarde 5 segundos — o PostgreSQL demora um pouco para inicializar. O healthcheck só vira "healthy" quando o banco aceita conexão (`make up` espera automaticamente).

## 📖 Referências

- [pgvector GitHub](https://github.com/pgvector/pgvector)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)
- [12-Factor App](https://12factor.net/)
- [A Guide to Embeddings and pgvector — dev.to/googleai](https://dev.to/googleai/a-guide-to-embeddings-and-pgvector-df0)
- [Introduction to RAG and Vector Database — Medium](https://medium.com/@sachinsoni600517/introduction-to-rag-retrieval-augmented-generation-and-vector-database-b593e8eb6a94)

## ✅ Checklist

- [x] Docker e Docker Compose instalados
- [x] Repositório clonado (público no GitHub)
- [x] Imagem `pgvector/pgvector:pg16` configurada
- [x] Volume de dados mapeado em `/var/lib/postgresql/data`
- [x] `init.sql` mapeado em `/docker-entrypoint-initdb.d/`
- [x] `docker-compose up -d` sobe o banco sem erros
- [x] Extensão `vector` verificada via `\dx`
- [x] README com comandos `up` e `down` e credenciais padrão
- [ ] Link do repositório submetido no AVA
- [ ] APS 16 respondida no AVA

---

**Criado para:** APS 16 — Arquitetura de Software (Ciclo 03)
**Disciplina:** Arquitetura de Software
**Instituição:** UniEVANGÉLICA
**Período:** 2026.1
