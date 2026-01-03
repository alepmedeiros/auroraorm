program JSONDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  AuroraJSON,
  Entities.User in '..\Sample\AuroraHeadless\Entities\Entities.User.pas';

var
  U: TUser;
  L: TObjectList<TUser>;
  J: string;
begin
  U := TUser.Create;
  U.Name := 'Alice';
  U.Email := 'alice@example.com';

  J := TAuroraJSON.ToJSONWithOptions<TUser>(U, False, True, True);
  Writeln('ToJSONWithOptions:');
  Writeln(J);

  U := TAuroraJSON.FromJSONWithOptions<TUser>(J, True, False);
  Writeln('FromJSONWithOptions:');
  Writeln(TAuroraJSON.ToJSON<TUser>(U));

  L := TObjectList<TUser>.Create(True);
  L.Add(U);
  var JArr := TAuroraJSON.ToJSONArrayWithOptions<TUser>(L, False, True, True);
  Writeln('ToJSONArrayWithOptions:');
  Writeln(JArr);
  L.Free;
end.
