program SQLDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AuroraSQL,
  Entities.User in '..\Sample\AuroraHeadless\Entities\Entities.User.pas';

var
  S: string;
begin
  try
    TAuroraSQL<TUser>.New
      .Fields('id, name, email')
      .Where('name LIKE :name')
      .OrderBy('id DESC')
      .Select(S);
    Writeln('SELECT:');
    Writeln(S);

    TAuroraSQL<TUser>.New
      .Insert(S);
    Writeln('INSERT:');
    Writeln(S);

    TAuroraSQL<TUser>.New
      .Update(S);
    Writeln('UPDATE:');
    Writeln(S);

    TAuroraSQL<TUser>.New
      .Delete(S);
    Writeln('DELETE:');
    Writeln(S);

    TAuroraSQL<TUser>.New
      .LastRecord(S);
    Writeln('LAST RECORD:');
    Writeln(S);
  except
    on E: Exception do Writeln(E.ClassName+': '+E.Message);
  end;
end.
