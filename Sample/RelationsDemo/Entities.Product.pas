unit Entities.Product;

interface

uses
  AuroraAttributes;

type
  [Tabela('products')]
  TProduct = class
  private
    FId: Integer;
    FCategoryId: Integer;
    FName: string;
    FPrice: Double;
    FCreatedAt: TDateTime;
    procedure SetId(const Value: Integer);
    procedure SetCategoryId(const Value: Integer);
    procedure SetName(const Value: string);
    procedure SetPrice(const Value: Double);
    procedure SetCreatedAt(const Value: TDateTime);
  published
    [Campo('id'), PK, AutoInc]
    property Id: Integer read FId write SetId;
    [Campo('category_id'), NotNull, FK('categories','id')]
    property CategoryId: Integer read FCategoryId write SetCategoryId;
    [Campo('name'), NotNull, Index]
    property Name: string read FName write SetName;
    [Campo('price')]
    property Price: Double read FPrice write SetPrice;
    [Campo('created_at'), NotNull]
    property CreatedAt: TDateTime read FCreatedAt write SetCreatedAt;
  end;

implementation

procedure TProduct.SetCategoryId(const Value: Integer);
begin
  FCategoryId := Value;
end;

procedure TProduct.SetCreatedAt(const Value: TDateTime);
begin
  FCreatedAt := Value;
end;

procedure TProduct.SetId(const Value: Integer);
begin
  FId := Value;
end;

procedure TProduct.SetName(const Value: string);
begin
  FName := Value;
end;

procedure TProduct.SetPrice(const Value: Double);
begin
  FPrice := Value;
end;

end.
