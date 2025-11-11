unit UserPlain;

interface

type
  // Entidade sem mapeamento (sem atributos, sem herdar de TAuroraEntity)
  TUserPlain = class
  private
    FId: Integer;
    FName: String;
    FEmail: String;
  public
    property Id: Integer read FId write FId;
    property Name: String read FName write FName;
    property Email: String read FEmail write FEmail;
  end;

implementation

end.