unit Entities.Order;

interface

uses
  AuroraAttributes;

type
  [Tabela('orders')]
  TOrder = class
  private
    FId: Integer;
    FUserId: Integer;
    FTotal: Double;
    procedure SetId(const Value: Integer);
    procedure SetUserId(const Value: Integer);
    procedure SetTotal(const Value: Double);
  published
    [Campo('id'), PK, AutoInc]
    property Id: Integer read FId write SetId;
    [Campo('user_id')]
    property UserId: Integer read FUserId write SetUserId;
    [Campo('total')]
    property Total: Double read FTotal write SetTotal;
  end;

implementation

procedure TOrder.SetId(const Value: Integer);
begin
  FId := Value;
end;

procedure TOrder.SetTotal(const Value: Double);
begin
  FTotal := Value;
end;

procedure TOrder.SetUserId(const Value: Integer);
begin
  FUserId := Value;
end;

end.
