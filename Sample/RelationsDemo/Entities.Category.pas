unit Entities.Category;

interface

uses
  AuroraAttributes;

type
  [Tabela('categories')]
  TCategory = class
  private
    FId: Integer;
    FName: string;
    procedure SetId(const Value: Integer);
    procedure SetName(const Value: string);
  published
    [Campo('id'), PK, AutoInc]
    property Id: Integer read FId write SetId;
    [Campo('name'), NotNull, Unique, Index]
    property Name: string read FName write SetName;
  end;

implementation

procedure TCategory.SetId(const Value: Integer);
begin
  FId := Value;
end;

procedure TCategory.SetName(const Value: string);
begin
  FName := Value;
end;

end.
