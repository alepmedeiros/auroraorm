# Legacy (SimpleORM)

Este diretório é reservado para conteúdo legado que servirá como referência durante a migração para o AuroraORM.

Sugerimos mover para cá (ou manter como referência):
- `Sample/RestDW`
- `Sample/Unidac`
- `Sample/FM X`
- `Sample/horse`
- `Sample/Validation` (pode ser mantido para reaproveitar a camada de validação)
- `SimpleORM.dpk/.dproj` e demais arquivos do pacote SimpleORM
- Adapters: `SimpleQueryRestDW.pas`, `SimpleQueryUnidac.pas`, `SimpleQueryZeos.pas`

Observação:
- O AuroraORM é FireDAC-only e focado em PostgreSQL e SQLite.
- Manteremos o que for útil como aprendizado, mas exemplos novos serão headless (sem bind visual), seguindo um estilo mais próximo do Hibernate.

Se desejar, posso realizar a movimentação física destas pastas/arquivos para `legacy/` em um próximo passo, preservando histórico.