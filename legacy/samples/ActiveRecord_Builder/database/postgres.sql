-- SimpleORM ActiveRecord_Builder - PostgreSQL schema for validation
-- Run this script in a PostgreSQL database (e.g., sample_simpleorm)
-- This sample is configured to use the 'simpleorm' schema via FireDAC OnAfterConnect.
-- For clarity, we also create and set the search_path here.

-- Schema setup for the sample
CREATE SCHEMA IF NOT EXISTS simpleorm;
SET search_path TO simpleorm, public;

-- Extensions needed for UUID generation (used by produto.guuid default)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- CLIENTE
CREATE TABLE IF NOT EXISTS cliente (
  id SERIAL PRIMARY KEY,
  nome TEXT,
  telefone TEXT
);

-- PEDIDO
CREATE TABLE IF NOT EXISTS pedido (
  id SERIAL PRIMARY KEY,
  nome TEXT,
  data TIMESTAMP WITHOUT TIME ZONE,
  valor NUMERIC(18,2)
);

-- PRODUTO
CREATE TABLE IF NOT EXISTS produto (
  guuid TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
  codigo TEXT,
  descricao TEXT,
  preco NUMERIC(18,2),
  ncm INTEGER,
  aliquota NUMERIC(10,4),
  st INTEGER,
  status INTEGER,
  dataalteracao TIMESTAMP WITHOUT TIME ZONE
);

-- Sample seed data
INSERT INTO cliente (nome, telefone) VALUES ('Cliente Demo', '+55 11 99999-0000') ON CONFLICT DO NOTHING;
INSERT INTO pedido (nome, data, valor) VALUES ('Cliente Demo', NOW(), 199.90) ON CONFLICT DO NOTHING;
-- For produto, omit guuid to allow default to apply
INSERT INTO produto (codigo, descricao, preco, ncm, aliquota, st, status, dataalteracao)
VALUES ('P001', 'Produto Demo', 9.99, 1234, 0.1200, 0, 1, NOW()) ON CONFLICT DO NOTHING;