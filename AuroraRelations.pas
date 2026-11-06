unit AuroraRelations;

{
  Carregamento explicito ("lazy") de relacionamentos declarados via [HasMany]/
  [BelongsToMany] (e tambem utilizavel para [HasOne]/[BelongsTo] fora do
  carregamento automatico feito por TAuroraDAO<T>.Find*).

  Diferente de LoadOne<R>/LoadMany<R> como metodos de iAuroraDAO<T> (a versao
  anterior, que nunca compilou: Object Pascal nao permite metodos parametrizados
  em interfaces - erro E2535), aqui R e generico numa FUNCAO livre, o que e
  perfeitamente legal e preserva a chamada tipada:

    Orders := TAuroraRelations.LoadMany<TOrder>(Conn, U, 'Orders');
}

interface

uses
  System.Generics.Collections,
  System.Variants,
  Data.DB,
  AuroraInterface,
  AuroraMetadata;

type
  TAuroraRelations = class
  private
    // E2506: metodos genericos declarados na interface nao podem usar simbolos
    // locais da implementation - por isso o helper precisa estar aqui.
    class function FindRelation(aOwnerMeta: TAuroraEntityMeta; const aPropName: string): TAuroraRelationMeta; static;
  public
    // aOwner e a entidade "dona" (ex.: TUser); aPropName e o nome da property
    // marcada com [HasOne]/[BelongsTo]/[HasMany]/[BelongsToMany] nessa entidade.
    class function LoadOne<R: class, constructor>(aQuery: iAuroraQuery; aOwner: TObject; const aPropName: string): R; static;
    class function LoadMany<R: class, constructor>(aQuery: iAuroraQuery; aOwner: TObject; const aPropName: string): TObjectList<R>; static;
  end;

implementation

uses
  System.SysUtils;

class function TAuroraRelations.FindRelation(aOwnerMeta: TAuroraEntityMeta; const aPropName: string): TAuroraRelationMeta;
var
  Rel: TAuroraRelationMeta;
begin
  Result := nil;
  for Rel in aOwnerMeta.Relations do
    if SameText(Rel.PropName, aPropName) then
      Exit(Rel);
end;

class function TAuroraRelations.LoadOne<R>(aQuery: iAuroraQuery; aOwner: TObject; const aPropName: string): R;
var
  OwnerMeta, TargetMeta: TAuroraEntityMeta;
  Rel: TAuroraRelationMeta;
  LocalField: TAuroraFieldMeta;
  LocalValue: Variant;
  SubQuery: iAuroraQuery;
begin
  Result := nil;
  if not Assigned(aOwner) then
    Exit;
  OwnerMeta := TAuroraMetadataRegistry.GetOrBuildByTypeInfo(aOwner.ClassInfo);
  Rel := FindRelation(OwnerMeta, aPropName);
  if Rel = nil then
    Exit;
  LocalField := OwnerMeta.FieldByColumn(Rel.LocalKey);
  if LocalField = nil then
    Exit;
  LocalValue := LocalField.GetValue(aOwner).AsVariant;
  if VarIsNull(LocalValue) or VarIsEmpty(LocalValue) then
    Exit;

  TargetMeta := TAuroraMetadataRegistry.GetOrBuild<R>;
  SubQuery := aQuery.Clone;
  SubQuery.SQL.Text := Format('SELECT * FROM %s WHERE %s = :%s', [TargetMeta.TableName, Rel.ForeignKey, Rel.ForeignKey]);
  SubQuery.Params.CreateParam(ftUnknown, Rel.ForeignKey, ptInput).Value := LocalValue;
  SubQuery.Open;
  if not SubQuery.DataSet.Eof then
    Result := R(AuroraMapDataSetToInstance(TargetMeta, SubQuery.DataSet));
end;

class function TAuroraRelations.LoadMany<R>(aQuery: iAuroraQuery; aOwner: TObject; const aPropName: string): TObjectList<R>;
var
  OwnerMeta, TargetMeta: TAuroraEntityMeta;
  Rel: TAuroraRelationMeta;
  LocalField: TAuroraFieldMeta;
  LocalValue: Variant;
  SubQuery: iAuroraQuery;
begin
  Result := TObjectList<R>.Create(True);
  if not Assigned(aOwner) then
    Exit;
  OwnerMeta := TAuroraMetadataRegistry.GetOrBuildByTypeInfo(aOwner.ClassInfo);
  Rel := FindRelation(OwnerMeta, aPropName);
  if Rel = nil then
    Exit;
  LocalField := OwnerMeta.FieldByColumn(Rel.LocalKey);
  if LocalField = nil then
    Exit;
  LocalValue := LocalField.GetValue(aOwner).AsVariant;
  if VarIsNull(LocalValue) or VarIsEmpty(LocalValue) then
    Exit;

  TargetMeta := TAuroraMetadataRegistry.GetOrBuild<R>;
  SubQuery := aQuery.Clone;
  SubQuery.SQL.Text := Format('SELECT * FROM %s WHERE %s = :%s', [TargetMeta.TableName, Rel.ForeignKey, Rel.ForeignKey]);
  SubQuery.Params.CreateParam(ftUnknown, Rel.ForeignKey, ptInput).Value := LocalValue;
  SubQuery.Open;
  while not SubQuery.DataSet.Eof do
  begin
    Result.Add(R(AuroraMapDataSetToInstance(TargetMeta, SubQuery.DataSet)));
    SubQuery.DataSet.Next;
  end;
end;

end.
