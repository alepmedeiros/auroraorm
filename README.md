# AuroraORM
![AuroraORM](public/logo.png)
ORM leve para Aplicações Delphi

O AuroraORM nasce a partir do SimpleORM, reaproveitando o código e evoluindo com uma nova camada de nomes (Aurora*), segurança e convenções. O objetivo é facilitar suas implementações de CRUD, agilizando mais de 80% do processo de desenvolvimento, com foco em FireDAC e bancos PostgreSQL/SQLite.

Homologado exclusivamente para o driver de Conexão FireDAC.

Nota: todo conteúdo antigo relacionado ao "SimpleORM" foi movido para a pasta `legacy/` e não faz parte do AuroraORM oficial. Consulte `legacy/README.md` se precisar de referência histórica.

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

`Bind` - Informa o Nome do Campo no Banco de Dados ou a `property` que o componente visual está fazendo Referência.

`Display` - Informa a descrição que deve aparecer no título de grids.

`Format`  - Informa o formato que o campo deve ter, coisas como (tamanho, precisão, máscara e range).

# Principais Operações


## Instalação
Basta adicionar ao Library Path o caminho do AuroraORM (em breve via [Boss](https://github.com/HashLoad/boss)). Não é necessário instalar componentes.

## Uses Necessárias

AuroraInterface,

AuroraDAO,

AuroraAttributes,

AuroraQueryFiredac,

AuroraConfig,

Aurora.Migrations

## Inicialização do AuroraORM

```delphi
var
  Conn : iAuroraQuery;
  DAOPedido : iAuroraDAO<TPEDIDO>;
begin
  // Dialeto e schema
  TAuroraConfig.SetDialect(dbPostgreSQL); // ou dbSQLite
  TAuroraConfig.SetSchema('public');      // opcional (PostgreSQL)
  TAuroraConfig.UseSchemaPrefix(True);

  // Conexão FireDAC
  Conn := TAuroraQueryFiredac.New(FDConnection1);
  DAOPedido := TAuroraDAO<TPEDIDO>
                  .NewAurora(Conn)
                  .DataSource(DataSource1)
                  .BindForm(Self);
end;
```

`Conn`      - Instancia a Interface iSimpleQuery passando o componente de conexão que o SimpleORM irá trabalhar.

`DAOPedido` - Instância o DAO para uma Entidade Mapeada, passando a Classe de Mapeamento como Atributo Genérico.

`New`       - Recebe a Interface de Conexão iSimpleQuery.

`DataSource`- Você pode informar um DataSource para que os dados sejam armazenados nele para facilitar seu processo de listagem de dados, podem linkar ao DBGrid para exibição dos mesmos.

`Bind`      - Você pode informar o formulário que deseja que o SimpleORM faça o Bind automatico entre a Classe e os Componentes da tela (Edit, Combo, CheckBox, RadioButton e etc...)

## Uso sem bind visual (Headless / estilo Hibernate)

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
Este estilo é recomendado para aplicações de qualidade de produção, com foco em camadas e testes.


## MAPEAMENTO DO BIND DO FORMULÁRIO
Quando você fizer o mapeamento Bind do Formulário, não precisará ligar manualmente os campos da classe ao Edits, o SimpleORM faz isso automáticamente, basta você realizar o mapeamento correto conforme abaixo.

```delphi
type
  TForm1 = class(TForm)
    [Bind('CLIENTE')]
    Edit1: TEdit;
    [Bind('ID')]
    Edit2: TEdit;
    [Bind('VALORTOTAL')]
    Edit3: TEdit;
    Button2: TButton;
    [Bind('DATAPEDIDO')]
    DateTimePicker1: TDateTimePicker;
```

No atributo Bind de cada campo, você deve informar o nome da Property correspondente na Classe Mapeada do banco de dados ou o nome do campo na tabela do banco de dados, ATENÇÃO de qualquer forma a Classe deve estar mapeada corretamente.

## INSERT COM BIND

```delphi
begin
  DAOPedido.Insert;
end;
```

## INSERT COM OBJETO
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

## INSERT COM OBJETO HERDADO DE `TSimpleEntity` E COM VALIDAÇÃO
```delphi
var
  Cliente: TCliente;
begin
  Cliente := TCliente.Create;
  try
    // PEGA OS VALORES DA TELA E PREENCHE O OBJETO VIA BIND
    Cliente.Parse(Self); 

    // VALIDA SEGUNDO ANOTAÇÕES DO OBJETO
    TSimpleValidator.Validate(Cliente); 
    
    // INSERE "CLIENTE" NO BANCO DE DADOS
    DAOCliente.Insert(Cliente);
  finally
    Cliente.Free;
  end;
end;
```

## UPDATE COM BIND
```delphi
begin
  DAOPedido.Update;
end;
```

## UPDATE COM OBJETO
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

## UPDATE COM OBJETO HERDADO DE `TSimpleEntity` E COM VALIDAÇÃO
```delphi
var
  Cliente: TCliente;
begin
  Cliente := TCliente.Create;
  try
    Cliente.Parse(Self); 
    TSimpleValidator.Validate(Cliente); 
    DAOCliente.Update(Cliente);
  finally
    Cliente.Free;
  end;
end;
```

## DELETE COM BIND
```delphi
begin
  DAOPedido.Delete;
end;
```

## DELETE COM OBJETO
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

## SELECT 
Você pode executar desde operações simples como trazer todos os dados da tabela, como filtrar campos e outras instruções SQL, 

executando a instrução abaixo você retornará todos os dados da tabela
```delphi
  DAOPedido.Find;
```

Abaixo um exemplo de todas as operações possíveis no AuroraORM
```delphi
begin
  DAOPedido
    .SQL
      .Fields('Informe os Campos que deseja trazer separados por virgula')
      .Join('Informe a Instrução Join que desejar ex INNER JOIN CLIENTE ON CLIENTE.ID = PRODUTO.CLIENTE')
      .Where('Coloque a Clausula Where que desejar ex: CODIGO = 1')
      .OrderBy('Informe o nome do Campo que deseja ordenar ex: ID')
      .GroupBy('Informe os campos que deseja agrupar separados por virgula')
    .&End
  .Find;
end;
```

Você também pode retornar uma Lista de Objetos para trabalhar com ela manualmente, abaixo um exemplo de como trazer a lista e trabalhar com ela exibindo todos os valores em um Memo
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

Para garantir qualidade sem depender de bancos de dados em tempo de teste, configure casos de teste com DUnitX usando um mock de `iSimpleQuery` que simula `Params`, `SQL` e um `TFDMemTable` em memória.

Estrutura sugerida:
- `Tests/AuroraORM.Tests/AuroraMock.SimpleQuery.pas`: implementação mock de `iSimpleQuery`.
- `Tests/AuroraORM.Tests/Aurora.Test.DAO.pas`: testes de DAO (INSERT/UPDATE/DELETE/SELECT) usando o mock.
- `Tests/AuroraORM.Tests/AuroraORM.Tests.dpr`: projeto console do DUnitX.

Exemplo de asserções cobertas:
- SQL parametrizado (sem valores literais no texto do SQL).
- WHERE com parâmetros nomeados.
- Dialeto respeitado (ex.: `LIMIT 1` para SQLite em `LastRecord`).
- Conversão de `DataSet` em entidade via RTTI.

Como executar:
1. Abrir `Tests/AuroraORM.Tests/AuroraORM.Tests.dpr` no Delphi.
2. Compilar e rodar. O runner escreve saída no console e exporta NUnit XML.

Obs.: Os testes não usam base de dados real — todo o processo é mockado para execução determinística e rápida.

## Comunidade e suporte
Para dúvidas e suporte, utilize Issues e Discussions do repositório AuroraORM. Conteúdos antigos de comunidade do SimpleORM foram mantidos apenas em `legacy/` para referência.

## Observabilidade e boas práticas
Logs e monitoramento em AuroraORM serão documentados na wiki do projeto. Configurações antigas do SimpleORM foram movidas para `legacy/`.
