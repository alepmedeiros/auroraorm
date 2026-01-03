unit Aurora.Test.DAO;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Data.DB,
  AuroraConfig,
  AuroraDAO,
  AuroraMock.Query,
  Entities.User,
  Entities.Order,
  Entities.Profile;

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

    [Test]
    procedure FindWhere_OneToMany_ReturnsChildList;

    [Test]
    procedure FindOneWhere_OneToOne_ReturnsProfile;
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

procedure TAuroraDAOTests.FindWhere_OneToMany_ReturnsChildList;
var
  DAO: iAuroraDAO<TOrder>;
  L: TObjectList<TOrder>;
begin
  FQuery.ResetDataSet;
  FQuery.DefineField('id', ftInteger);
  FQuery.DefineField('user_id', ftInteger);
  FQuery.DefineField('total', ftFloat);
  FQuery.AppendRow([1, 1, 100.0]);
  FQuery.AppendRow([2, 1, 50.0]);
  FQuery.AppendRow([3, 2, 25.0]);

  DAO := TAuroraDAO<TOrder>.NewAurora(FQuery);
  L := DAO.FindWhere('user_id', 1);
  try
    Assert.IsNotNull(L);
    Assert.AreEqual(2, L.Count);
    Assert.AreEqual(1, L[0].UserId);
    Assert.AreEqual(1, L[0].Id);
    Assert.AreEqual(1, L[1].UserId);
    Assert.AreEqual(2, L[1].Id);
  finally
    L.Free;
  end;
end;

procedure TAuroraDAOTests.FindOneWhere_OneToOne_ReturnsProfile;
var
  DAO: iAuroraDAO<TProfile>;
  P: TProfile;
begin
  FQuery.ResetDataSet;
  FQuery.DefineField('id', ftInteger);
  FQuery.DefineField('user_id', ftInteger);
  FQuery.DefineField('bio', ftString);
  FQuery.AppendRow([10, 1, 'bio alice']);

  DAO := TAuroraDAO<TProfile>.NewAurora(FQuery);
  P := DAO.FindOneWhere('user_id', 1);
  try
    Assert.IsNotNull(P);
    Assert.AreEqual(10, P.Id);
    Assert.AreEqual(1, P.UserId);
    Assert.AreEqual('bio alice', P.Bio);
  finally
    P.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAuroraDAOTests);

end.
