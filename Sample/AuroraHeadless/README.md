# AuroraHeadless Sample

Exemplo minimalista (console) usando AuroraORM + FireDAC sem bind visual, com CRUD básico e relacionamentos 1:1 e 1:N.

## Pré-requisitos
- Delphi com FireDAC
- Driver SQLite disponível

## Rodando
1. Compile e execute `AuroraHeadless.dpr`.
2. O programa cria/abre `aurora.db`, insere um usuário de exemplo e lista ordenado por `id desc`.

## Estrutura
- `Entities/User.pas`: Entidade `TUser` mapeada para a tabela `users`.
- `Entities/Order.pas`: Entidade `TOrder` (1:N) ligada a `users` por `user_id`.
- `Entities/Profile.pas`: Entidade `TProfile` (1:1) ligada a `users` por `user_id`.
- `migrations/sqlite/` e `migrations/postgres/`: Scripts `.sql` para criar tabelas/índices, incluindo `orders` e `profiles`.
## Como funciona
1. Dialeto configurado para SQLite:
   ```pascal
   TAuroraConfig.SetDialect(dbSQLite);
   TAuroraConfig.UseSchemaPrefix(False);
   ```
2. Adapter de query com FireDAC:
   ```pascal
   Query := TAuroraQueryFiredac.New(Conn);
   ```
3. DAO e CRUD:
   ```pascal
   DAOUser := TAuroraDAO<TUser>.NewAurora(Query);
   DAOUser.Insert(U);
   DAOUser.SQL.OrderBy('id desc').&End.Find(Users);
   ```

## Ajustando para PostgreSQL
Se quiser apontar para PostgreSQL, ajuste:
- `TAuroraConfig.SetDialect(dbPostgreSQL)`
- `TFDConnection` com driver `PG` e parâmetros de conexão
