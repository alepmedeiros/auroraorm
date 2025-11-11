unit Entities.User;

interface

uses
  AuroraEntity, AuroraAttributes, System.SysUtils;

type
  [Tabela('users')]
  TUser = class(TAuroraEntity)
  private
    [PK]
    [AutoInc]
    [Campo('id')]
    FId: Integer;

    [NotNull]
    [Campo('name')]
    FName: String;

    [NotNull]
    [Campo('email')]
    FEmail: String;
  public
    property Id: Integer read FId write FId;
    property Name: String read FName write FName;
    property Email: String read FEmail write FEmail;
  end;

implementation

end.