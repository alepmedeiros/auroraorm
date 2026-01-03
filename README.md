# AuroraORM
![AuroraORM](public/logo.png)
ORM leve e moderno para aplicações Delphi, com foco em produtividade e segurança.

AuroraORM acelera implementações de CRUD e consultas usando atributos para mapear entidades, RTTI para gerar SQL de forma segura e integração nativa com FireDAC. Suporta PostgreSQL e SQLite por meio de um dialeto configurável.

Compatibilidade: FireDAC (homologado), Delphi RAD Studio 10+.

Entidade do Banco de Dados Mapeada

```delphi
uses
  AuroraAttributes;

Type
  [Tabela('PEDIDO')]
  TPEDIDO = class
  private
    FID: Integer;
    FCLIENTE: String;
    FDATAPEDIDO: TDatetime;
    FVALORTOTAL: Currency;
    procedure SetID(const Value: Integer);
    procedure SetCLIENTE(const Value: String);
    procedure SetDATAPEDIDO(const Value: TDatetime);
    procedure SetVALORTOTAL(const Value: Currency);
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Campo('ID'), Pk, AutoInc]
    property ID: Integer read FID write SetID;
    [Campo('NOME')]
    property CLIENTE: String read FCLIENTE write SetCLIENTE;
    [Campo('DATA')]
    property DATAPEDIDO: TDatetime read FDATAPEDIDO write SetDATAPEDIDO;
    [Campo('VALOR')]
    property VALORTOTAL: Currency read FVALORTOTAL write SetVALORTOTAL;
  end;
```

Obs.: Em casos como o "Campo('ID')" a anotação é opcional, pois a `property` tem o mesmo nome do campo no banco de dados.

## Atributos
`Tabela`  - Informa o Nome da Tabela no Banco em que a Classe faz o mapeamento.

`Campo`   - Informa o Nome do Campo no Banco de Dados em que a property está fazendo Referência.

`PK`      - Informa se o Campo é PrimaryKey.

`FK`      - Informa se o Campo é ForeignKey.

`NotNull` - Informa se o Campo é NotNull.

`Ignore`  - Ignorar o Campo nas Operações de CRUD.

`AutoInc` - Informa se o Campo é AutoIncremento.

`NumberOnly` - Informa se o Campo deve aceitar somente números.

`Display` - Informa a descrição que deve aparecer no título de grids.

`Format`  - Informa o formato que o campo deve ter, coisas como (tamanho, precisão, máscara e range).

# Funcionalidades

- Mapeamento por atributos (`Tabela`, `Campo`, `PK`, `FK`, `Ignore`, `AutoInc`, `NotNull`, `NumberOnly`, `Blob`, `Email`, `JsonIgnore`, `JsonCampo`, `Display`, `Format`).
- DAO genérico com CRUD, seleção de listas e último registro, integração com `TDataSource` e `TFDConnection` via `AuroraQueryFiredac`.
- Builder SQL (`AuroraSQL`) para gerar `INSERT/UPDATE/DELETE/SELECT` com partes (`Fields`, `Where`, `OrderBy`, `GroupBy`, `Join`).
- RTTI utilitária (`AuroraRTTI`) para mapear `DataSet` ↔ entidades, gerar listas de campos, cláusulas de `UPDATE` e `WHERE` automáticas.
- Serialização JSON nativa (`AuroraJSON`) com controle por atributos (`JsonIgnore`, `JsonCampo`) e opções para nulidade e `AutoInc`.
- Validação por atributos (`AuroraValidator`) com regras `NotNull`, `NumberOnly`, `Email`, `Format`.
- Migrações simples (`Aurora.Migrations`) com scripts SQL por dialeto e execução transacional.


