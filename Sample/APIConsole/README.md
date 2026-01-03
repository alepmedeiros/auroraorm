# AuroraAPIConsole

Aplicativo console que simula uma API, usando AuroraORM com mock de query (`iAuroraQuery`) para demonstrar:
- CRUD básico
- Relacionamentos 1:1 (`Profile` por `user_id`) e 1:N (`Orders` por `user_id`)
- Serialização/deserialização JSON e JSONArray
- Uso real com FireDAC (SQLite) e migrações

## Rodando
- Compile e execute `AuroraAPIConsole.dpr`.
- Comandos suportados:
  - `migrate.sqlite`
  - `user.create {"name":"Alice","email":"alice@example.com"}`
  - `user.get 1`
  - `user.update {"id":1,"name":"Alice","email":"alice@new.com"}`
  - `orders.create {"user_id":1,"total":100.00}`
  - `orders.list 1`
  - `profile.upsert {"user_id":1,"bio":"bio text"}`

## Arquivos
- `AuroraAPIConsole.dpr`: fonte principal.
