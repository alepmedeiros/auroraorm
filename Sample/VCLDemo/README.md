# VCLDemo

Formulário VCL simples com AuroraORM + FireDAC (SQLite), exibindo lista em `DBGrid` e inserção.

## Como usar
- Configure `FDConnection1` para SQLite (`DriverID=SQLite`, `Database=aurora.db`).
- No código, o `DAOUser` usa `DataSource` para preencher o grid.
- Botão "Load" executa `Find` com `OrderBy`.
- Botão "Insert" insere um registro.

## Arquivos
- `MainForm.pas`: código do formulário.
