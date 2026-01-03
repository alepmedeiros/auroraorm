program ValidationDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  AuroraValidator,
  Entities.User in '..\Sample\AuroraHeadless\Entities\Entities.User.pas';

var
  U: TUser;
  Errors: TList<TAuroraValidationError>;
begin
  U := TUser.Create;
  U.Name := '';
  U.Email := 'invalid-email';
  Errors := TAuroraValidator.Validate<TUser>(U);
  try
    if Errors.Count = 0 then
      Writeln('OK')
    else
      for var E in Errors do
        Writeln(E.Field+': '+E.Message);
  finally
    Errors.Free;
    U.Free;
  end;
end.
