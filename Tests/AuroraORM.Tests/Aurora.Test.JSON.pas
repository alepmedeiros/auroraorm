unit Aurora.Test.JSON;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  AuroraJSON,
  Entities.User;

type
  [TestFixture]
  TAuroraJSONTests = class
  public
    [Test]
    procedure ToJSON_MustUseCampoNames_AndValuesMatch;

    [Test]
    procedure FromJSON_MustPopulateEntityProperties;

    [Test]
    procedure ToJSONArray_MustSerializeListWithCampoNames;

    [Test]
    procedure FromJSONArray_MustDeserializeListOfEntities;
  end;

implementation

procedure TAuroraJSONTests.ToJSON_MustUseCampoNames_AndValuesMatch;
var
  U: TUser;
  S: string;
  V: TJSONValue;
  O: TJSONObject;
begin
  U := TUser.Create;
  try
    U.Id := 1;
    U.Name := 'Alice';
    U.Email := 'alice@example.com';

    S := TAuroraJSON.ToJSON<TUser>(U);
    V := TJSONObject.ParseJSONValue(S);
    try
      Assert.IsNotNull(V, 'JSON inválido');
      O := V as TJSONObject;
      Assert.IsNotNull(O, 'Objeto JSON esperado');

      Assert.IsTrue(O.TryGetValue('id', S), 'Campo id deve existir');
      Assert.AreEqual('1', S, 'id deve ser 1');
      Assert.IsTrue(O.TryGetValue('name', S), 'Campo name deve existir');
      Assert.AreEqual('Alice', S);
      Assert.IsTrue(O.TryGetValue('email', S), 'Campo email deve existir');
      Assert.AreEqual('alice@example.com', S);
    finally
      V.Free;
    end;
  finally
    U.Free;
  end;
end;

procedure TAuroraJSONTests.FromJSON_MustPopulateEntityProperties;
var
  U: TUser;
  Json: string;
begin
  Json := '{"id":1,"name":"Alice","email":"alice@example.com"}';
  U := TAuroraJSON.FromJSON<TUser>(Json);
  try
    Assert.IsNotNull(U);
    Assert.AreEqual(1, U.Id);
    Assert.AreEqual('Alice', U.Name);
    Assert.AreEqual('alice@example.com', U.Email);
  finally
    U.Free;
  end;
end;

procedure TAuroraJSONTests.ToJSONArray_MustSerializeListWithCampoNames;
var
  L: TObjectList<TUser>;
  U1, U2: TUser;
  S: string;
  V: TJSONValue;
  A: TJSONArray;
  O: TJSONObject;
  Tmp: string;
begin
  L := TObjectList<TUser>.Create(True);
  try
    U1 := TUser.Create; U1.Id := 1; U1.Name := 'Alice'; U1.Email := 'alice@example.com'; L.Add(U1);
    U2 := TUser.Create; U2.Id := 2; U2.Name := 'Bob';   U2.Email := 'bob@example.com';   L.Add(U2);

    S := TAuroraJSON.ToJSONArray<TUser>(L);
    V := TJSONObject.ParseJSONValue(S);
    try
      Assert.IsNotNull(V, 'JSON inválido');
      A := V as TJSONArray;
      Assert.IsNotNull(A, 'Array JSON esperado');
      Assert.AreEqual(2, A.Count, 'Deve serializar dois itens');

      O := A.Items[0] as TJSONObject;
      Assert.IsNotNull(O);
      Assert.IsTrue(O.TryGetValue('id', Tmp));
      Assert.AreEqual('1', Tmp);
      Assert.IsTrue(O.TryGetValue('name', Tmp));
      Assert.AreEqual('Alice', Tmp);
      Assert.IsTrue(O.TryGetValue('email', Tmp));
      Assert.AreEqual('alice@example.com', Tmp);
    finally
      V.Free;
    end;
  finally
    L.Free;
  end;
end;

procedure TAuroraJSONTests.FromJSONArray_MustDeserializeListOfEntities;
var
  L: TObjectList<TUser>;
  Json: string;
begin
  Json := '[{"id":1,"name":"Alice","email":"alice@example.com"},'+
          ' {"id":2,"name":"Bob","email":"bob@example.com"}]';
  L := TAuroraJSON.FromJSONArray<TUser>(Json);
  try
    Assert.IsNotNull(L);
    Assert.AreEqual(2, L.Count);
    Assert.AreEqual(1, L[0].Id);
    Assert.AreEqual('Alice', L[0].Name);
    Assert.AreEqual('alice@example.com', L[0].Email);
    Assert.AreEqual(2, L[1].Id);
    Assert.AreEqual('Bob', L[1].Name);
    Assert.AreEqual('bob@example.com', L[1].Email);
  finally
    L.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAuroraJSONTests);

end.