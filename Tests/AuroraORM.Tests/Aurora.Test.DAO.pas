unit Aurora.Test.DAO;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Data.DB,
  AuroraConfig,
  AuroraDAO,
  AuroraMock.SimpleQuery,
  Entities.User;

type
  [TestFixture]
  TAuroraDAOTests = class
  private
    FQuery: TAuroraMockQuery;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Insert_MustGenerateParameterizedSQL;

    [Test]
    procedure Delete_WithWhere_IsParameterized;

    [Test]
    procedure LastRecord_SQL_UsesLimit1_ForSQLite;

    [Test]
    procedure FindOneWhere_ReturnsEntity_FromMockedDataSet;
  end;

implementation

uses
  AuroraInterface;

procedure TAuroraDAOTests.Setup;
begin
  // Dialeto padrão para os testes
  TAuroraConfig.Dialect := dbSQLite;
  FQuery := TAuroraMockQuery.Create;
end;

procedure TAuroraDAOTests.Insert_MustGenerateParameterizedSQL;
var
  U: TUser;
  DAO: iAuroraDAO<TUser>;
begin
  U := TUser.Create;
  try
    U.Name := 'Alice';
    U.Email := 'alice@example.com';

    DAO := TAuroraDAO<TUser>.NewAurora(FQuery);
    DAO.Insert(U);

    // Deve gerar SQL com placeholders e não com valores diretos
    Assert.IsTrue(Pos('INSERT INTO users', FQuery.SQL.Text) > 0, 'SQL de insert deve apontar para tabela users');
    Assert.IsTrue(Pos(':', FQuery.SQL.Text) > 0, 'Insert deve ser parametrizado');
    Assert.IsFalse(Pos('alice@example.com', FQuery.SQL.Text) > 0, 'Não deve injetar valores no SQL');

    // Parâmetros devem conter os valores
    Assert.AreEqual('Alice', FQuery.Params.ParamByName('name').AsString);
    Assert.AreEqual('alice@example.com', FQuery.Params.ParamByName('email').AsString);
  finally
    U.Free;
  end;
end;

procedure TAuroraDAOTests.Delete_WithWhere_IsParameterized;
var
  DAO: iAuroraDAO<TUser>;
begin
  DAO := TAuroraDAO<TUser>.NewAurora(FQuery);
  DAO.Delete('email','alice@example.com');

  Assert.IsTrue(Pos('WHERE', UpperCase(FQuery.SQL.Text)) > 0, 'Delete deve conter WHERE');
  Assert.IsTrue(Pos(':email', LowerCase(FQuery.SQL.Text)) > 0, 'Delete deve usar parâmetro :email');
  Assert.AreEqual('alice@example.com', FQuery.Params.ParamByName('email').AsString);
end;

procedure TAuroraDAOTests.LastRecord_SQL_UsesLimit1_ForSQLite;
var
  DAO: iAuroraDAO<TUser>;
begin
  TAuroraConfig.Dialect := dbSQLite;
  DAO := TAuroraDAO<TUser>.NewAurora(FQuery);
  DAO.LastRecord;
  Assert.IsTrue(Pos('limit 1', LowerCase(FQuery.SQL.Text)) > 0, 'SQLite deve usar LIMIT 1');
end;

procedure TAuroraDAOTests.FindOneWhere_ReturnsEntity_FromMockedDataSet;
var
  DAO: iAuroraDAO<TUser>;
  Found: TUser;
begin
  // Prepara dataset mockado
  FQuery.ResetDataSet;
  FQuery.DefineField('id', ftInteger);
  FQuery.DefineField('name', ftString);
  FQuery.DefineField('email', ftString);
  FQuery.AppendRow([1, 'Alice', 'alice@example.com']);

  DAO := TAuroraDAO<TUser>.NewAurora(FQuery);
  Found := DAO.FindOneWhere('email', 'alice@example.com');
  try
    Assert.IsNotNull(Found, 'Deve retornar entidade a partir do dataset');
    Assert.AreEqual(1, Found.Id);
    Assert.AreEqual('Alice', Found.Name);
    Assert.AreEqual('alice@example.com', Found.Email);
  finally
    Found.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAuroraDAOTests);

end.