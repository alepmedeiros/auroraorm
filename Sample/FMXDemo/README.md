# FMXDemo

Aplicativo FMX com AuroraORM, FireDAC (SQLite), exibindo usuários e relações de forma programática.

## Funcionalidades
- Listar usuários e inserir novo
- Carregar relação 1:1 (`Profile`) e 1:N (`Orders`)

## Rodando
- Compile e execute `FMXDemo.dpr`
- O app cria/usa `aurora.db`; execute migrações pelo console `Sample/APIConsole` com `migrate.sqlite` para garantir tabelas (`users`, `orders`, `profiles`).
