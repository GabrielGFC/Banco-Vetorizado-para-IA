-- =============================================================================
-- init.sql - Bootstrap do banco vetorizado para IA / RAG
-- Executado UMA UNICA VEZ na primeira subida do container (PGDATA vazio).
-- Para re-executar: docker compose down -v && docker compose up -d
-- Autor: Gabriel Fernandes Carvalho (2320142)
-- =============================================================================

-- 1) Habilita a extensao pgvector (matematica vetorial dentro do Postgres)
CREATE EXTENSION IF NOT EXISTS vector;

-- Extensoes auxiliares uteis para um stack RAG real
CREATE EXTENSION IF NOT EXISTS pg_trgm;          -- busca textual fuzzy
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- IDs sem coordenacao
CREATE EXTENSION IF NOT EXISTS btree_gin;        -- indices compostos

-- =============================================================================
-- 2) Schema de dominio - separado do public para boa pratica
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS rag;

-- -----------------------------------------------------------------------------
-- Tabela: rag.documents
-- Documentos-fonte que serao quebrados em chunks e indexados vetorialmente.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rag.documents (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title        VARCHAR(500) NOT NULL,
    source_uri   TEXT,
    mime_type    VARCHAR(100) DEFAULT 'text/plain',
    metadata     JSONB DEFAULT '{}'::jsonb,
    created_at   TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_documents_metadata
    ON rag.documents USING GIN (metadata);

-- -----------------------------------------------------------------------------
-- Tabela: rag.chunks
-- Cada documento e fatiado em chunks; cada chunk tem seu proprio embedding.
-- Dimensao 1536 = padrao OpenAI text-embedding-3-small / ada-002.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rag.chunks (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id  UUID NOT NULL REFERENCES rag.documents(id) ON DELETE CASCADE,
    chunk_index  INTEGER NOT NULL,
    content      TEXT NOT NULL,
    token_count  INTEGER,
    embedding    vector(1536),
    created_at   TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (document_id, chunk_index)
);

-- Indice IVFFlat para similaridade por cosseno (padrao de fato em RAG).
-- 'lists = 100' e bom para ate ~1M de vetores; reavaliar acima disso.
CREATE INDEX IF NOT EXISTS idx_chunks_embedding_cosine
    ON rag.chunks
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Indice auxiliar para filtros por documento
CREATE INDEX IF NOT EXISTS idx_chunks_document_id
    ON rag.chunks (document_id);

-- =============================================================================
-- 3) Dados de smoke test - permite validar imediatamente que tudo funciona
--    Vetor minusculo (3 dimensoes) na tabela 'public.demo_vectors'
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.demo_vectors (
    id        SERIAL PRIMARY KEY,
    label     TEXT NOT NULL,
    embedding vector(3) NOT NULL
);

INSERT INTO public.demo_vectors (label, embedding) VALUES
    ('vermelho',  '[1, 0, 0]'),
    ('verde',     '[0, 1, 0]'),
    ('azul',      '[0, 0, 1]'),
    ('roxo',      '[0.5, 0, 0.5]'),
    ('amarelo',   '[0.5, 0.5, 0]')
ON CONFLICT DO NOTHING;

-- =============================================================================
-- 4) Sanidade
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'pgvector-rag-stack inicializado com sucesso';
    RAISE NOTICE 'Extensao vector: ATIVA';
    RAISE NOTICE 'Schema rag criado (documents + chunks com vector(1536))';
    RAISE NOTICE 'Tabela demo_vectors populada com 5 cores RGB';
    RAISE NOTICE 'Smoke test: SELECT label FROM demo_vectors';
    RAISE NOTICE '             ORDER BY embedding <=> ''[1,0,0]'' LIMIT 3;';
    RAISE NOTICE '============================================================';
END $$;
