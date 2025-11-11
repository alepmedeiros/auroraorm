unit AuroraEntity;

interface

uses
  System.Classes,
  System.Generics.Collections;

type
  // Entidade base nativa do AuroraORM, sem dependências do SimpleORM.
  // Mantemos mínima para permitir herança em entidades mapeadas.
  TAuroraEntity = class(TObject)
  public
    constructor Create; virtual;
    destructor Destroy; override;
  end;

  // Lista genérica de entidades Aurora
  TAuroraEntityList<T: class, constructor> = class(TObjectList<T>)
  public
    constructor Create(OwnsObjects: Boolean = True); reintroduce;
  end;

implementation

{ TAuroraEntity }

constructor TAuroraEntity.Create;
begin
  inherited Create;
end;

destructor TAuroraEntity.Destroy;
begin
  inherited;
end;

{ TAuroraEntityList<T> }

constructor TAuroraEntityList<T>.Create(OwnsObjects: Boolean);
begin
  inherited Create(OwnsObjects);
end;

end.