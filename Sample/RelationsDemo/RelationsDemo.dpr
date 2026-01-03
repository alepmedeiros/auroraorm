program RelationsDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  AuroraConfig,
  AuroraInterface,
  AuroraQueryFiredac,
  AuroraSchemaSync,
  AuroraDAO,
  Entities.Category in 'Entities.Category.pas',
  Entities.Product in 'Entities.Product.pas';

var
  Conn: TFDConnection;
  Q: iAuroraQuery;
  CatDAO: iAuroraDAO<TCategory>;
  ProdDAO: iAuroraDAO<TProduct>;
  Cat: TCategory;
  Prod: TProduct;
begin
  Conn := TFDConnection.Create(nil);
  Conn.Params.Values['DriverID'] := 'SQLite';
  Conn.Params.Database := 'aurora.db';
  Conn.Open;
  TAuroraConfig.SetDialect(dbSQLite);
  Q := TAuroraQueryFiredac.New(Conn);

  TAuroraSchemaSync.Ensure<TCategory>(Q);
  TAuroraSchemaSync.Ensure<TProduct>(Q);

  CatDAO := TAuroraDAO<TCategory>.NewAurora(Q);
  ProdDAO := TAuroraDAO<TProduct>.NewAurora(Q);

  Cat := TCategory.Create; Cat.Name := 'Eletrônicos'; CatDAO.Insert(Cat);
  Prod := TProduct.Create; Prod.CategoryId := 1; Prod.Name := 'Camera'; Prod.Price := 499.90; Prod.CreatedAt := Now; ProdDAO.Insert(Prod);

  Writeln('RelationsDemo OK');
end.