## Instalação
- Adicione ao Library Path o caminho do AuroraORM.
- Alternativamente, instale via [Boss](https://github.com/HashLoad/boss) conforme `boss.json` do repositório.

## Uses necessárias
- `AuroraInterface`
- `AuroraDAO`
- `AuroraAttributes`
- `AuroraQueryFiredac`
- `AuroraConfig`
- `AuroraRTTI`
- `AuroraSQL`
- `AuroraJSON`
- `AuroraValidator`
- `Aurora.Migrations`

## Inicialização

```delphi
var
  Conn: iAuroraQuery;
  DAOPedido: iAuroraDAO<TPEDIDO>;
begin
  TAuroraConfig.SetDialect(dbPostgreSQL); // ou dbSQLite
  TAuroraConfig.SetSchema('public');      // opcional (PostgreSQL)
  TAuroraConfig.UseSchemaPrefix(True);

  Conn := TAuroraQueryFiredac.New(FDConnection1);
  DAOPedido := TAuroraDAO<TPEDIDO>
                  .NewAurora(Conn)
                  .DataSource(DataSource1);
end;
```

`Conn`      - Instancia `iAuroraQuery` com um `TFDConnection`.

`DAOPedido` - Instancia o DAO para a entidade mapeada `TPEDIDO`.

`DataSource`- Liga o `DataSet` interno ao `TDataSource` para exibição em componentes visuais.



## Uso headless

Para sistemas sem camada visual ou quando você prefere separar completamente UI de persistência, utilize entidades puras e o DAO com uma conexão FireDAC, sem usar `DataSource` ou `BindForm`.

Exemplo mínimo (console):
```delphi
var
  Conn: iAuroraQuery;
  DAOUser: iAuroraDAO<TUser>;
  U: TUser;
begin
  TAuroraConfig.SetDialect(dbSQLite);
  Conn := TAuroraQueryFiredac.New(FDConnection1);

  DAOUser := TAuroraDAO<TUser>.NewAurora(Conn);
  U := TUser.Create;
  try
    U.Name := 'Alice';
    U.Email := 'alice@example.com';
    DAOUser.Insert(U);
  finally
    U.Free;
  end;
end;
```
Recomendado para aplicações em camadas e testes automatizados.


 

## Insert com objeto
```delphi
var
  Pedido : TPEDIDO;
begin
  Pedido := TPEDIDO.Create;
  try
    Pedido.ID := StrToInt(Edit2.Text);
    Pedido.CLIENTE := Edit1.Text;
    Pedido.DATAPEDIDO := now;
    Pedido.VALORTOTAL := StrToCurr(Edit3.Text);
    DAOPedido.Insert(Pedido);
  finally
    Pedido.Free;
  end;
end;
```

## Validação por atributos
```delphi
var
  Cliente: TCliente;
  Erros: TList<TAuroraValidationError>;
begin
  Cliente := TCliente.Create;
  try
    Erros := TAuroraValidator.Validate<TCliente>(Cliente);
    if Erros.Count = 0 then
      TAuroraDAO<TCliente>.NewAurora(Conn).Insert(Cliente);
  finally
    Erros.Free;
    Cliente.Free;
  end;
end;
```

 

## Update com objeto
```delphi
var
  Pedido : TPEDIDO;
begin
  Pedido := TPEDIDO.Create;
  try
    Pedido.ID := StrToInt(Edit2.Text);
    Pedido.CLIENTE := Edit1.Text;
    Pedido.DATAPEDIDO := now;
    Pedido.VALORTOTAL := StrToCurr(Edit3.Text);
    DAOPedido.Update(Pedido);
  finally
    Pedido.Free;
  end;
end;
```

## Update validado
```delphi
var
  Cliente: TCliente;
  Erros: TList<TAuroraValidationError>;
begin
  Cliente := TCliente.Create;
  try
    Erros := TAuroraValidator.Validate<TCliente>(Cliente);
    if Erros.Count = 0 then
      TAuroraDAO<TCliente>.NewAurora(Conn).Update(Cliente);
  finally
    Erros.Free;
    Cliente.Free;
  end;
end;
```

 

## Delete com objeto
```delphi
 var
  Pedido : TPEDIDO;
begin
  Pedido := TPEDIDO.Create;
  try
    Pedido.ID := StrToInt(Edit2.Text);
    DAOPedido.Delete(Pedido);
  finally
    Pedido.Free;
  end;
end;
```

## Select
Você pode executar desde operações simples para trazer todos os dados da tabela até filtros avançados e joins.
```delphi
  DAOPedido.Find;
```

Exemplo de composição com `SQL` (Fields/Join/Where/OrderBy/GroupBy):
```delphi
begin
  DAOPedido
    .SQL
      .Fields('CLIENTE, DATA, VALOR')
      .Join('INNER JOIN CLIENTE ON CLIENTE.ID = PEDIDO.CLIENTE')
      .Where('VALOR > :VALOR_MIN')
      .OrderBy('ID DESC')
      .GroupBy('CLIENTE')
    .&End
  .Find;
end;
```

Você também pode retornar uma lista de objetos para trabalhar manualmente:
```delphi
var
  Pedidos : TObjectList<TPEDIDO>;
  Pedido : TPEDIDO;
begin
  Pedidos := TObjectList<TPEDIDO>.Create;
  DAOPedido.Find(Pedidos);
  try
    for Pedido in Pedidos do
    begin
      Memo1.Lines.Add(Pedido.CLIENTE + DateToStr(Pedido.DATAPEDIDO));
    end;
  finally
    Pedidos.Free;
  end;
end;
```

## Testes automatizados (DUnitX) com mocks

Use `TAuroraMockQuery` (implementa `iAuroraQuery`) para simular `Params`, `SQL` e `TFDMemTable` em memória.

Estrutura sugerida:
- `Tests/AuroraORM.Tests/AuroraMock.Query.pas`: mock de `iAuroraQuery`.
- `Tests/AuroraORM.Tests/Aurora.Test.DAO.pas`: testes de DAO usando o mock.
- `Tests/AuroraORM.Tests/AuroraORM.Tests.dpr`: projeto console DUnitX.

Coberturas recomendadas:
- SQL parametrizado (sem valores literais).
- WHERE com parâmetros nomeados.
- Dialeto respeitado (ex.: `LIMIT 1` para SQLite em `LastRecord`).
- Conversão de `DataSet` em entidade via RTTI.

Execução:
1. Abrir `Tests/AuroraORM.Tests/AuroraORM.Tests.dpr` no Delphi.
2. Compilar e rodar.

## Comunidade e suporte
Para dúvidas e suporte, utilize Issues e Discussions do repositório AuroraORM.

## Observabilidade e boas práticas
Logs e monitoramento serão documentados na wiki do projeto. Exemplos de uso de `FDMonitor` podem ser adicionados em breve.

## Migrações
AuroraORM inclui um runner simples baseado em arquivos SQL.

- Local: `Sample/AuroraHeadless/migrations/<dialeto>/` (ex.: `sqlite`, `postgres`).
- Convenção de nome: `YYYYMMDDHHMM_descricao.sql`. O número no início é a versão aplicada e determina a ordem.
- Execução: cada arquivo é aplicado dentro de transação (commit/rollback); separação simples por `;`.
- Limitações: não há auto-migração por mudanças nas entidades. Alterar atributos/classe NÃO altera schema automaticamente.

### Como adicionar um campo/tabela
- Crie um novo arquivo `.sql` no diretório do dialeto com um prefixo de versão maior que os anteriores.
- Escreva os comandos `ALTER TABLE`/`CREATE TABLE` conforme o banco.
- Mantenha suas entidades (`[Campo]`, `[Tabela]`, `[PK]`, etc.) em sincronia com o schema.

### Como executar
```delphi
var Runner: TAuroraMigrationRunner;
    Q: iAuroraQuery;
begin
  TAuroraConfig.SetDialect(dbSQLite); // ou dbPostgreSQL
  Q := TAuroraQueryFiredac.New(FDConnection1);
  Runner := TAuroraMigrationRunner.Create(Q, 'Sample/AuroraHeadless/migrations/sqlite');
  Runner.ApplyPending;
end;
```

Também disponível no exemplo `Sample/APIConsole` via comando `migrate.sqlite`. Seeds de dados exemplo:
- `202511121210_seed_initial.sql` para SQLite/Postgres (insere `users`, `orders`, `profiles`).

### Modo Auto-Migration (experimental)
Permite criar tabelas ausentes e adicionar colunas com base nas entidades mapeadas.

- API: `TAuroraSchemaSync.Ensure<T>(Query)` cria a tabela de `T` se não existir e adiciona colunas ausentes.
- Suporta `SQLite` e `PostgreSQL` com mapeamento básico de tipos.
- Não altera tipos existentes nem remove colunas; alterações complexas devem ser feitas via scripts.
- Respeita atributos: `NotNull`, `Format` (tamanho em `VARCHAR`), `AutoInc` no `PK`, `FK(tabela,coluna)` em colunas, `Unique`, `Index(nome?)`.
- Observações: SQLite não adiciona `NOT NULL`/FK em `ADD COLUMN`; use scripts para alterações complexas.

Exemplo:
```delphi
TAuroraConfig.SetDialect(dbSQLite);
Q := TAuroraQueryFiredac.New(FDConnection1);
TAuroraSchemaSync.Ensure<TUser>(Q);
TAuroraSchemaSync.Ensure<TOrder>(Q);
TAuroraSchemaSync.Ensure<TProfile>(Q);
```

No `Sample/APIConsole`, use `migrate.auto` para rodar o auto-migration para as entidades do exemplo.

## Roadmap
- Ampliação de suporte a relacionamentos com carregamento automático.
- Extensão do `Update/Delete/Find` com construção dinâmica completa.
- Integração opcional com GBJson via diretiva.

## Relacionamentos
- 1:1: use `FindOneWhere` ou `LoadOne<R>` com chave local/estrangeira.
```delphi
var P: TProfile;
begin
  P := TAuroraDAO<TProfile>.NewAurora(Conn).FindOneWhere('user_id', 1);
end;
```

- 1:N: use `FindWhere` ou `LoadMany<R>` para lista por FK.
```delphi
var L: TObjectList<TOrder>;
begin
  L := TAuroraDAO<TOrder>.NewAurora(Conn).FindWhere('user_id', 1);
end;
```

Carregamento explícito a partir da entidade com helpers:
```delphi
var
  U: TUser;
  P: TProfile;
  Orders: TObjectList<TOrder>;
  DAOUser: iAuroraDAO<TUser>;
begin
  DAOUser := TAuroraDAO<TUser>.NewAurora(Conn);
  U := DAOUser.FindOneWhere('id', 1);
  DAOUser.LoadOne<TProfile>(U, 'id', 'user_id', P);
  DAOUser.LoadMany<TOrder>(U, 'id', 'user_id', Orders);
end;
```

## Atributos (detalhado)
- `Tabela(nome)`: define o nome da tabela.
- `Campo(nome, tipo?)`: define o nome do campo; opcionalmente informa tipo.
- `PK`: marca a chave primária.
- `FK`: marca chave estrangeira (indicativo; sem carregamento automático ainda).
- `Ignore`: exclui campo de operações.
- `AutoInc`: exclui de `INSERT` e da serialização por padrão.
- `NotNull`: validação de não nulo/vazio.
- `NumberOnly`: validação de dígitos.
- `Blob`: marca conteúdo binário.
- `Email`: valida e-mail.
- `JsonIgnore`: oculta do JSON.
- `JsonCampo(nome)`: renomeia campo no JSON.
- `Display(texto)`: sugere rótulo amigável.
- `Format(size|mask|range)`: validação de tamanho/máscara.

## Interfaces e classes
- `iAuroraQuery`: `SQL: TStrings`, `Params: TParams`, `ExecSQL`, `Open`.
- `iAuroraDAO<T>`: `Insert/Update/Delete`, `LastID/LastRecord`, `Find*`, `DataSource`, `SQL`.
- `iAuroraDAOSQLAttribute<T>`: `Fields/Where/OrderBy/GroupBy/Join`, `Clear`, `End`.
- `iAuroraRTTI<T>`: `TableName/ClassName/Fields/FieldsInsert/Param/Update/Where`, `PrimaryKey`, `DataSetToEntity(List)`.
- `iAuroraSQL<T>`: `Insert/Update/Delete/Select/SelectId/LastID/LastRecord`.
- `TAuroraJSON`: `ToJSON/ToJSONArray/FromJSON/FromJSONArray` e variantes com opções.
- `TAuroraValidator`: `Validate<T>` retorna `TList<TAuroraValidationError>`.

## Exemplo AuroraSQL
```delphi
var S: string;
begin
  TAuroraSQL<TPEDIDO>.New
    .Where('CLIENTE = :CLIENTE')
    .OrderBy('ID DESC')
    .Select(S);
  Conn.SQL.Text := S;
  Conn.Params.ParamByName('CLIENTE').AsString := 'Alice';
  Conn.Open;
end;
```
Veja também `Sample/SQLDemo` para uma demonstração completa de geração de queries.

## JSON
```delphi
var
  P: TPEDIDO;
  J: string;
begin
  J := TAuroraJSON.ToJSON<TPEDIDO>(P);
  P := TAuroraJSON.FromJSON<TPEDIDO>(J);
end;
```
Veja também `Sample/JSONDemo` para uso de opções avançadas.

## Validação
```delphi
var Erros: TList<TAuroraValidationError>;
begin
  Erros := TAuroraValidator.Validate<TPEDIDO>(Pedido);
  if Erros.Count > 0 then
    // tratar mensagens
end;
```
Veja também `Sample/ValidationDemo` para validações com atributos.

## DateTime
- Mapeamento: `TDateTime` em Delphi é um `Double`. Declare nas entidades `property X: TDateTime` com `[Campo('...')]`.
- RTTI: `AuroraRTTI` mapeia `tkFloat` para `ftDateTime` em `GetDataType`, permitindo parametrização correta.
- DAO: em mapeamentos `DataSet` → entidade, `tkFloat` usa `Field.AsFloat`, compatível com `TDateTime` do FireDAC.
- Dialetos:
  - SQLite: auto-migration cria colunas datetime como `REAL` (double). Alternativamente, scripts podem usar `TEXT`/ISO 8601.
  - PostgreSQL: usa `TIMESTAMP` (sem timezone) na auto-migration. Para `TIMESTAMPTZ`, adote scripts de migração.
- Timezone: recomende operar em UTC no servidor e converter na camada de UI, evitando ambiguidade. Ajuste `TimeZone` no servidor conforme necessidade.
- Boas práticas:
  - Use parâmetros nomeados (`:created_at`) e evite concatenar strings de data.
  - Padronize serialização JSON com ISO 8601 quando necessário; `TAuroraJSON` suporta strings e números.
