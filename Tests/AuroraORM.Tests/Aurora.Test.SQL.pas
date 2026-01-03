unit Aurora.Test.SQL;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  AuroraSQL,
  Sample.AuroraHeadless.Entities.Entities.User;

type
  [TestFixture]
  TAuroraSQLTests = class
  public
    [Test]
    procedure Build_Select_MustIncludeWhereAndOrder;
  end;

implementation

procedure TAuroraSQLTests.Build_Select_MustIncludeWhereAndOrder;
var S: string;
begin
  TAuroraSQL<TUser>.New
    .Fields('id,name')
    .Where('name LIKE :name')
    .OrderBy('id desc')
    .Select(S);
  Assert.IsTrue(Pos('WHERE', UpperCase(S))>0);
  Assert.IsTrue(Pos('ORDER BY', UpperCase(S))>0);
end;

initialization
  TDUnitX.RegisterTestFixture(TAuroraSQLTests);

end.
