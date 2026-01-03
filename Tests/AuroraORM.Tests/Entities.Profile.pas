unit Entities.Profile;

interface

uses
  AuroraAttributes;

type
  [Tabela('profiles')]
  TProfile = class
  private
    FId: Integer;
    FUserId: Integer;
    FBio: string;
    procedure SetId(const Value: Integer);
    procedure SetUserId(const Value: Integer);
    procedure SetBio(const Value: string);
  published
    [Campo('id'), PK, AutoInc]
    property Id: Integer read FId write SetId;
    [Campo('user_id')]
    property UserId: Integer read FUserId write SetUserId;
    [Campo('bio')]
    property Bio: string read FBio write SetBio;
  end;

implementation

procedure TProfile.SetBio(const Value: string);
begin
  FBio := Value;
end;

procedure TProfile.SetId(const Value: Integer);
begin
  FId := Value;
end;

procedure TProfile.SetUserId(const Value: Integer);
begin
  FUserId := Value;
end;

end.
