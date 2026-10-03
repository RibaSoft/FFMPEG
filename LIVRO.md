<!-- ============================================================================ -->
<!--  CAPA                                                                        -->
<!-- ============================================================================ -->

<div style="text-align:center; page-break-after:always;">

<br><br><br><br><br><br>

# NEW_Varejo

## O livro do projeto

### Arquitetura, padrões, armadilhas e manual de uso do sistema de varejo RibaSoft

<br><br><br>

**Object Pascal · Lazarus 4.8 · Firebird 5.0.4 · ZEOS 8 · ACBr · LazReport**

<br><br><br><br><br><br>

RibaSoft — Ribamar M. Santos
Documentação consolidada em 12/09/2026
Escrita a partir do código, do `CLAUDE.md`, do `ESTADO.md`, do `DECISOES.md`, do `FISCAL.md`
e da memória de trabalho das sessões de agosto e setembro de 2026.

</div>

<!-- ============================================================================ -->
<!--  PREFÁCIO                                                                    -->
<!-- ============================================================================ -->

## Prefácio — para que serve este livro

Este documento tem **três leitores** e foi escrito para os três:

1. **Quem vai dar manutenção no NEW_Varejo** — encontra aqui a estrutura, os padrões
   de cada camada, as regras de negócio que o código faz mas não explica, e as armadilhas
   que compilam verde e quebram em produção.
2. **Quem vai começar um projeto novo no padrão RibaSoft** (como já aconteceu com o
   `New_RibaSoftADM` e o `EmissorDiario`) — encontra na Parte VIII o que se replica, em
   que ordem, e o que **não** se replica.
3. **Quem usa o sistema** — encontra na Parte VII o manual: menus, atalhos, o fluxo de
   emissão fiscal e a lista do que *parece* defeito e não é.

O livro é um **retrato**. O estado vivo das frentes continua no `ESTADO.md`; o porquê de
cada decisão continua no `DECISOES.md`; o mapa fiscal continua no `FISCAL.md`. Quando
este livro e um desses três discordarem, **vale o arquivo curto** — ele é atualizado a cada
sessão, este não. Onde há um `§`, é ponteiro para a seção correspondente do `DECISOES.md`.

Duas convenções de leitura:

- ⚠ marca armadilha: coisa que não dá erro de compilação e só aparece rodando (ou na SEFAZ).
- Nomes em `código` são nomes reais de arquivo, unit, classe, método, tabela ou coluna —
  todos conferíveis por `grep` no repositório.

---

## Sumário

**Parte I — O projeto**
1. Visão geral
2. Estrutura de pastas e arquivos
3. A documentação viva e suas regras

**Parte II — Arquitetura e padrões**
4. As camadas e as interfaces centralizadas
5. O framework RibaSoft (`utils/`)
6. O padrão de um `model`
7. O padrão de uma `view`
8. O banco de dados
9. Convenções de código

**Parte III — A linguagem e suas armadilhas**
10. FPC / Object Pascal: tipos e strings
11. Lazarus / LCL: o que compila verde e quebra depois
12. Firebird e ZEOS
13. LazReport
14. Rede, OpenSSL e atualização automática

**Parte IV — Fiscal**
15. A ordem das fontes fiscais
16. ACBr: armadilhas gerais
17. NF-e e NFC-e
18. CT-e e CT-e OS
19. MDF-e
20. Distribuição DF-e e manifestação
21. Reforma tributária, tabelas de apoio e rejeições com receita própria

**Parte V — Regras de negócio**
22. Venda, caixa, pagamentos e financeiro
23. As frentes e suas decisões
24. O que foi recusado — não voltar a propor

**Parte VI — Operação e ciclo de vida**
25. Build e ferramentas
26. Publicar uma versão
27. Finalizar uma sessão de trabalho
28. Diagnóstico de campo

**Parte VII — Manual do usuário**
29. Menus e atalhos
30. As telas e os fluxos principais
31. O que parece defeito e não é

**Parte VIII — Padronização para novos projetos**
32. O que se replica e em que ordem
33. Como trabalhar com assistente de código neste padrão

**Apêndices**
A. Scripts de varredura
B. Mapa da `ImageList24_botoes`
C. Glossário

---

<!-- ============================================================================ -->
<!--  PARTE I                                                                     -->
<!-- ============================================================================ -->

# Parte I — O projeto

## 1. Visão geral

O **NEW_Varejo** é a reescrita do sistema de varejo da RibaSoft (o antigo vive em
`D:\Documents\GitHub\Varejo`, com telas `UnitXxx.pas` sem camada nenhuma). A regra de escopo
que guiou a reescrita foi dita pelo autor em 27/08/2026: *"não colocar nada a mais que o
antigo, só organizar e padronizar"*. O sistema antigo é a fonte de **escopo** e, muitas vezes,
de **leiaute** (etiquetas, relatórios) — antes de dar algo como "não existe", conferir se é
buraco ou se é escopo.

### 1.1 Stack

| Camada | Tecnologia |
|---|---|
| Linguagem / IDE | Object Pascal, **Lazarus 4.8** (FPC 3.2.2), `{$mode objfpc}{$H+}`, UTF-8, DPI-aware |
| Banco | **Firebird 5.0.4** embarcado (ou instalado / em rede), via **ZEOS 8** |
| Fiscal | **ACBr** (NF-e, NFC-e, CT-e, CT-e OS, MDF-e, distribuição DF-e, e-mail) |
| Relatórios | **LazReport** (`.lrf`, XML legível) + FortesReport CE (DANFE/DACTE/DAMDFE do ACBr) |
| Componentes próprios | pacote `ribasoft` (`TBotao` em `libBotao.pas`, `TReiniciador` em `libReiniciador.pas`, repo `RibaSoftComponentes`) |
| Alvo | Windows 32 bits (`i386-win32` fixado — o `fbclient.dll` é x86) |

### 1.2 O cliente-alvo

Varejo pequeno, quase sempre **Simples Nacional**, com um ou poucos terminais. Isso explica
uma regra que aparece em todo o projeto: **campo que o cliente-alvo nunca usou não vira UI** —
no máximo coluna no banco ou constante (`DECISOES.md § 2`). O emitente-piloto é Simples, mas o
código já cobre o Regime Normal (o `CRT` vem do `Config` e pode mudar sem aviso).

### 1.3 O estado em 12/09/2026

Todas as frentes de código estão fechadas, exceto a **Central de Relatórios**, que fica aberta
por natureza (cresce a cada relatório). Em produção de verdade: NF-e/NFC-e, MDF-e, CT-e OS,
migração do antigo, etiquetas, entrada de XML no estoque. Código completo e à espera do uso
real: CT-e 57, mesas, pedido/orçamento, balança, distribuição DF-e, gerador de chaves,
tributação por cenário de destino. Detalhe e datas: `ESTADO.md § 1`.

A matriz fiscal documento por documento (emitir, consultar, imprimir, exportar, cancelar,
carta de correção, inutilizar, encerrar, eventos, importar, e-mail, contabilidade,
distribuição) está no `ESTADO.md § 2` — os traços de "não existe" lá **não são pendência**,
são ausência de serviço no leiaute (CT-e 4.00 não tem inutilização; MDF-e nunca teve).

---

## 2. Estrutura de pastas e arquivos

```
NEW_Varejo/
├── pVarejo.lpr / .lpi / .res / .ico   projeto Lazarus (todas as units entram pelo .lpr)
├── CLAUDE.md  ESTADO.md  DECISOES.md  FISCAL.md  LIVRO.md
├── Limpar.bash                         limpeza + release + commit (ver cap. 26)
├── audita_lrf.ps1                      auditoria dos .lrf (ver cap. 13)
├── extrair_lazarus.ps1                 utilitário de extração
├── dataObject/   dbo.*.pas + RibaInterfaceData.pas   (27 arquivos)
├── model/        model.*.pas                          (62)
├── controller/   controller.*.pas                     (12)
├── view/         view.*.pas + .lfm                    (140 = 70 telas)
├── thread/       thread.*.pas                         (6)
├── utils/        Riba*.pas + RibaCore.lrs             (11)
├── report/       *.lrf                                (15)
├── img/  intl/  resource/                            recursos (intl e resource gitignored)
├── Schemas/  data/  XMLs/  bkp/  lib/                 NÃO versionados (.gitignore)
├── DB.FDB  Config.ini  cert.pfx                      dados locais, NÃO versionados
└── Varejo.exe / Varejo_debug.exe                     artefatos de build
```

### 2.1 O que cada pasta contém

**`dataObject/`** — as entidades (`dbo.cliente`, `dbo.produto`, `dbo.nf`, `dbo.nf_item`,
`dbo.venda`, `dbo.cte`, `dbo.mdf`, `dbo.pedido`, `dbo.mesa_item`, `dbo.trib`, ...). Só dados. E
o **`RibaInterfaceData.pas`**, onde moram **todas** as interfaces de entidade (`ICliente`,
`IProduto`, `INF`, ...).

**`model/`** — regra de negócio + SQL. Um model por tabela ou por família de tabela
(`model.nf`, `model.nf_item`, `model.nf_pag`, `model.nf_vol`, `model.nf_dup`, `model.nf_ref`,
`model.nf_evento`, `model.nf_contabilidade`, `model.nf_import`, `model.nf_venda`; idem para
`cte_*` e `mdf_*`). Mais os de serviço: `model.auditoria`, `model.permissao`, `model.import`,
`model.migracao`, `model.balanco`, `model.dfe`, `model.entrada_xml*`, `model.trib_inter`.

**`controller/`** — orquestração entre view e model: `cliente`, `fornecedor`, `produto`,
`venda`, `cupom`, `fiscal`, `nf`, `cte`, `mdf`, `dfe`, `entrada_xml`, `migracao`.

**`view/`** — 70 telas. Frames de tela cheia (`TPadraoView`) e diálogos `TForm`
(`view.busca_*`, `view.input_*`, `view.abertura_caixa`, `view.ajuste_preco`,
`view.contas_pagar_detalhe`, `view.mdf_encerra`, `view.gerador_chaves_fiscais`,
`view.ajuste_trib_inter`, `view.pizza`). O **`view.principal`** é o form único do app e o
dono da navegação (cap. 7).

**`thread/`** — `thread.inicio` (a abertura do sistema: atualização, Firebird, banco,
tabelas de apoio, backup de saída), `thread.migracao`, `thread.importa_dados`,
`thread.restaura`, `thread.produto_get`, `thread.trib_get` (receita de carga em thread, sem uso
hoje).

**`utils/`** — o framework (cap. 5): `RibaCore`, `RibaDB`, `RibaTools`, `RibaConfig`,
`RibaTypes`, `RibaApi`, `RibaACBr` (11.297 linhas — o motor fiscal), `RibaAtivacao`,
`RibaEtiqueta`, `RibaProgresso`, e o **`RibaCore.lrs`** (22 MB: os binários do Firebird, as
DLLs do OpenSSL embutidas no `.exe` como resource).

**`report/`** — 15 `.lrf`: `aniversariantes`, `auditoria`, `balanco`, `caixa_movimento`,
`carne`, `clientes`, `compras`, `contas_pagar`, `fornecedores`, `lotes`, `pedido`,
`produtos`, `venda`, `vendidos_produto`, `vendidos_vendedor`.

### 2.2 O que NÃO é versionado, e por quê

O `.gitignore` deixa de fora `Schemas/`, `data/`, `lib/`, `bkp/`, `XMLs/`, `intl/`,
`resource/`, e toda extensão de dado local (`*.ini`, `*.FDB`, `*.dll`, `*.exe`, `*.pfx`,
`*.txt`, `*.csv`, `*.log`, `*.lps`, `*.res`). Consequências que enganam:

- ⚠ **`Schemas/` não viaja no commit.** Quem leva o XSD ao cliente é o servidor
  (`Schemas.zip`, atualizado 1×/dia pela `thread.inicio`), não o git. E o ACBr valida contra o
  XSD **local** antes de transmitir — grupo novo + XSD velho = erro local sem rejeição da SEFAZ
  (`§ 4.6`).
- **`data/` é a tabela oficial no disco** (CFOP, NCM, CEST, ANP, cBenef, cClassTrib,
  municípios). Antes de pesquisar norma fora, `grep` ali (cap. 21).
- **`build.log`**, `Varejo.exe` e `lib/` são artefatos: o build não suja o diff.

---

## 3. A documentação viva e suas regras

O projeto tem **quatro arquivos de conhecimento** na raiz, lidos nesta ordem no início de
toda sessão de trabalho — e este livro é o quinto, de outra natureza (retrato, não painel).

| Arquivo | O que é | O que NÃO é |
|---|---|---|
| `CLAUDE.md` | regras de operação da sessão: somente leitura no fonte, camadas, interfaces, framework, como finalizar sessão | histórico |
| `ESTADO.md` | **o painel**: uma linha por frente, a matriz fiscal, o que falta de verdade | relato de sessão, lista de tarefas futuras |
| `DECISOES.md` | **o porquê**: recusas, regras vivas, armadilhas que não quebram compilação, o durável de cada frente fechada (§ 7 CT-e, § 8 MDF-e, § 9 etiquetas, § 10 DF-e, § 11 balança, § 12 mesas, § 13 pedido, § 14 relatórios, § 15 gerador, § 16 novidades, § 17 auditoria, § 18 trib. destino) | código copiado |
| `FISCAL.md` | **o mapa fiscal**: IE × `indIEDest`, códigos numéricos de tela, reforma (datas), rejeições com receita, tabelas de apoio; **ponteiro `§`** para o `DECISOES.md` em tudo que já estava lá | cópia do `DECISOES.md` |

### 3.1 Regras de manutenção que valem para os quatro

- **Frente que fecha vira uma linha** no `ESTADO.md`; o durável vai para o `DECISOES.md`; o
  relato sessão a sessão fica **só no git** (`git show b9daee1:HANDOFF_MDF.md`,
  `34eae7c:HANDOFF_CTE.md`, `caafedd:HANDOFF_entrada_xml_estoque.md`, ...). Não existe mais
  handoff nem plano na raiz, e não deve voltar a existir.
- **Ponteiro, nunca cópia.** Duas cópias da mesma regra divergem sozinhas.
- **Nada de nomenclatura por "fase".** "Fase 5" era divisão de sessão e envelheceu no dia em
  que a frente fechou. O que faz alguma coisa se chama pelo **nome**
  (`ValidaMDFeParaEmissao`, `AlimentaCTe`). Única exceção: a migração do antigo, onde
  "FASE 1 / FASE 2" é vocabulário de **runtime** que o usuário lê no relatório da
  `model.migracao`.
- **Esqueleto de frame/form não é pendência.** Telas criadas só no Object Inspector, sem
  lógica, são propositais — não se listam, não se contam, não se sugere trabalho nelas.
- **Prova de campo não é pendência e roteiro de teste não se escreve** (decisão de
  04/09/2026). Registrar *se* uma frente já rodou em cliente é estado; *como* testá-la não
  entra em documento nenhum. Antes de apagar uma seção de teste, salvar os "isso NÃO é bug"
  que ela escondia.
- **Antes de afirmar que algo existe, `grep`.** Levantamento escrito erra nos dois sentidos.
  Unit ou tabela: `grep` em `model/`. Coluna: `grep` em `utils/RibaDB.pas`. Arquivo
  apagado: `git log --diff-filter=D -- <arquivo>`.
- **Decisão implementada está no código; decisão recusada não está em lugar nenhum** —
  ausência não se pesquisa. É por isso que o `DECISOES.md § 2` e o cap. 24 deste livro
  existem.

---

<!-- ============================================================================ -->
<!--  PARTE II                                                                    -->
<!-- ============================================================================ -->

# Parte II — Arquitetura e padrões

## 4. As camadas e as interfaces centralizadas

Quase tudo é `TInterfacedObject` implementando uma interface `I*` — contagem de referência,
memória gerenciada, nenhum `Free` de entidade espalhado pelo código.

| Camada | Prefixo | Papel | O que NÃO faz |
|---|---|---|---|
| `dataObject` | `dbo.` | entidade/DTO: `Get*`/`Set*`, `Clear`, propriedades; o setter **normaliza** (`FormataTexto`, `LimpaNumeros`) | SQL, regra de negócio |
| `model` | `model.` | regra de negócio + SQL via `TRibaDB`; críticas de gravação; `Riba.Aviso` quando recusa | UI |
| `controller` | `controller.` | orquestra view ↔ model; navega pelo `PrincipalView.InstanciaView`; pouca ou nenhuma SQL | regra pesada |
| `view` | `view.` | frames `TPadraoView` ou diálogos `TForm`; monta a entidade a partir da tela e chama controller/model | SQL, regra de negócio |
| `thread` | `thread.` | tarefas de fundo, `TThread`, `Synchronize` para tocar na UI | — |
| `utils` | `Riba*` | framework (cap. 5) | — |
| `report` | `*.lrf` | LazReport | — |

### 4.1 ⚠ A regra crítica: as interfaces são centralizadas

Nenhuma interface fica na unit da classe que a implementa:

- Interfaces de **entidade** (`ICliente`, `IProduto`, `INF`, `INFItem`, `ICT`, `IMDF`, ...) →
  **`dataObject/RibaInterfaceData.pas`**.
- Interfaces de **model, controller e serviço** (`IClienteModel`, `INFController`,
  `IACBrTools`, `IConfig`, `IRibaTools`, `IRibaAtivacao`, ...) → **`utils/RibaCore.pas`**.

Consequências que já custaram compilação:

- **Método público novo = classe + interface**, no mesmo bloco de entrega. Declarar só na
  classe compila a unit inteira verde; o erro (`5038 identifier idents no member`) aparece no
  **primeiro chamador**, que usa a variável de interface — um arquivo que nem foi tocado.
- **A lista de métodos no topo do `RibaACBr.pas` é a CLASSE `TACBrTools`, não a interface**
  (`IACBrTools` está no `RibaCore.pas`). Lida de relance, parece a interface (`§ 15.6`).
- **Ler a classe não é ler a interface.** `TFornecedor` tinha `property Limite`; `IFornecedor`
  não — e é pela interface que o resto do sistema enxerga. Membro de dbo que a interface não
  expõe é candidato a código morto.
- **Método público de VIEW não entra em interface** — o `view.principal` chama por cast
  direto no `FFrame`.
- **Type com nome igual ao do ACBr** numa unit que usa as duas famílias resolve pela unit
  mais à direita do `uses` e faz sumir um método de interface "sem motivo" (`5042 No matching
  implementation`). `TDadosCertificado` virou `TDadosCert` por isso.

### 4.2 Models e controllers são FACTORY

Os acessos globais do `RibaCore` (`ProdutoModel`, `ClienteModel`, `NFController`, ... — mais
de 60, listados em `RibaCore.pas:1860-1923`) são **funções que devolvem instância nova**:
`Result := TProdutoModel.Create;`. Logo:

- Todo estado guardado por método fluente (`acao`, `produto`, `busca`, `id`) **morre com a
  instância**. `ProdutoModel.acao(acNovo);` seguido de `ProdutoModel.GeraCPROD(...)` não
  compartilha nada — o segundo nasce com `FAcao = acNill` e o `ExisteValor` recusa.
- Certo é **tudo na mesma cadeia**: `ProdutoModel.acao(acNovo).produto(auxProduto).salvar(auxID)`.
  Precisando de duas chamadas, guardar em variável `I*Model` local.
- **Cada instância abre a própria conexão** (cap. 8) — é o outro lado da mesma moeda.

As entidades também têm factory: `dataCliente`, `dataVendedor`, `dataNF`, ... (funções
`data*` no `RibaCore`).

### 4.3 Nomenclatura

| | Interface | Classe | Arquivo |
|---|---|---|---|
| entidade | `ICliente` | `TCliente` | `dbo.cliente.pas` |
| model | `IClienteModel` | `TClienteModel` | `model.cliente.pas` |
| controller | `IClienteController` | `TClienteController` | `controller.cliente.pas` |
| view | — | `TClienteCadastroView` | `view.cliente_cadastro.pas` |
| thread | — | `TInicioThread` | `thread.inicio.pas` |

Tabelas no **plural** (`CLIENTES`, `PRODUTOS`, `VENDAS`), filhas com prefixo singular +
plural (`VENDA_ITENS`, `CAIXA_ITENS`, `MESA_ITENS`, `PEDIDO_ITENS`, `NF_ITENS`), exceto a
família fiscal (`NF`, `CTE`, `MDFE` e suas `NF_*`, `CTE_*`, `MDFE_*`).

---

## 5. O framework RibaSoft (`utils/`)

Reutilizar, nunca recriar. Antes de escrever helper novo, `grep` aqui.

| Unit | Classe / interface | Responsabilidade |
|---|---|---|
| `RibaCore` | interfaces + `TPadraoView` + factories + `PintaLinhaGrade` | registro central de interfaces; classe-base dos frames; `Riba`, `Config`, `ACBrTools` (as três globais de serviço) |
| `RibaDB` | `TRibaDB` | acesso ao Firebird via ZEOS; `CriaTabelas`, `AtualizaColunas`, `ExisteValor`, `ExisteDoc`, `CacheCombo`, `CarregaComboBox*`, os loaders `Cria*` das tabelas de apoio |
| `RibaTools` | `TRiba` / `IRibaTools` (+ `TRibaZipBridge`) | utilitários: `Aviso`/`Sucesso`/`Confirma`, `FormataTexto`, `LimpaNumeros`, `LimpaDoc`, `LimpaPlaca`, `Arredonda`, `EstilizaComponentes`, `ComboBoxObjeto`/`ComboBoxTexto`, `Input*`, `ClipBoard`, `Encripta`, `DiagnosticoConexao`, extração dos resources |
| `RibaConfig` | `TConfig` / `IConfig` | `Config.ini` (por máquina) **e** tabela `CONFIG` (por banco); `GravaConexao`; `NewConfig` |
| `RibaTypes` | tipos, records, enums, constantes | `TAcao`, `TTipoConexao`, `TPermissao`, `CFG_*`, cores (`VerdeClaro`, ...), `ARQUIVO_CONFIG = '.\Config.ini'`, `DIAS_ATRASO_BLOQUEIO`, `SUPORTE_JANELA_SEG`, conta SMTP |
| `RibaApi` | `TRibaApi` | HTTP com o servidor `ribasoft.com.br`: `TemVersaoNova`, `AtualizaSistema`, `AtualizaArquivo` (hash SHA1), `VerificaFirebird`, `MandaVersao`, ReceitaWS |
| `RibaACBr` | `TACBrTools` / `IACBrTools` | **o motor fiscal**: `Configura*`, `Alimenta*`, `Valida*ParaEmissao`, `Emite*`, `Consulta*`, `Cancela*`, `Imprime*`, `Exporta*`, distribuição DF-e, e-mail, `MontaChaveNF`, `CodigoNumericoNF`, `ValidaIE` |
| `RibaAtivacao` | `TRibaAtivacao` / `IRibaAtivacao` | ativação por chave (estado no `Config.ini`, não na `CONFIG`) |
| `RibaEtiqueta` | motor de etiqueta em milímetros | modelo 40 (Oasis 80×60), calibração |
| `RibaProgresso` | `TRibaProgressoUI` / `IRibaProgresso` | UI de progresso para threads e downloads |

### 5.1 O que o `EstilizaComponentes` faz por você (e o que você precisa desfazer)

`Riba.EstilizaComponentes(container)` roda no `TPadraoView.Create` (via `inherited`) e no
`FormCreate` de todo diálogo. Ele impõe o padrão do sistema:

- **todo `TEdit` sai em MAIÚSCULAS** (`CharCase := ecUppercase`) — convenção, não se mexe.
  Campo de e-mail declara a exceção no próprio `Create` (`ecLowerCase`); o `Riba.InputTexto`
  tem o interruptor `AMinusculas`;
- **todo `TDateTimePicker` recebe `NullInputAllowed := False`** — o picker vazio devolve
  `1.7e+308`, não zero (cap. 11). Picker que precisa aceitar vazio (`dtpDocDPrev` do CT-e)
  sobrescreve no `Create`;
- **`TForm` ganha `KeyPreview := True`** — não se pede no roteiro de `.lfm`.

Mesma mecânica sempre: o estilizador manda o padrão rígido, a tela declara a exceção.

### 5.2 `Riba.FormataTexto` × `Riba.LimpaNumeros` × `Riba.LimpaPlaca`

- `FormataTexto(AValue, AMaiusculas, ATamanho)`: TAB/LF/CR viram espaço, duplicados
  colapsam, controle e emoji somem, `&` vira `E`, aspas inteligentes viram ASCII, `Trim`,
  corte por **caracteres** (`UTF8Copy`). **Preserva pontuação, inclusive o ponto.** Serve
  para texto humano (nome, razão, descrição, `infCpl`).
- ⚠ Por preservar o ponto, **estraga código numérico**: `0102.10.10` com
  `FormataTexto(x, True, 8)` grava `0102.10.` — aceito pelo banco, recusado na emissão.
  **NCM, CEST, CFOP gravam por `LimpaNumeros(AValue, True).Substring(0, n)`** (`FISCAL.md § 3`).
- **Placa** grava por `LimpaPlaca` (só `[0-9A-Z]`, sem cortar — quem corta é o setter que
  conhece a coluna): `FormataTexto(APlaca, True, 7)` transformaria `ABC-1234` em `ABC-123`
  (`§ 4.8`).
- O `FormataTexto` **achata quebra de linha**: campo alimentado por `TMemo` vira uma linha.
  Onde a quebra importa (`infCpl` da NF), o par `QuebraLinhaParaPipe`/`PipeParaQuebraLinha` do
  `RibaTools` traduz na fronteira da view — o `|` é a convenção do próprio ACBr (cap. 16).

### 5.3 Os diálogos prontos — não criar `InputQuery`

`Riba.InputTexto(ATitulo; var ATexto; AObrigatorio = True; AMinusculas = False)`,
`Riba.InputMemo` (preserva caixa; critica mínimo/máximo em caracteres), `Riba.InputValor`,
`Riba.InputNumero` (é o `InputValor` com `Precisao := 0`), `Riba.InputDoc`, `Riba.InputData`.
Todos em variável **local**, sem `ProcessMessages` antes do `ShowModal` (cap. 11).
⚠ `InputTexto` devolve **MAIÚSCULAS ou minúsculas — nunca "como digitado"**; para
identificador técnico (nome de tag) é o `InputMemo` + `FormataTexto(texto, False, N)`.

---

## 6. O padrão de um `model`

Molde: `model/model.vendedor.pas` (328 linhas, o menor completo). Todo model segue isto:

```pascal
TVendedorModel = class(TInterfacedObject, IVendedorModel)
  constructor Create;
private
  FBusca: string;
  FAcao: TAcao;            // acNill, acNovo, acEditar, acExcluir, acRestaurar
  FVendedor: IVendedor;
public
  function busca(AValue: string): IVendedorModel;         // fluente
  function acao(AValue: TAcao): IVendedorModel;           // fluente
  function vendedor(AValue: IVendedor): IVendedorModel;   // fluente
  function find(AValue: integer): IVendedor;              // inexistente = ID 0, sem erro
  procedure get(ABuf: TBufDataset);                       // listagem → CopyFromDataset
  procedure getBusca(ABuf: TBufDataset; ACampos: array of string; ALimite: integer = 30);
  function count: Integer;
  function Repetido: boolean;                             // RibaDB.ExisteValor
  function salvar(out AID: integer): boolean; overload;
  function salvar: boolean; overload;
end;
```

### 6.1 O esqueleto de todo método que toca o banco

```pascal
var
  auxDB: TRibaDB;
begin
  auxDB := nil;                                  // sempre, antes do try
  try
    auxDB := TRibaDB.Create;                     // uma conexão própria (AutoCommit = False)
    try
      with auxDB.Query do
      begin
        if Active then Close;
        SQL.Clear;
        SQL.Add('...');                          // SQL.Add: bloco inteiro na entrega
        ParamByName('X').AsInteger := ...;
        Open;   // ou ExecSQL
      end;
      auxDB.Conexao.Commit;
      Result := True;
    except
      on E: Exception do
      begin
        auxDB.Conexao.Rollback;
        raise Exception.CreateFmt(string.Join(#13, ['%s - %s: Linha: %s', 'Erro ao ...!', 'Erro: %s']),
          [Self.ClassName, {$I %CURRENTROUTINE%}, {$I %LINE%}, E.Message]);
      end;
    end;
  finally
    FreeAndNil(auxDB);
  end;
end;
```

Regras embutidas nesse esqueleto:

- **`TRibaDB` criado e destruído por método.** Não há conexão global.
- **Crítica antes do `try`**, com `Riba.Aviso(Format('%s - %s: Linha: %s', [ClassName,
  {$I %CURRENTROUTINE%}, {$I %LINE%}]), 'mensagem em português')` e `Exit` — a mensagem diz
  ao usuário o que faltou e ao suporte onde foi.
- **Exceção real sobe re-empacotada** com classe, rotina e linha; quem exibe é o
  `OnException` do `ApplicationPropertiesPrincipal`.
- **`salvar` decide pelo `FAcao`**: `acExcluir` e `acRestaurar` são soft delete
  (`ATIVO = FALSE/TRUE`) na maioria das tabelas; `acNovo` usa `INSERT ... RETURNING(ID)` +
  `Open`; `acEditar` usa `UPDATE ... WHERE ID = :ID` (e `AND VERSAO = :VERSAO` onde há trava
  otimista — cap. 8).
- **Listagem entrega `TBufDataset`** por `ABuf.CopyFromDataset(auxDB.Query)`; a view só liga
  o `DataSource`.
- **Auditoria depois do `Commit`**, nunca dentro da transação: o `AuditoriaModel.registra`
  tem conexão e commit próprios e nunca levanta exceção.

### 6.2 Cursor no `Query`, escrita no `Query2`

Para percorrer e gravar na **mesma transação** sem abrir segunda conexão: laço no `Query`,
`Query2` com o SQL montado **uma vez antes do laço**, só parâmetros mudando, commit único no
fim. Precedentes: `model.venda_item.gravaDoCarrinho`, `model.nf`,
`EntradaXmlModel.adicionaEstoque`.

### 6.3 O que o model não faz

- Não chama outro model que escreva na **mesma tabela** com a transação aberta (cap. 8 — trava
  o app).
- Não enxerga outro model por `uses` — só pelas interfaces do `RibaCore`. Por isso existem
  **cópias literais de propósito** (`CustoAquisicao` em `model.entrada_xml` e
  `model.entrada_xml_item`; `EANDoXML`/`IDProdutoPorEAN` em `model.entrada_xml` e
  `model.nf_import`) — **mexeu numa, mexa na outra** (`§ 4.1`). As constantes compartilhadas
  foram para o `RibaTypes` por isso.
- Não serve para **importar**: os `adiciona`/`altera` dos filhos fiscais chamam
  `NFEmEdicao`/`CTEmEdicao`/`MDFEmEdicao` (só situação 0 e 3), e documento importado nasce
  em 2 ou 4. `model.nf_import`, `model.cte_import`, `model.mdf_import` gravam as filhas por
  SQL próprio, repetindo cada crítica com outro desfecho (pula e conta em `Ignorados`).

### 6.4 Onde mora a SQL de relatório

No **model da entidade**, não numa `model.relatorio`: `getVendidosPorVendedor` e
`getVendidosPorProduto` em `model.venda_item`; `getListaCompras` em `model.produto`;
`getImpressao` em `model.pedido`; `getCarne` em `model.parcela`. Dataset **plano, todo
string, já formatado**, com totais por função de janela (`PARTITION BY` / `OVER ()`) — assim
o `.lrf` só imprime texto e sai pelo `PrincipalView.ImprimeRelatorio`, que só quer um
`TDataSet`.
⚠ Quando vários relatórios dividem o **mesmo** `TBufDataset` (a Central), o model começa por
`ABuf.Clear` — `Close` não destrói os `TField` e o dataset reabre com a estrutura do relatório
anterior (`§ 14.7`).

---

## 7. O padrão de uma `view`

### 7.1 Frame × diálogo

- **Frame de tela cheia** = `class(TPadraoView)` (`TFrame`, em `RibaCore.pas:1818`).
  Herda `Iniciar` (abstrato — é onde a tela lê `ParamViewID`/`ParamViewAcao` e carrega),
  `ID`/`Acao`, `BufComboKey`, `LigaHintsDosCampos`, `SugereUFMunicipioPeloCEP`, e os
  handlers **published** `Padrao*` que aparecem no Object Inspector.
- **Diálogo** = `TForm` (`view.busca_*`, `view.input_*`, `view.mdf_encerra`, ...).
  ⚠ **Não herda nenhum `Padrao*`** — a lista do OI vem vazia desses nomes e o comportamento
  tem de ser copiado para dentro da unit. Ganha `KeyPreview` de graça pelo estilizador.
  Aberto sempre em **variável local**, resultado lido antes do `FreeAndNil`, **sem
  `Application.ProcessMessages` antes do `ShowModal`** (cap. 11). A única global de janela do
  projeto é a `PrincipalView`.

Diferença que muda o comportamento de tecla: **`TForm` modal escapa** da `ActionListPrincipal`
e do `ACBrEnterTab` (os dois só agem no form principal); o frame não.

### 7.2 O `view.principal` é o dono de tudo

- **`TViews`** (enum em `view.principal.pas:50`) lista toda tela navegável. Frame que guarda a
  origem (`FOrigemView: TViews`) precisa de `view.principal` no `uses` da **interface** — não
  fecha ciclo, porque o principal usa as telas só na `implementation`. `TViews` **não pode**
  aparecer em interface do `RibaCore`.
- **`InstanciaView(AView)`** é **assíncrona**: só faz `Application.QueueAsyncCall(@FInstaciaView, ...)`.
  ⚠ O handler que navegou ainda não terminou quando a troca acontece; `FFrame` e `ViewAtual`
  são os da tela velha até lá. Handler que grava e navega precisa de trava própria
  (`FOcupado` do caixa, `FFechandoVenda` do fechar venda) — sem ela, a tecla que já estava na
  fila entra na tela velha de novo (`§ 4.5`). E `Application.ProcessMessages` **drena** a fila
  de async e libera o `FFrame` debaixo da pilha.
- **Parâmetros de navegação**: `ParamViewID`, `ParamViewAcao` (zerados no `finally` do
  `FInstaciaView`), `ParamViewRetorno` (**permanente**: "para onde a listagem vai ao fechar"),
  e o par de **uso único** `ParamViewOrigem` + `ParamViewOrigemID` ("de onde eu vim", com ID,
  zerado no mesmo `finally`). A tela de destino lê no `Iniciar` e guarda em campo próprio;
  `VoltaParaOrigem: boolean` devolve `False` quando ninguém marcou.
- **Atalhos são centralizados aqui, não nos frames.** `ActionListPrincipal` (F1–F12, Enter,
  Esc, ↑/↓, Ctrl+Enter — `ShortCut` no `.lfm`) → `ActionF1Execute`..`ActionCtrlEnterExecute`,
  cada um um `case ViewAtual of` que dá `.Click` no botão da tela ativa. Letras, dígitos, `*`,
  espaço e aceleradores `&` no `FormKeyPress`. **Botão novo com atalho liga em DOIS lugares:**
  o `Hint`/`Caption` no `.lfm` **e** o `case` no principal — esquecer o segundo é tecla morta.
- **`ImprimeRelatorio(AArquivo, ADados)`**: `Report.LoadFromFile('.\report\' + AArquivo)` **a cada
  impressão** (salvar o `.lrf` antes de reimprimir), zebra pelo `RelatorioEnterRect` (procura um
  `TfrShapeView` chamado exatamente `ShapeZebra`).
- **`ImageList24_botoes`**: 43 imagens (Apêndice B). Anexar no fim é seguro; inserir no meio
  troca ícone em toda tela, sem erro. `ImageIndex` também é atribuído em código (0, 5, 6, 8, 17).

### 7.3 Teclado: quem come o Enter

Dois interceptadores no principal, os dois **antes** do controle focado:

- `ActionListPrincipal`: `ShortCut` de `TAction` é resolvido no **KeyDown** do form. A tecla é
  consumida **mesmo quando o `case ViewAtual` não tem ramo** para a tela atual.
- `ACBrEnterTab` (`EnterAsTab = True`): hooka o `OnKeyPress` e troca **todo** `#13` por
  `SelectNext`, **sem exceção para `TMemo`**.

Padrão adotado: **tela de digitação NÃO liga a `ActionEnter`** — trata Enter especial em
`OnKeyDown` local (`if Key <> VK_RETURN then Exit; Key := 0; <ação>;`). A `ActionEnter` fica
para listagem/consulta, onde Enter tem significado único. Memo em frame quebra linha só por
**Ctrl+Enter**, que o `ActionCtrlEnterExecute` traduz em `LineEnding` quando o foco está num
`TCustomMemo` editável.

### 7.4 Botões: `TBotao`

Fonte em `D:\Documents\GitHub\RibaSoftComponentes\libBotao.pas`. Descende de `TCustomPanel`.
Existe porque duplo clique em PC lento duplicava gravação no sistema antigo:

- `FProcessandoClique` barra reentrância enquanto o `OnClick` roda; `IntervaloClique`
  (700 ms; 0 desliga) barra o segundo clique da fila; `TextoAguarde` ("Aguarde...",
  "Salvando...", "Transmitindo...") é pintado por cima do `Caption` enquanto roda.
- `ShowHint` já vem ligado — só preencher o `Hint`. `TSpeedButton` da LCL precisa de
  `ShowHint = True` + `ParentShowHint = False`.
- ⚠ **O mesmo `TBotao` não aceita segundo clique enquanto o handler não volta**, nem com
  `ProcessMessages` dentro. Mata o padrão "botão que vira Parar". Saída:
  `Application.QueueAsyncCall(@Executa, 0)` — o clique termina e o trabalho roda em seguida.
- ⚠ **`TControl.Click` ignora `Enabled`.** Todo atalho passa por um `Aciona(ABotao)`:
  `if ABotao.Enabled then ABotao.Click;` — molde `TNFCadastroView.TeclaFuncao`.
- ⚠ **Legenda trocada em runtime engole o prefixo do atalho** (`F6 - Ignorar` → `Ignorar`).
  Onde a legenda alterna, o prefixo entra nas duas pontas do `if`.
- Quem "volta" é sempre o `btnFecha`/`btnFechar`, `TSpeedButton` 30×30 com `Glyph` embutido.

Hints padrão: `'F1 - Novo'`, `'F2 - Editar'`, `'F3 - Salvar'`, `'F4 - Cancelar'`,
`'F5 - Excluir'`, `'F6 - Imprimir'`, `'F7 - busca'`, `'C - Calculadora'`,
`'Ctrl + Enter - Ação'`, `'Fechar - ESC'`. Ao escolher F-key nova, olhar **as duas listas**: o
que o projeto usa para aquela ação e o que a tela irmã usa; brigando, a irmã ganha a ação que
existe nas duas e a outra vai para tecla livre nas duas (foi assim que o Excluir da entrada de
XML caiu no F12 e o do pedido no F5).

### 7.5 Campos: o toolkit `Padrao*`

| Controle | Evento | Handler |
|---|---|---|
| `TEdit` valor | `OnKeyPress` / `OnExit` | `PadraoValorKeyPress` / `PadraoValorExit` (2 casas) ou `PadraoValor4Exit` |
| `TEdit` número | `OnKeyPress` / `OnExit` | `PadraoNumeroKeyPress` / `PadraoNumeroExit` ou `PadraoNumeroVazioExit` |
| `TEdit` documento | `OnKeyPress` / `OnExit` / `OnEnter` | `PadraoDocKeyPress` / `PadraoCNPJ_CPF_Exit` / `PadraoColaCNPJ_CPF` |
| `TEdit` texto | `OnExit` | `PadraoTextoExit` (maiúsculas) ou `PadraoTextoLivreExit` |
| `TEdit` fone / CEP | `OnExit` | `PadraoFoneExit` / `PadraoCEP_Exit` |
| `TComboBox` | `OnEnter` **+** `OnKeyPress` | `PadraoComboBoxEnter` + `PadraoComboBoxKeyPress` — sempre o **par** (busca incremental por prefixo; município tem ~5.500 itens) |

- `PadraoValorExit` serve para percentual também (2 casas); só muda o `MaxLength`.
- Handler próprio pode **reusar** o padrão: `PadraoValorExit(Sender)` de dentro do seu
  `OnExit`. ⚠ Nunca com `nil` — ele converte o `Sender` para `TEdit` na primeira linha.
- ⚠ `PadraoNumeroKeyPress` filtra o **digitado**; **Ctrl+V não passa por `OnKeyPress`**. Quem
  limpa código colado é o `OnExit` e, por último, o setter do dbo. E o **`MaxLength` corta
  ANTES da limpeza**: campo de NCM/CEST tem `MaxLength = 14`, com folga para a pontuação.
- `Riba.ComboBoxObjeto(combo)` devolve **-1** sem seleção e o código quando há — então
  **código 0 é distinguível de vazio**, e o teste para combo cujo zero é legítimo é `< 0`.
- ⚠ `CarregaComboBoxUF` termina selecionando **PR**; `CarregaComboBoxTributacoes` termina
  selecionando o **ID 1**. Carregador que já escolhe um item não se corrige por fora sem olhar
  quem ele seleciona — `ItemIndex := 0` depois dele cai no primeiro alfabético
  (DEVOLUCAO DE VENDA, à qual nenhum produto aponta).
- `MaxLength` dos edits fica **folgado de propósito**: o usuário precisa conseguir digitar
  antes de o sistema criticar.

### 7.6 Grades: `TDBGrid`

- **Colunas montadas em código** no `Create`: `Columns.Add.FieldName`, depois o bloco de
  títulos/alinhamento (anda por `Inc(I)`), depois as larguras no `FrameResize`. **Coluna nova
  mexe nos três lugares**, todos silenciosos.
- ⚠ **Coluna invisível no meio quebra o `Inc(I)`**: com oculta no meio, índice explícito
  (molde `view.contas_pagar`).
- Largura elástica: `Width - SCROLL_WIDTH - (fixas) - DBGridDados.Scale96ToFont(DEFINDICATORCOLWIDTH)`
  — o indicador ocupa faixa escalada por DPI; `ColWidths`/`ColCount` são `protected` e o
  `TDBGrid` não republica. Testar toda grade nova com a janela no mínimo (`Constraints.MinWidth = 1000`).
- **Valor e quantidade centralizados** — padrão do projeto inteiro, só existe no código.
- **Cor da linha: `PintaLinhaGrade(grade, AState, fundo, fonte)`** no `OnPrepareCanvas`, com
  `if gdFixed in AState then Exit` na primeira linha. Fora do foco: fundo claro + fonte escura;
  em foco: invertem. `clNone` = não toca. É rotina de unit no `RibaCore` (não método do
  `TPadraoView`) porque `TContasPagarDetalheView` é `TForm`. Cores em `RibaTypes`.
- **Coluna de seleção é `VARCHAR(1)` com `'X'`**, nunca booleano: `CAST(' ' AS VARCHAR(1)) AS SEL`,
  grade `ReadOnly := True`, alterna no `OnCellClick`. Evita `dgeCheckboxColumn`, o
  `SwapCheckBox` que alterna antes do evento, e o `dgEditing` das opções padrão.
- **Grade não usa `OnDataChange`** — o `Carrega*` é dono único do `Enabled` dos botões. Dois
  donos para um estado é bug esperando data.
- Laço que percorre o `BufDados` **move o cursor da grade**: guardar `RecNo`, `DisableControls`,
  devolver no `finally`. `Riba.SomaBuf` deixa o cursor no **fim** — `First` depois.
- ⚠ `DataSource` apontando para o `Buf*` errado deixa a grade **plausível**, não vazia
  (`TColumn` resolve por `FindField`, `nil` = coluna em branco), e o Excluir apaga sempre o
  primeiro registro. Varredura no Apêndice A.

### 7.7 Combos com cache

`TRibaDB.CacheCombo(chave, SQL, campoTexto, campoCodigo [, campoDescr])` em variável de
classe; os `CarregaComboBox*` viraram `Clear` + `Items.AddStrings(...)`. Chaves: `UF`,
`MUNICIPIO|<uf>`, `TIPO_VENDA|CAD/SEM`, `FORMA_PAG|1/2/3/TODAS`, `BANDEIRA_CARTAO`, `TRIB`,
`CFOP`, `CENQ_IPI`, `CCLASSTRIB|<modelo>`. ⚠ **Alterou a tabela, chama `LimpaCache`** — já
ligado em `CriaMunicipios`, `CriaCFOP`, `CriaCENQ_IPI`, `TTribModel.salvar`. Os combos de
**filtro de relatório** (`CarregaComboBoxVendedorFiltro`, `...FornecedorFiltro`) não usam cache
e trazem os **inativos** — relatório olha para trás.

### 7.8 Navegar para um cadastro e voltar

Mecanismo genérico: a origem marca `ParamViewOrigem`/`ParamViewOrigemID` **só quando
`FID > 0`** (sem rascunho não há para onde voltar), chama o controller com `.volta(False)`
(a `function volta(AValue: boolean)` existe na classe **e na interface** do `RibaCore`, com
`FVolta := True` no `Create`); o destino copia no `Iniciar` e `VoltaParaOrigem` decide.
Molde: `btnEditaDadosClienteClick` e o F4 do `view.nf_cadastro`.

### 7.9 Labels que somem sem deixar vão

`Visible := False` **fecha o buraco** — mas só se cada label estiver **ancorado no anterior**
(corrente de `AnchorSide`) e com `Anchors` contendo `akLeft`/`akTop`. Label em posição fixa
fica invisível **com o vão no lugar**. Primeira aplicação: capa da aba Início do
`view.cte_cadastro`, com um `MostraLabel(ALabel; APrefixo; AValor)` que põe `Caption` e
`Visible` juntos.

---

## 8. O banco de dados

### 8.1 Cada `TRibaDB` é uma conexão

`TRibaDB.Create` faz `TZConnection.Create(nil)` com `AutoCommit = False` — e **não conecta**:
o ZEOS conecta no primeiro `OpenSQL`. Duas instâncias = duas transações independentes.

⚠ **Model com transação aberta não pode chamar outro model que escreva na MESMA tabela.** A
segunda conexão espera um commit que só viria depois da chamada voltar: **o programa trava
sozinho, sem erro, sem exceção**. Foi por isso que `EntradaXmlModel.adicionaEstoque` faz o
`UPDATE PRODUTOS` na própria transação em vez de chamar `ProdutoModel.AjustaEstoque`; e
`PedidoItemModel.AtualizaCabecalho` roda na conexão do item. Chamar outro model que escreve em
**outra** tabela é seguro — mas o que ele gravar **sobrevive ao rollback** do chamador.

### 8.2 Esquema: `CriaTabelas` + `AtualizaColunas`

O esquema é criado e migrado **em código**, em `utils/RibaDB.pas`, em toda abertura:

- `CriaTabelas`: os `CREATE TABLE` (idempotentes) e os **seeds** (tributações, `TRIB_INTER`,
  usuário, vendedor GERENTE, cliente 1 CONSUMIDOR SEM CADASTRO, fornecedor 1 PADRAO).
- `AtualizaColunas` (chamado no fim do `CriaTabelas`): a lista de `AdicionaColuna('TABELA',
  'COLUNA', 'TIPO'); // dd/mm/aaaa` (`ALTER TABLE ... ADD` idempotente via `ExisteColuna`, que
  lê o esquema inteiro numa consulta só) e `AlteraColunaTamanho` (só alarga).

**Regra combinada:** coluna nova entra **nos dois lugares** — no `CREATE TABLE` e no
`AtualizaColunas`, com a **data no comentário**. Banco criado depois da data já nasce com a
coluna; a linha do ALTER é apagada quando não sobrar banco anterior a ela.
⚠ O tipo do `AdicionaColuna` **não pode ter `NOT NULL`** — em tabela com dados o ADD falharia.
⚠ Seed só roda quando a tabela é **criada**: quem já tem a `TRIB_INTER` não recebe as 5 regras
ao atualizar (`§ 18.4`).
⚠ **Nome de coluna que seja palavra comum de SQL passa pelo `isql` antes** — `LOCAL` virou
`PASTA`, `MOD` virou `MODELO`.

### 8.3 Trava otimista: `VERSAO`

`PRODUTOS`, `CLIENTES`, `FORNECEDORES`, `USUARIOS` e outras têm `VERSAO INTEGER DEFAULT 1`. O
`salvar` faz `WHERE ID = :ID AND VERSAO = :VERSAO ... RETURNING ID` e trata `IsEmpty` como
conflito. **`UPDATE` por fora do `salvar` incrementa a `VERSAO` se mexer em coluna que a tela
edita** (custo, venda) — só o saldo de estoque não incrementa (`AjustaEstoque`), porque a
venda mexe nele o tempo todo.

### 8.4 Soft delete e auditoria

- Cadastros: `ATIVO = FALSE` (excluir) / `TRUE` (restaurar). Pagamentos: soft delete com
  auditoria. Exceções com `DELETE` físico: NF (só rascunho/rejeitada, e só Suporte),
  `CAIXA_ITENS`, `VENDA_ITENS` (por isso a auditoria lê os dados **antes** do `DELETE`).
- A tabela `AUDITORIA` **nunca é apagada** — nem pela migração (`§ 17.5`). O que se registra e
  onde (model × tela) está no `§ 12.7` e `§ 17`: uma linha por **registro**, só o que **mudou**,
  **depois do commit**, e a senha nunca entra na linha.

### 8.5 Convenções que o Firebird impõe

- **`UNIQUE` composta e `NULL`** (medido no Firebird 5.0): só a chave **inteiramente nula**
  fica fora do índice; `('123', NULL, NULL)` duas vezes **viola**; string vazia **não é** NULL.
  O cadastro grava `ParamByName(...).Clear` no vazio; a base migrada tem string vazia onde o
  cadastro tem NULL. `TRibaDB.ExisteDoc` monta o `WHERE` em Pascal com `IS NULL` escrito no SQL
  para o que está vazio.
- **Contadores em tabela, não em `Config`** quando há mais de um terminal (`DFE_NSU`): o
  `Config` fica em cache na abertura.
- `CAIXA_ITENS.TOTAL` é **COMPUTED** (`ROUND((VALOR * QTD) - DESCONTO, 2)`) — somar ele no
  SQL já dá o líquido; refazer em Pascal diverge.
- Agregado que depende de agregado precisa de subconsulta (`ParcelaModel.diasAtrasoMaximo`).
- `COALESCE` em coluna anulável antes de comparar — `NULL <= 10` é UNKNOWN e some da lista.
- Enum gravado como inteiro (`.cfg`, coluna, `TIniFile`): **valor novo entra no FIM** do enum
  (`TTipoConexao` ganhou `tcRedeLinux` no fim; `TPermissao` idem).

### 8.6 Tabelas de apoio e sua atualização

`MUNICIPIOS`, `NCM`, `CEST`, `CFOP`, `ANP`, `CBENEF`, `CCLASSTRIB`, `IBPT` são carregadas dos
arquivos de `data/` pelos loaders `Cria*` do `RibaDB`, que a `thread.inicio` dispara **1×/dia**
(`CFG_ULTIMA_VERIF_TABELAS`) quando o **hash SHA1** do arquivo local diverge do servidor
(`TRibaApi.AtualizaArquivo`), ou quando a tabela está vazia (`TabelaVazia`/`ColunaVazia`).
**Só o terminal 1 recarrega sozinho**; os outros baixam o arquivo e recarregam pelo botão
Configuração › Dados › **Atualizar Dados** (`§ 3`). O mesmo motor atualiza `Schemas.zip`,
`report.zip` (desligável por `Config.AtualizarReports`, por máquina) e o próprio `Varejo.zip`.
Detalhe dos arquivos, fontes oficiais e armadilhas de cada um: cap. 21.

### 8.7 Firebird: modos de conexão e os arquivos de dentro do `.exe`

`TTipoConexao = (tcWindowsLocalEmbarcado, tcWindowsLocalInstalado, tcRedeWindows, tcRedeLinux)`;
`Config.EmRede` cobre os dois últimos. Os cinco campos da conexão são gravados juntos
(`Config.GravaConexao`) e valem no **próximo início**; a **senha do banco fica fora da tela**,
só no `.cfg`. `fbclient.dll`, `firebird.msg`, `gbak.exe`, `gfix.exe`, `isql.exe`,
`libcrypto-1_1.dll` e `libssl-1_1.dll` vêm de **dentro do `.exe`**
(`RibaCore.lrs`, extraídos pelo `TRiba.Create` só se não existirem) — o `FB504-embarcado.zip`
do servidor não os traz, e está certo assim (`§ 4.7`). **Backup em rede foi tirado do cliente**:
em `tcRede*` o sistema não faz backup nenhum; quem cuida do servidor é o servidor.

---

## 9. Convenções de código

- **Português** em identificadores e comentários. Código legível por humanos; comentário diz
  o **porquê**, não o quê.
- Cabeçalho de método: linha `//==== NOME DO MÉTODO ====\\` centralizada a 128 colunas,
  seguida (quando há o que explicar) de 1–4 linhas de comentário sobre a intenção e a
  armadilha. Rodapé de unit: `//=====...=====\\` antes do `end.`.
- Prefixos: `F*` campo privado, `A*` parâmetro, `aux*` variável local, `I` para contador
  de laço curto. `T*`/`I*` por camada (cap. 4).
- Uma unit começa com `unit x; {$mode ObjFPC}{$H+}` na mesma linha. `uses` da interface
  mínimo; o que só a implementação precisa vai no `uses` da implementação (é assim que
  `view.principal` ↔ views não fecham ciclo).
- ⚠ **Unit usada por outra não é reexportada**: quem usa `TAcao`, `CFG_*`, cores, põe
  `RibaTypes` no próprio `uses`. `ftString` exige `DB`.
- ⚠ **Campo declarado depois de método na mesma seção de visibilidade não compila** em
  objfpc (Delphi aceita): campo novo ancora no **último campo** da seção, ou abre `private` novo.
- ⚠ **`{$mode objfpc}` exige `overload` em TODAS as versões** de um método sobrecarregado.
- Funções que devolvem `record` **inicializam o `Result` na primeira linha** — o FPC só zera
  campos gerenciados.
- Comentário **nunca começa com a palavra `todo`** (nem `done`): o parser de To-Do do Lazarus
  recolhe como tarefa. Reescrever a linha (`Cada evento...`, `qualquer caminho...`).
- Constantes de regra ficam no `RibaTypes` (`DIAS_ATRASO_BLOQUEIO = 30`,
  `SUPORTE_JANELA_SEG = 420`, `PRODUTO_GRUPO_PADRAO`, `CTEICMS_*`, `PEDIDO_TIPO_*`, `DEVREF_*`).
- Bloco novo de unit grande vai **no fim da área do assunto**, não onde couber: as funções do
  CT-e entraram contíguas depois do `ExportaNF` no `RibaACBr`; espalhar é o que torna um
  arquivo de 11 mil linhas impossível.
- `try/finally` novo **não engole** bloco antigo só para alinhar — entrega em bloco novo vale
  mais que reindentar 200 linhas conferidas.
- **Dono único para cada estado**: campo derivado tem Edit `ReadOnly` e **um** método que
  escreve nele (`RecalculaVTotDFe`), chamado de todos os pontos que invalidam a conta. A
  pergunta que separa "recalcular ao carregar" de "não recalcular" é **se o campo aceita
  digitação**, não se é calculado.
- O `Ctrl+D` (Source Formatter) do Lazarus reformata o arquivo inteiro — reindenta, baixa
  `String`→`string`, transforma linha `//` solta em branco. É o padrão do autor e **não se
  reporta como achado**; conferir só os trechos entregues.

---

<!-- ============================================================================ -->
<!--  PARTE III                                                                   -->
<!-- ============================================================================ -->

# Parte III — A linguagem e suas armadilhas

Tudo o que segue foi **provado** — com `fpc.exe` num `.pas` isolado, com `isql` num banco
descartável, ou lendo a fonte da LCL/FPC/ACBr — e não suposto. Quando a memória e o teste
discordaram, o teste venceu; vale repetir o teste antes de confiar neste capítulo.

## 10. FPC / Object Pascal: tipos e strings

### 10.1 `currency` só é exato enquanto ninguém o promove

1. **`Abs(currency)` devolve ponto flutuante.** Não há overload de `Abs` para currency; a
   expressão inteira vira double. `Trunc((Abs(x) * escala) + 0.5)` fazia 4,6 % dos valores
   terminados em `...5` **descerem** (4,055 → 4,05). Custou semanas de rejeição de NF.
2. **`currency × currency` corta o produto em 4 casas.** `0,3335 × 19,99 = 6,666665` chega
   como `6,6667`; o Firebird multiplica `NUMERIC(15,4)` em **8 casas** — 1 centavo de
   divergência em 1 de cada 232 pares na faixa de balança.
3. **A mesma conta em SQL puro e em Pascal dá números diferentes** — quando vários caminhos
   gravam a mesma coluna de dinheiro, todos calculam do mesmo lado (o `restaura` saiu do SQL).

**Como fazer moeda exata:** `Riba.Arredonda` trabalha no `int64` interno do currency
(`PInt64(@x)^`, escala 10⁴), sem ponto flutuante; o overload `Arredonda(AQtd, AValor)` faz o
produto em escala 10⁸. **Somar currency é exato; só multiplicar e dividir arredondam.**
⚠ `Arredonda(<currency>, 2)` resolve para a versão `(double, byte)` — conferir sempre a
resolução de `overload`, ela é impossível de adivinhar lendo.

### 10.2 Conjunto só aceita ordinal 0..255

`if cStat in [110, 301, 302]` **não compila** (`4109 range check error while evaluating
constants`); `in [0, 100, 150]` na linha de cima passa — parece intermitente e não é. cStat
da SEFAZ passa de 255 o tempo todo: comparação direta. **`-1 in [0, 20, 40]` é seguro** e
devolve `False` (provado com `{$R+}{$Q+}`).

### 10.3 Nenhum type helper em `.Text` / `.Caption`

`TCaption = TTranslateString = type string` — tipo **distinto**. `EditX.Text.Trim`,
`.Contains`, `.StartsWith`, `.IsEmpty` **não compilam**. Usar `Trim(EditX.Text)`,
`Pos('\', EditX.Text) > 0`, ou variável `string` local. A regra é do **tipo**, não do método.
(`Exception.Message` é `string` de verdade — `E.Message.Contains(...)` compila.)

### 10.4 `ftString` conta bytes

`FieldDefs.Add('CAMPO', ftString, N)`: `N` é byte. `'NÃO'` precisa de **4**, `'AÇÃO'` de 6.
Se `'SIM'` sai inteiro e `'NÃO'` vira `'NÃ'`, é isso. O mesmo vale para `Length` na guarda de
parâmetro do Firebird (cap. 12) e para o corte de 25 posições do `TXITENS.TXT` da balança.

### 10.5 Pequenos sequestros de identificador

- **`with auxDB.Query do` esconde `System.Delete`, `Insert`, `Append`, `Next`, `Close`,
  `Open`, `First`, `Last`, `Post`, `Cancel`** pelos do `TDataSet` (`3026 Wrong number of
  parameters` + `Found declaration` apontando `dataset.inc`). Manipulação de string não tem o
  que fazer dentro do `with` — tirar de lá.
- **`Windows` depois de `SysUtils` no `uses`** (`RibaTools`) faz `DeleteFile(string)` resolver
  para a API (`4025 Got AnsiString, expected PChar`): `SysUtils.DeleteFile(...)`. Idem
  `CopyFile`, `FindClose`, `MoveFile`.
- **`Format(..., [iif(...)])`**: o `IIf` do ACBr devolve `Variant`; em `array of const` não é o
  mesmo que string. Variável local antes do `Format`.

### 10.6 `StrToInt*Def` não prova formato

Chave de acesso tem 44 dígitos; `Int64` cabe 19. `StrToInt64Def(chave, -1)` devolve o
**default**, indistinguível de "tem letra". Para perguntar "é só dígito?", testar caractere a
caractere. E conferir o que o default significa na consulta: `StrToIntDef(chave44, 0)` = 0
num `WHERE NNF = :P` não acha nada — inofensivo só porque nenhum documento tem número 0.

### 10.7 `TCSVDocument`: uma aspa solta engole linhas

O `TCSVParser` trata qualquer aspa como abertura de campo, mesmo no meio do valor, até a
próxima aspa do arquivo. Foi o furo dos 3.332 NCMs que nunca entravam
(`27101921;Gasóleo" (óleo diesel);...`). Desligar com `QuoteChar := #1` +
`EqualColCountPerRow := False`. **`#0` não serve** (é o fim de arquivo do parser → laço
infinito). **Quando não desligar:** `ibpt.csv` e `cest.csv` têm aspas bem formadas e `;`
dentro delas. ⚠ Com `QuoteChar := #1`, o arquivo **não pode conter o byte 0x01** — um
`re.sub` do Python com `\1` gerou 13 deles e **183 CEST sumiram** sem erro.

### 10.8 Caminho Windows em arquivo gerado por script

`view\view.x.pas` numa string Python/bash vira `view` + **0x0B** + `iew` (`\v` é vertical
tab). O `.lpi` compilou verde (as units entram pelo `.lpr`), quem viu foi a IDE. Escrever o
script em arquivo com heredoc literal e montar a barra por `chr(92)`; conferir com `repr()`
ou contando o byte 0x0B, nunca só olhando.

---

## 11. Lazarus / LCL: o que compila verde e quebra depois

Família única: **o `.lfm` liga componentes e eventos por TEXTO, e o compilador não confere
nada disso.** O `{$R *.lfm}` só empacota; quem lê é o streaming, em runtime, ao abrir a tela.

### 11.1 As quatro do `.lfm`

1. **Campo publicado sem componente no `.lfm` = `nil`.** Sobra de campo é silêncio; morre no
   primeiro toque (`Access violation reading address 0`).
2. **Handler escrito e não ligado** = nunca roda. Foi o `btnOK` do `view.input_memo`. Item de
   menu novo: o `OnClick` do `.lfm` é o passo que some.
3. **Handler apagado do `.pas` com o `.lfm` ainda apontando** = estoura só ao abrir aquela
   tela. Antes de apagar handler, varrer os `.lfm` pelo nome.
4. **`DataSource` apontando para o dataset errado** = grade plausível (linhas em branco na
   quantidade do dataset errado) e o Excluir apagando sempre o primeiro. Uma propriedade no
   OI conserta (`DataSourceVol.DataSet = BufPag` ficou meses assim).

Mais duas irmãs: **componente do `.lfm` sem campo publicado** (silêncio; vale o `grep` ao
fechar tela) e **classe do `.lfm` ≠ tipo do `.pas`** (`Class "TXxx" not found` na abertura — na
paleta o clique pegou `TPanel` onde devia ser `TMemo`). E **propriedade escrita à mão no
`.lfm` que não é `published`** (`ParentFont` no `TBotao`) = `Unknown property` ao abrir; conferir
por RTTI (`TypInfo.GetPropInfo`) antes. Varreduras automáticas no Apêndice A.

### 11.2 O Object Inspector e o stub duplicado

Ligar evento pelo OI quando **já existe** método com aquele nome mas assinatura incompatível
(`OnDataChange` exige `(Sender; Field: TField)`; `OnKeyDown` exige `(Sender; var Key; Shift)`) faz
a IDE criar um **stub novo e vazio** e manter o antigo. Em objfpc isso é overload implícito e
compila; o `.lfm` casa **pelo nome** (`TObject.MethodAddress` devolve a primeira entrada) e
qual fica ligado depende da ordem da tabela. As buscas do projeto usam `FormKeyDown(Sender;
var Key: Word)` — dois parâmetros — e funcionam só por esse casamento por nome.

**A regra da setinha depende do estado, e é o inverso nos dois casos:** método que **ainda não
existe** só nasce digitando o nome na célula + Enter; método que **já tem corpo** liga pela
**setinha**, depois de declarado na classe — nunca por duplo clique. Corpo colado sem
declaração dá `3047 method identifier expected` e uma cascata de `5000 Identifier not found`
para cada símbolo do corpo: **ler o primeiro erro, não a lista**.

Por isso componente novo com handler novo são **três passos**: (1) componentes no designer,
(2) código com os handlers declarados, (3) ligar eventos no OI — handler que ainda não existe
**não aparece na lista** do OI, e campo sem evento compila verde.

### 11.3 Eventos que disparam (ou não) por código

- **`TRadioGroup.ItemIndex` atribuído por código DISPARA `OnClick`/`OnSelectionChanged`**
  (`radiogroup.inc`, compatibilidade Delphi) — diferente do `TComboBox`. Padrão: flag
  `FTrocandoXxx` em volta da atribuição e `if FTrocandoXxx then Exit;` no handler.
- **A metade inversa: valor IGUAL não dispara nada** (`if FLastClickedItemIndex = FItemIndex
  then exit`). O `.lfm` grava `ItemIndex = 0`, então o índice 0 é o caso que silenciosamente
  não roda. **Carregar tela por `ItemIndex` chama o handler na mão** (`CarregaConexao` →
  `AplicaTipoConexao`). `OnSelectionChanged` é o mesmo gatilho, só melhor nomeado.
- **`TComboBox.OnChange` só dispara quando o usuário escolhe** — `Riba.ComboBoxObjeto` mexe no
  `ItemIndex` e não passa por ele. É o que impede o `CarregaNFExistente` de disparar a
  pergunta de retributação sozinho (`§ 18.5`).
- **`TControl.Click` ignora `Enabled`** (cap. 7.4).
- `EditNCM.Text := x` dispara `OnChange`, **não** `OnExit` — quem escreve num campo por código
  chama explicitamente o que o `OnExit` faria (`AtualizaDescrNCMCEST`).

### 11.4 Reentrância: `CreateForm` global + `ProcessMessages` antes do `ShowModal`

O padrão antigo `Application.CreateForm(TBuscaX, BuscaXView); ...; Application.ProcessMessages;
BuscaXView.ShowModal;` deixa a tela principal **habilitada** durante o `ProcessMessages`: a
tecla enfileirada (Enter do leitor de código de barras) entra no `ActionEnter`, reentra na
rotina, cria outra janela **na mesma global**, e o `finally` de dentro deixa a global `nil`
para o `ShowModal` de fora → Access violation intermitente. **Corrigido em todo o projeto
(22 lupas + 14 diálogos)**: janela em variável local, sem `ProcessMessages`, globais apagadas.
Varredura: `grep -rn "Application.CreateForm(T" view/` (a variável tem de ser `aux*`) e
`grep -rn "Application.ProcessMessages" view/ utils/`.

O mesmo `ProcessMessages` **drena a fila de async calls** e libera o `FFrame` debaixo da pilha
(cap. 7.2) — a morte não passa pelo `OnException` e parece travamento de máquina.

### 11.5 `TDateTimePicker`

- **Vazio devolve `NullDate = 1.7e+308`**, não zero — passa por `> 0` e `= 0` e estoura no
  `AsDate` do Firebird. Só `DateIsNull` detecta. O único caminho para ficar nulo é a tecla
  **N** dentro do campo. Resolvido globalmente pelo estilizador (`NullInputAllowed := False`);
  a tela que precisa de vazio declara a exceção.
- **`AutoSize` nasce `True` e encolhe o controle DEPOIS do `SetBounds`** — picker criado em
  runtime leva `AutoSize := False` antes, senão o vizinho fica com vão de 70 px.
- `AsDateTime` de coluna nula devolve **zero**: ler com `IsNull` antes de formatar, senão
  imprime `30/12/1899`.

### 11.6 `case` sem o ramo novo

Ao acrescentar valor a um enum, todo `case` sobre ele continua compilando — sem `else`, o valor
novo não faz nada. Ao mexer num enum, `grep` do tipo **e de cada valor antigo**, e visitar todo
`case` (quase aconteceu com `tcRedeLinux` no `VerificaFirebird`).

### 11.7 Miudezas que enganam

- `TUnZipper.OnProgress` manda 0..100 **por arquivo** de dentro do zip — a barra reinicia; não é
  bug. Mostrar o nome do arquivo corrente (`OnStartFile`).
- `TTreeView`: `ShowRoot` tem de ficar `True` (senão nó de primeiro nível não tem sinal de
  expandir); `OnCustomDrawItem` recebe a cor zerada mas **não o estilo** (negrito vaza —
  atribuir `Style := []` nos dois ramos); nó selecionado não recebe cor nossa.
- `TTreeFilterEdit`: limpar a busca colapsa a árvore inteira; buscar número de versão mostra a
  versão sem os filhos — o uso é por palavra.
- Seta ↑/↓ é Action global: tela cuja lista não é `TDBGrid` precisa do próprio ramo no `case`.
- Item de menu condicional precisa de quem o **apague** no mesmo lugar que decide o estado
  (`MenuLogoutSuporte` e o `TimerSuporteTimer`).
- Reiniciar o sistema **não sai de dentro de uma modal**: a tela liga um `Reiniciar: boolean`
  e fecha; quem chama `ReiniciaSistema` é o `MenuSobreClick`, com a modal liberada.
- Reiniciar é o `TReiniciador` (pacote `ribasoft`, solto no `PrincipalView`): abre uma
  instância nova de `Application.ExeName` passando o PID desta e encerra esta; a nova espera
  o PID sair antes do `OnCreate`. Não há executável auxiliar e funciona em Debug
  (`Varejo_debug.exe`). O `OnAntesReiniciar` do form liga `FBackupSaidaOK` e `FecharApp`.
- Destruir o controle **focado** é caminho conhecido de AV: tirar o foco de dentro do painel
  antes de liberar (`LimpaFiltros` da Central).
- `csDropDownList` sem item vazio é rua sem retorno quando vazio é resposta válida.
- Desabilitar `TGroupBox` desabilita os filhos; `AnchorSideXxx.Control` apontando para outra
  aba compila e desloca em silêncio; copiar-colar `GroupBox` deixa renames incompletos.
- `ActivePage`/`TabIndex` regravados pelo designer a cada aba aberta são ruído de diff, não
  achado — a tela fixa a aba inicial no `Create` (`PageControlX.ActivePage := TabSheetY`).

---

## 12. Firebird e ZEOS

### 12.1 ⚠ Parâmetro maior que a coluna dá ERRO, não vazio

Comparar `:BUSCA` contra `VARCHAR(n)` com valor maior que `n` estoura no bind
(GDS 335544914, *expected length n, actual m*, o `-303`). Pior: o **mesmo nome de parâmetro**
repetido contra colunas de tamanhos diferentes (`CPROD = :X OR CBARRA = :X OR CEAN = :X`) recebe
um bind por ocorrência, tipado pela coluna daquela comparação — falha assim que o valor passa
da **menor** coluna. Vale para `CONTAINING` também.

**O guard**: incluir a cláusula da coluna estreita só quando `Length(valor) <= tamanho`
(`Length` em bytes). Não perde resultado: texto de 44 nunca está contido num campo de 14.
⚠ **O guard troca o erro por "não achou" — nunca faz achar.** Colar `33.749.814/0001-82` (18
caracteres) na busca de cliente saía do `CNPJ(14)` pelo guard e sobrava uma busca por razão
social que nunca casa. **O padrão que ficou: dois parâmetros** — `:BUSCA` com o texto como veio
para RAZAO/FANTASIA, `:DOC` com `Riba.LimpaNumeros(FBusca, True)` para documento e telefone,
cada um com o seu guard (`model.cliente`, `model.fornecedor`, `model.dfe`,
`model.entrada_xml`). Ao mexer numa busca multi-campo, perguntar as duas coisas: **estoura?**
e **acha?**

### 12.2 SQL montado por `SQL.Add` não é conferido pelo compilador

`:PLACEHOLDER` sem `ParamByName`, vírgula que faltou ao acrescentar uma linha, coluna do
`INSERT` que não existe no `CREATE TABLE` — tudo compila verde e estoura no primeiro `Open`
real. Por isso a entrega de SQL é **sempre bloco inteiro**, e `INSERT`/`UPDATE` com uma centena
de colunas (`model.cte`, ~154) merece um script que confere placeholders × `ParamByName` × DDL
antes de sair.

### 12.3 DDL e expressão de `SELECT` se provam no `isql`

Um `isql.exe` de qualquer pasta de `D:\SistemasLocais` cria banco descartável no scratchpad e
prova `CREATE TABLE`, FK, índice, `IIF`/`EXTRACT`/`CAST` em segundos. **Firebird embarcado não
confere senha** (`password 'x'` conecta). Foi assim que `LOCAL` apareceu como palavra reservada.

### 12.4 Leituras

`AsCurrency` é o padrão para valor vindo de `TBufDataset` (é o que `Riba.SomaBuf` usa).
`AsDateTime` de coluna nula é zero. `Ide.CFOP` do CT-e é `Integer` no ACBr, não string — campo
com cara de string nem sempre é.

---

## 13. LazReport

Divisão de trabalho: o autor assume os `.lrf` no designer; o assistente só o Pascal — mas o
`.lrf` **é XML legível** e já foi escrito à mão do zero (`etiqueta_oasis.lrf`, `pedido.lrf`),
conferido por programa (carrega, `PrepareReport`, exporta PNG/PDF, `SaveToFile` para `diff`).
Formatos: listagem = **A4 retrato, área útil 680 px**; comprovante = **térmica 80 mm**.

### 13.1 ⚠ `[CAMPO]` só resolve em CINCO bandas

`GetDefaultDataSet` (`lr_class.pas:2069`) devolve dataset só em `btMasterData`,
`btReportSummary`, `btMasterFooter`, `btGroupHeader`, `btGroupFooter` (e variantes). Em
**`btReportTitle`, `btPageHeader`, `btPageFooter`** dá `EParserError: Undefined symbol` — ou
página em branco. Qualificar (`DataSet."CAMPO"`) **não resolve**. Passam sem dataset: `[PAGE#]`,
`[TOTALPAGES]`, `[DATE]`, `[TIME]`, `[LINE#]` e os agregados.

**Cabeçalho dinâmico** num relatório do `ImprimeRelatorio`: `btGroupHeader` de **condição
constante** (`Condition = DataSet."TITULO"`, `Flags 48`). Título literal fica no
`btReportTitle`. ⚠ **A exceção é o `OnGetValue`**: `balanco.lrf`, `caixa_movimento.lrf` e
`venda.lrf` têm `TfrReport` próprio e resolvem qualquer símbolo em qualquer banda — os outros
11 saem pelo `ImprimeRelatorio` e obedecem à regra. Consequência conhecida: group header só
sai quando há linha (pedido sem item não imprime cabeçalho).

### 13.2 O formato do arquivo

- `<ObjectCount Value="N"/>` no fim do `<Page1>` — **faltando, carrega zero objetos e a página
  sai em branco sem erro**.
- Objeto entra na banda por **geometria**, limite de cima **inclusivo**, varrendo as bandas na
  ordem do enum `TfrBandType` (não a visual): deixar folga entre faixas. Com dois
  `btGroupHeader`, quem pareia com o footer é o **último no arquivo**.
- `<Page><Width>/<Height>` em **pontos** (com `PrintToDefault=False`); `x/y/dx/dy` e
  `<Margins>` em 91/pol (X) e 91,6/pol (Y). `ColCount`/`ColGap`/`LayoutOrder` são da
  **página**, não da banda (etiqueta lado a lado = `loRows`).
- `<BarCode>` grava por **atributo** (`<BarCode Zoom="1" BarType="bcCode39" CheckSum="0"
  ShowText="0"/>`); como filho carrega sem erro e valem os defaults (`CheckSum = True`).
  `LR_BarC` tem de estar num `uses` do programa, senão `EClassNotFound` em runtime.
- Máscara numérica é estilo `FormatFloat` (`#,##0.00`), não `%2.2n`. No XML é o par
  `<Format Value="17039916"/>` + `<FormatStr Value="#,##0.00"/>` (4 casas: `17039404`) — para
  outra máscara, copiar o inteiro de um memo formatado no designer, não inventar.
- Campo longo cortando: `Stretched` do **memo** faz a caixa crescer; `Stretched` da **banda**
  faz a linha crescer. Precisa dos dois, mais `WordWrap=True` + `AutoSize=False` no memo.
- O `ShapeZebra` (nome exato, `TfrShapeView` na banda de detalhe, antes dos memos) é o que o
  `RelatorioEnterRect` pinta. `Flags 112` no group header que deve repetir no alto da página.
- O filtro de PDF (`TlrPdfExportFilter`) **ignora papel custom e exporta A4** — impressão
  direta não tem o problema.
- Os `.lfm` de relatório do sistema antigo são FortesReport em **pixel de 96 DPI**
  (`1 px = 0,2646 mm`); o motor novo de etiqueta desenha em **milímetro** — todo número de lá
  passa por essa conta.

### 13.3 `audita_lrf.ps1`

Na raiz; confere `ObjectCount`, objeto órfão e `[CAMPO]` em banda sem dataset, com os três
`.lrf` de `OnGetValue` isentos. **Sem argumento nenhum** (`.\audita_lrf.ps1`), do **`pwsh` 7**
— nunca `powershell -File` (5.1 tem loja de `ExecutionPolicy` separada e recusa; não é ajuste
de segurança do Windows). Rodar em todo `.lrf` novo ou mexido. ⚠ `.lrf` com `mtime` anterior
ao commit que o alterou **não foi editado, foi sobrescrito** por cópia que preservou a data
(zip, backup, sincronizador) — o `git diff` de fim de sessão é que pega.

---

## 14. Rede, OpenSSL e atualização automática

### 14.1 ⚠ O FPC carrega o OpenSSL ANTIGO primeiro

`openssl.pas` (`LoadLibraries`) tenta `libeay32.dll`/`ssleay32.dll` **antes** de
`libcrypto-1_1.dll`/`libssl-1_1.dll`. Uma DLL 0.9.8 de 2009 largada em `C:\Windows\System32`
por outro software sequestra o HTTPS do sistema (só fala TLS 1.0) — e o sintoma se disfarça de
"cliente sem internet"/firewall, enquanto a parte fiscal continua funcionando (o ACBr tenta a
ordem inversa). Três armadilhas de diagnóstico: `ESocketError Connect failed` é ambíguo (TCP ×
TLS); `where` não acha a DLL culpada (não varre `System32` fora do PATH); tamanho de arquivo
não prova qual DLL foi carregada. **Correção**: `DLLUtilName := 'libcrypto-1_1.dll';
DLLSSLName := 'libssl-1_1.dll';` no `TRiba.Create`, antes de qualquer HTTPS. Não renomear a
DLL velha da máquina do cliente.

**O diagnóstico está DENTRO do sistema** desde 04/09/2026: Configuração › ADM › **Verificar
Conexões** (`Riba.DiagnosticoConexao`), oito blocos com tempo em ms (é o ms que separa
`RECUSOU` de `NÃO RESPONDEU`), gravando `Diagnostico_<data>.txt` ao lado do exe. Não se escreve
mais exe de console para isso.

⚠ A atualização automática passa por HTTPS: o cliente com o OpenSSL sequestrado **não consegue
se atualizar sozinho** — o executável vai na mão.

### 14.2 A atualização por hash

`TRibaApi.TemVersaoNova` (só o hash do `Varejo.zip`, barato) → pergunta → `AtualizaSistema`
baixa, descompacta em `.\atualizacao`, **renomeia** o exe em uso para `.old` (Windows não deixa
sobrescrever exe em execução, mas deixa renomear) e põe o novo; falhou o 2º rename, desfaz o
1º; só então grava `Config.HashSistema`. O `.old` é apagado na abertura seguinte. Roda **antes
de conectar no banco**, para a migração de esquema rodar com a versão nova. 1×/dia, no mesmo
flag das tabelas de apoio. Só o `Varejo.exe` da raiz do zip é aproveitado — **todo o resto do
zip é jogado fora** (é por isso que o changelog viaja dentro do exe, `§ 16.1`). Pegadinhas de
teste: `Ultima Verificacao Tabelas` com a data de hoje bloqueia tudo (zerar no `Config.ini`
com o sistema fechado); `TemVersaoNova` engole exceção de propósito (404 = "não há versão").
Em Debug a atualização não roda (`-dSEM_ATUALIZACAO_AUTOMATICA`).

### 14.3 E-mail

Conta **única da RibaSoft** (constante no `RibaTypes`). `MAIL.Clear` zera o `ReplyTo` junto;
o Gmail não aceita `From` de terceiro — o cliente vai no `ReplyTo`.
`ACBrTools.EnviaEmailArquivos` recusa mensagem sem anexo.

### 14.4 O servidor

Repo `RibaSoft/site` (Laravel + Postgres, Docker), fora deste projeto. Rotas usadas:
`/api/download/<arquivo>` e `/api/download/hash/<arquivo>` (genérica, `basename` em
`storage/app/public/arquivos/sistemas/`), `POST /api/clientes/versao` (4 partes obrigatórias,
`TRibaApi.MandaVersao`), `registra_relatorio_xml` (com `unique(cnpj, modelo, competencia)` e
`upsert`). A rota legada `versao_sistema` virou no-op. Versão de 3 partes = sistema antigo =
vermelho na lista de clientes.

---

<!-- ============================================================================ -->
<!--  PARTE IV                                                                    -->
<!-- ============================================================================ -->

# Parte IV — Fiscal

O motor fiscal inteiro mora em `utils/RibaACBr.pas` (`TACBrTools`, interface `IACBrTools` no
`RibaCore`). Por documento: `ConfiguraNFe`/`ConfiguraCTe`/`ConfiguraMDFe` (o objeto do ACBr
nasce **depois** do `Configura*`), `AlimentaNFe`/`AlimentaCTe`/`AlimentaMDFe` (dbo → objeto do
ACBr), `ValidaNFParaEmissao`/`ValidaCTeParaEmissao`/`ValidaMDFeParaEmissao` (**a barreira**:
confere antes de falar com a SEFAZ o que dá para conferir sem ela), `Emite*`, `Consulta*`,
`Cancela*`, `CartaCorrecao*`, `InutilizaNF`, `EncerraMDFe`, `Imprime*`, `Exporta*`, e a
distribuição DF-e. **A transmissão é síncrona por decisão definitiva** (`§ 2.7`): nota que sai
sem o retorno gravado fica presa em `SITUACAO = 1`.

Situações (mesma escala nos três documentos): 0 rascunho · 1 transmitindo · 2 autorizada ·
3 rejeitada · 4 cancelada · 5 denegada · 6 inutilizada (NF) / encerrado (MDF-e) /
inalcançável (CT-e).

## 15. A ordem das fontes fiscais

Quando duas fontes discordam, vale esta ordem — decidida em campo:

1. **A fonte do ACBr instalada** (`E:\Developer\ACBr\Fontes\`; não está em C: nem D:). O
   writer (`*.XmlWriter.pas`, `pcn*W.pas`) diz **quando** a tag sai e se é obrigatória; a classe
   (`*.Classes.pas`) diz o **tipo** do campo; o `*-change-log.txt` de cada componente diz qual
   NT já está implementada (arquivos em CP1252).
2. **A norma da SEFAZ** (NT, manual, regra de validação).
3. **O XSD do disco** (`Schemas/`) — depois do writer. Mas duas coisas são dele: `minOccurs`
   **ausente = obrigatório** (o reflexo natural é procurar `minOccurs="1"`, e é o oposto), e o
   **domínio dos enums** (o `tpRod` do MDF-e aceita `01..06`; o `trNaoAplicavel = 00` do ACBr
   reprova). Ler o XSD para **tamanho e domínio**; ler o `Gerar_*` para **obrigatoriedade e
   gatilho do grupo**. E conferir em que **ramo** do XSD se está (`TCTeSimp`/`TCTe`/`TCTeOS`
   têm cada um o seu `imp`, `vPrest`, `infDoc`).
4. **XML de exemplo** — o mais fraco. ⚠ **XML autorizado não prova que está correto**: a SEFAZ
   aceita muita coisa que a norma não manda; contador despreparado passa nota errada.

Fora da lista: resumo gerado por IA (cita versão errada de NT, mistura datas) — serve para
saber o que procurar, nunca como fonte. ⚠ **Afirmação sobre comportamento do ACBr exige
`grep -rn` no diretório inteiro antes de concluir pela ausência** ("o ACBr não carimba nada em
produção" caiu com dois PDFs). Ao entregar, **dizer em qual das fontes a decisão se apoiou**.

O acompanhamento das NTs é do autor, pelo fórum do ACBr — não é tarefa de sessão.

## 16. ACBr: armadilhas gerais

### 16.1 Units de conversão duplicadas

Os enums do leiaute existem **duas vezes**, com nomes idênticos, como tipos distintos:

| Documento | Legada | Nova | Quem manda |
|---|---|---|---|
| NF-e | `pcnConversaoNFe` | `ACBrNFe.Conversao` | `moNFe`/`ve400` da legada; `taProducao`/`teNormal`/`tiNFCe` de `ACBrDFe.Conversao` |
| CT-e | `pcteConversaoCTe` | `ACBrCTe.Conversao` | a **legada** (é a das propriedades das classes); `ve400`/`moCTe` qualificados |
| MDF-e | `pmdfeConversaoMDFe` | `ACBrMDFe.Conversao` | a **legada** (writer e config usam ela); `ve300` qualificado — colide em **três** units |

`pcnConversao` está deprecated. Antes de acrescentar unit de conversão ao `RibaACBr`, cruzar
os identificadores públicos dela contra a unit inteira. Ao ler `cSitDFe`/`tpNF` do `docZip`
usa-se `Ord()` em vez do literal — a **posição** no enum não muda.
`TpcnTamanhoPapel` também está declarado duas vezes.

### 16.2 O que o ACBr faz por dentro e ninguém avisa

- **`AddNode` nunca trunca**: passando do máximo registra `wAlerta` e escreve inteiro; abaixo
  do mínimo preenche com zero. **Campo obrigatório vazio não vira erro: vira tag vazia**
  (`<UF></UF>`, `<CEP>00000000</CEP>`), e quem reprova é o schema local com *"Falha na
  validação dos dados"*, sem dizer o campo. Por isso os tamanhos e obrigatoriedades são
  conferidos na **barreira**, não confiados ao ACBr.
- **`TIndicador = (tiSim, tiNao)`** — `tiSim` vale **zero**, o inverso do que o nome sugere.
  Campo desse tipo não inicializado nasce `tiSim`. Vai sempre explícito.
- **`TindIntermed`: `iiSemOperacao` é a tag AUSENTE**, não "sem intermediador" (`''` no array
  de strings). No enum do ACBr o primeiro item costuma ser "não informado".
- **Data opcional com zero não some do XML: vira `1899-12-30`** quando o writer tem `if` sobre
  **outro** campo do grupo (`dhViagem` sob `tpFretamento`). Antes de confiar no `minOccurs="0"`,
  ler o `Gerar_*`. E data no passado é rejeição por si — o `AlimentaCTe` usa o `Now` congelado
  do `marcaTransmitindo` como piso.
- **Quebra de linha é `|`** nos dois sentidos (`Gerador.Opcoes.QuebraLinha := '|'` no writer;
  volta para `sLineBreak` no DANFE/DANFCe/DACTe/DAMDFe — no DACTe/DAMDFe numa **segunda passada**
  sobre o `Lines.Text`). O usuário nunca digita pipe.
- **O XmlReader não lê tudo o que o XmlWriter escreve** (CT-e: `vICMSDeson`/`cBenef` não voltam;
  o `infModal` é escrito de `infModal.rodo` e lido para `infCTeNorm.rodo`). Antes de prometer
  coluna na importação, `grep` da tag no reader daquele DFe.
- **Unit nova do ACBr só entra por pacote no `.lpi`** (`OtherUnitFiles` só tem as pastas do
  projeto). Pacote faltando não dá erro nenhum até a linha do `uses` existir. Conferir:
  `grep PackageName pVarejo.lpi`. `%LOCALAPPDATA%\lazarus\staticpackages.inc` diz o que já está
  compilado na IDE.
- **O objeto do ACBr nasce DEPOIS do `Configura*`**: o construtor copia modelo, versão, `tpAmb`
  e `tpEmis` das `Configuracoes` no `Add`, e o `GerarXML` lê do objeto. `tpImp` só ganha
  default quando já há DANFE/DACTE ligado — vai à mão.
- **`Consultar(chave)` faz `NotasFiscais.Clear`/`Conhecimentos.Clear`** — quando o documento
  local importa, usa-se `WebServices.Consulta` direto, e aí o ACBr casa a chave com o `NumID` e
  atualiza o `XMLOriginal`. `Consulta.CTeChave` valida na **atribuição** (exceção antes do
  `Executar`).
- **Rejeição chega como EXCEÇÃO** (`Enviar.GerarException`) com os campos do retorno já
  preenchidos: ler `WebServices.Enviar.cStat` antes de tratar como falha local. `procNFe`/
  `procCTe` só é preenchido quando **autorizado**; o `XMLOriginal` existe nos dois casos
  (rejeitado = XML assinado — dá para gravar como prova).
- **Repetir o `Enviar` é seguro**: `dhEmi` congelado pelo `marcaTransmitindo` + `cNF`/`cCT`
  derivado do número = mesma chave; se a primeira passou sem resposta, a segunda volta 204 e a
  consulta resolve.
- **`Configuracoes.Arquivos.Salvar := True`** faz o `Assinar` gravar `<chave>-nfe.xml` **no ato
  da assinatura** — a segunda cópia já existe em disco (o sistema antigo perdia XML por
  `SalvarApenasNFeProcessadas := True`). Na distribuição DF-e é `False`, senão XML de terceiro
  cai na pasta dos nossos.
- **`Geral.Salvar := True`** grava `<lote>-pro-lot.xml` com o **byte cru** da resposta — é a
  prova de que o `xMotivo` da SEFAZ-PR chega com acento **duplamente codificado**
  (`C3 83 C2 A3`). Conserto no `ArrumaAcentoDuplo` + `ByteCP1252`, **antes** do `gravaRetorno`
  (o `FormataTexto` troca NBSP por espaço e perde o byte); a assinatura é o **par** de bytes,
  não `Pos('Ã')`, e a faixa CP1252 `80..9F` cobre os maiúsculos.
- `Cancelada` do relatório é flag que **não se desliga sozinha**; quem manda é a situação do
  banco, não o `cStat` do XML gravado (que é o autorizado, 100). Em **homologação** o carimbo
  de cancelado não aparece (o literal de teste ocupa o mesmo rótulo).
- `GerarNFe`/`GerarCTe` não assina, não valida schema e não grava arquivo — é o que torna o
  preview do rascunho barato. Sem protocolo o ACBr já carimba "NÃO ENVIADA" na chave; em
  homologação sai "SEM VALOR FISCAL" **mesmo autorizada**; "EM CONTINGÊNCIA" exige
  `tpEmis <> teNormal` + sem protocolo.
- `LoadFromString` **não lê configuração nenhuma** e, com `AGerarNFe = False`, não grava
  arquivo — dá para carregar o XML primeiro, ler o modelo e só então configurar (é assim que o
  `ImprimeDANFEXML` imprime nota de terceiro; `Logo := EmptyStr`, senão o logo da loja entra no
  cabeçalho do fornecedor).
- `EventoCTe.LerXMLFromString` **acrescenta** item — `Evento.Clear` antes, senão imprime dois.
- Coleção do ACBr sem variável tipada no `RibaACBr`: usar **índice** (`emiDocAnt[auxIdx]`), para
  não pôr `ACBrCTe.Classes` no `uses` (colisões de `TIde`, `TEmit`, `TDest`).
- `<choice>` do XSD não é `if` que o ACBr faça: `idDocAnt` escreve as duas coleções lado a
  lado se as duas vierem cheias — quem separa é o `Alimenta*`.
- `Configuracoes.Arquivos.SalvarApenasNFeProcessadas` fica no default `False`.

### 16.3 CSRT (976/977)

`hashCSRT = Base64(SHA1(CSRT + chave))`. Hash batendo = problema de cadastro/ambiente, e já
houve **propagação** (autorizou sozinho no dia seguinte). O CSRT vale **por ambiente**. Não mexer
no código enquanto o hash bater.

---

## 17. NF-e e NFC-e

### 17.1 O que a barreira e o motor fazem por desenho

- **`cNF` é determinístico: `nNF × 3`** (`CodigoNumericoNF`), com as guardas da B03-10 (nunca
  igual ao `nNF`, fora dos 20 códigos óbvios, `mod 10⁸`, `Int64`). Razão: perdidos o XML e a
  coluna `CHAVE`, a chave se **reconstrói** (é o que o Gerador de Chaves faz, cap. 23). Notas
  anteriores a 08/08/2026 nasceram com `cNF` aleatório.
- **A consulta por chave não devolve o XML.** Reconstrução com prova só existe porque o `cNF` é
  determinístico e o `dhEmi` fica congelado: remontar pelo banco e assinar de novo dá o mesmo
  `DigestValue`. NFC-e não é distribuída por DF-e.
- **`dhSaiEnt` no 4.00 é montado só do `Ide.dSaiEnt`** (o `hSaiEnt` nunca é lido): mandar
  `TDate` rejeita **506** em toda NF transmitida depois da meia-noite. `dSaiEnt := Data + Hora`,
  **condicional** (`dSaiEnt <> 0` é o gatilho da tag).
- **`xCondUso` da CC-e só nasce pelo setter**: `detEvento.xCondUso := EmptyStr;` é o gatilho —
  a atribuição aparentemente inútil. `xCorrecao` de 15 a 1000; limite de **20 cartas** por nota
  (NT 2011.003) — só na NF-e.
- **`AtualizarXMLCancelado` desligado**: ligado, a consulta de cancelada reescreve o `nfeProc`
  com o protocolo do cancelamento (híbrido que não existe na norma). `NF.XML` guarda o
  autorizado; `XML_CANCELADO` recebe o híbrido do sistema antigo; o carimbo do DANFE vem da flag
  `Cancelada`/`ImprimirCancelado`.
- **ICMSTot**: a SEFAZ confere por somatório (531/532/533/534/564/535/536/537/601/538/602/603/
  604/861/610/685 e os monofásicos; só no 55: `vFCPST` 862, `vFCPSTRet` 859, `vIPIDevol` 863),
  tolerância R$ 0,01, campo não informado = 0. O validador soma só itens com **`indTot = 1`**;
  **NFC-e não tem IPI** (538 + 610). Composição por CST/CSOSN: `vBC`/`vICMS` ← 00, 10, 20, 51,
  70, 90 e CSOSN 900; `vBCST`/`vST` ← 10, 30, 70, 90 e 201/202/203/900; fora: 40/41/50, 60,
  500, 101/102/103/300/400 e os monofásicos.
- **Grupo `card` (391)**: o writer só emite `tBand`/`cAut` quando `tpIntegra <> tiNaoInformado`
  (é o único filho obrigatório do grupo); valor **2** (não integrado, sem TEF). E o grupo vale
  para **toda forma eletrônica** — PIX (17) foi rejeitado 8 minutos depois do cartão passar. A
  lista mora no `PagamentoEletronico`: dentro 03, 04, 10-13, 15, 16, 17-20, 22; fora 01, 02, 05,
  21, 90.
- **`indIntermed` (434/435)**: obrigatória em `indPres` 2, 3, 4, 9; **vedada** em 0, 1, 5. O
  grupo `infIntermed` (marketplace) segue por fazer — as colunas existem, nada as grava.
- **`indIEDest = 1` obriga a IE no XML** (o writer materializa `<IE>` sempre que não é isento);
  a IE vai **só com dígitos** (`ISENTO` digitado vira vazio — quem informa isenção é o
  indicador). A NF é **snapshot** do cliente (`aplicaDestinatario`): corrigir o cadastro não
  corrige nota aberta — reaplicar o cliente. O indicador é do **operador**: nenhuma tela
  recalcula o `indIEDest` no salvar (`FISCAL.md § 2`). O `Config.IndIEDest` do emitente não vai
  para XML nenhum.
- **Série 0–889 ou 920–969** (244); 890–919 é do Fisco, 970–979 do PAA. Série normalizada
  (`IntToStr(StrToIntDef(...))`) porque a coluna é `VARCHAR(3)` e `"01" ≠ "1"` para a
  `UNIQUE(MODELO, SERIE, NNF)`.
- **`detPag` fecha contra o `VNF` da nota**, nunca contra total da venda; recebimento de
  parcela não é pagamento da NF (`ID_PARCELA IS NULL`) — senão estoura 866. O `descoberto` da
  venda **não** serve para montar o `detPag` (abate parcelas; venda parcelada dá zero e a NFC-e
  nascia sem pagamento). A **falta** dos pagamentos aparece **negativa** quando se paga a mais.
- **Fatura (`cobr`) só com duplicata** (rejeição 905 é da duplicata, não da fatura); venda à
  vista sai sem `cobr`. XML já autorizado é imutável.
- **`verProc`** tem 20 caracteres: `'RibaSoft ' + Riba.VersaoApp`.
- Devolução: `refNFe` dispensado em 1201/1202/1410/1411/5921/6921 (`CFOPDispensaRefDevolucao`,
  regra da 321); a **327** (CFOP sem `indDevol`) não é conferida localmente; a virada para
  `det/DFeReferenciado` está **codada e desligada** (`Config.NF_DevolucaoRef`, 3 estados,
  produção em 05/10/2026 — `§ 1.1`).

### 17.2 Rejeições com desfecho próprio no sistema

| cStat | O que é | O que o sistema faz |
|---|---|---|
| **206** | numeração já inutilizada | vira 102 **com pergunta**: SIM marca inutilizada (situação 6, sem evento inventado); NÃO deixa rejeitada para trocar a série |
| **539** | duplicidade com diferença na chave | o número está **gasto** por outro documento: não há o que inutilizar (o `inutilizar` barra antes); sai por Editar com número livre, ou **Excluir** (Suporte — o `excluir` aceita rejeitada) |
| **217** (na consulta) | não consta | a NF vira rejeitada → o Inutilizar libera → **563** é desfecho bom |
| **573** (manifestação) | duplicidade | conta como **sucesso** — só faltava o registro local |
| **655** | manifestação fora do prazo | conclusiva em 90 dias (era 180) desde 01/06/2026; Ciência em 10 |

Série e número são **editáveis** no rascunho/rejeitada; número editado para valor que o
contador ainda vai emitir **empurra o contador**. A numeração importada anda pelo **par**
(série, nnf). Detalhe: `§ 3`.

---

## 18. CT-e e CT-e OS

O durável completo está no `DECISOES.md § 7` (a lista mais longa do projeto). O que muda a
cabeça de quem vem da NF:

- **Não existe inutilização no CT-e 4.00** — o ACBr levanta exceção, não há URL do serviço em
  UF nenhuma, e o `inutCTe_v4.00.xsd` **existe no disco mesmo assim** (schema presente não é
  serviço ativo). Buraco de numeração fica; a saída é trocar série/número. A `SITUACAO` 6 é
  inalcançável; o `TIPO 3` da `CTE_EVENTOS` ficou queimado.
- **O ACBr quase não valida CT-e** (só 502/897/252/503/226) e **o CEP é obrigatório em todo
  endereço** no writer (o XSD diz `minOccurs="0"`). A barreira do CT-e é maior que a da NF por
  isso.
- **Evento é impresso pelo próprio DACTE** (`TACBrCTeDACTeRL.ImprimirEVENTO`); a **carta de
  correção é estruturada** (`infCorrecao` 1..N, `grupoAlterado`/`campoAlterado`/`valorAlterado`)
  — grade de campos, não memo; `nSeqEvento` tem **3 dígitos** e não há limite de 20; cStat de
  evento registrado é **134/135/136** (o 155 é só da NF).
- **`RNTRC` vai em DOIS objetos** (`infCTeNorm.rodo` e `infModal.rodo`) por bug do ACBr — não é
  redundância. Vem do `CFG_NF_RNTRC` do Config (copiado só quando `AModelo = 57`); aceita
  `ISENTO`.
- **Emitente é só CNPJ** (CPF sairia adulterado com zeros); **tomador é sempre `toma4`**
  (decisão: não há coluna `TOMA`), e **tomador sem nome vira `toma3` = remetente** — por isso o
  nome é obrigatório na barreira. Os cinco papéis **não travam num Cliente**.
- **IBS/CBS nasce DESLIGADO** (combo vazio) e tem **outros nomes de campo** (`pIBS`/`vIBS` nas
  classes; o writer escreve `pIBSUF`); os **valores** só saem em CST 000/200 (57) e 000/222
  (67); `vTotDFe` é obrigatório quando o grupo está ligado (mesmo no 410); `cClassTrib` são
  **12 códigos** (colunas `CTE`/`CTEOS` na tabela, modelo na chave do cache). **CT-e não tem
  Imposto Seletivo** nem `infTribFed` (57).
- **`ICMS_CST` guarda o RAMO**, não o CST (três ramos emitem `<CST>90</CST>`): `CTEICMS_*` no
  `RibaTypes`, 91 = `ICMSOutraUF`, 99 = `ICMSSN`.
- Tamanhos que o leiaute fixa e a coluna não: `Comp/xNome` 15, `xCaracAd` 15,
  `ObsFisco/xTexto` 60 (o ACBr aceita 160 e a SEFAZ rejeita), `docAnt.serie` 3, `subser` 2,
  `nDoc` 30, `tpDoc` só 07..13, `cBenef` mínimo 8 e em **par** com `vICMSDeson`, IE do
  emitente do `docAnt` obrigatória (aceita `ISENTO`).
- Em homologação o ACBr troca o `xNome` de remetente, destinatário, expedidor e recebedor —
  **não do tomador** (`Gerar_Toma4` não olha `tpAmb`).
- **Colunas sobrando de propósito** (zeradas, sem tela, o `AlimentaCTe` não lê): `DPREV`,
  `LOTA`, `CIOT`, `DIF_PICMSINTERPART`, as cinco `IS_*`, `TOMA_ISUF`, e as cinco de
  `infTribFed` (que são do 67). Apertar tabela pede backup/restore.
- `ArquivoXMLDaChave` procura `-cte.xml` (parâmetro `ASufixo`); o DACTE imprime só **12**
  componentes do valor; `Gerar_Comp` deixa buraco no array com componente vazio — as críticas
  do `CTCompModel.adiciona` é que impedem.
- Duas regras da barreira são **nossas** (soma dos componentes = `vTPrest`; `vRec > 0`) —
  marcadas como tal; dois `if` de apagar se barrarem CT-e legítimo.
- Modelo 67: `tpServ = 6`; o CST 200 diverge entre o arquivo oficial e o `Gerar_IBSCBS` — a
  tela seguiu o ACBr.

---

## 19. MDF-e

`DECISOES.md § 8`. O escopo é o do sistema antigo (`rsLibs\libMDF.pas`); fora: `infANTT`
inteiro, `prodPred`/`infLocal`, lacres, `autXML`, `prop` de terceiro, `peri`, unidades de
transporte/carga, `infMDFeTransp`, modais aéreo/aquaviário/ferroviário, e-mail aos motoristas,
e **contabilidade** (o manifesto não apura imposto — `§ 2.8`).

- **Leiaute 3.00** (não existe 4.00); **não tem imposto nenhum — nem IBS/CBS**; **nunca teve
  inutilização** (a `SITUACAO` 6 aqui é **encerrado**).
- **O encerramento só entra pelo Consultar**: `EncerraMDFe` grava o evento 110112 e não mexe na
  situação; quem carimba é a consulta. Manifesto migrado **nasce em aberto** até ser
  consultado. Aviso da principal: `naoEncerrados` com corte de **7 dias**, sem falar com a SEFAZ.
- **A estrutura tem NETAS**: `MDFE_DESC_DOC` e `MDFE_SEGURO_AVERB` penduram no município de
  descarga, não no manifesto. Três travas de edição (`MDFEmEdicao`, `...PeloFilho`,
  `...PelaNeta`); `model.mdf_evento` é a única que não chama nenhuma, de propósito.
- `TpEmit := 2` (carga própria) é **escolha**; trocar depois de chave lançada é 638/639.
- `Ide.modelo` é **string** no MDF-e (inteiro no CT-e). `CMDF` sai das posições 36..43 da chave
  só na importação. RENAVAM tem **piso 9** e teto 11. Placa por `LimpaPlaca`.
- XML de **evento** (`-mdfe-encerrado.xml`) não vira manifesto (`Count = 0`, sem crítica); o
  `-mdfe-cancelado.xml` entra e nasce em 4. RNTRC vem do `infANTT` primeiro; XML do antigo não
  tem RNTRC, e é o esperado.
- Sem confirmar em fonte: prazo legal de encerramento (30 dias?), quais regras do
  `ValidarRegrasdeNegocio` estão ligadas, e se algum campo de fora do escopo é obrigatório em
  algum `Gerar_*`.

---

## 20. Distribuição DF-e e manifestação

`DECISOES.md § 10`; só **NF-e** por decisão (`§ 2.9`). Tabela `DFE` (um registro por NSU),
contador `DFE_NSU` (tabela, não `Config`), tela `view.dfe`, ponte para o estoque pelo
`EntradaXmlModel.importaXML` (texto — a nota do NSU nunca esteve em disco).

- **A fila é do CNPJ no Ambiente Nacional** e **ler não consome**: o `ultNSU` é de cada
  consumidor; o contador da contabilidade não tira nota nenhuma. Retenção de **3 meses**; lote de
  até **50**; reler tudo é `UPDATE DFE_NSU SET ULTNSU = 0` sem tocar em `DATA_HORA_CONSULTA`.
  `ultNSU > maxNSU` na tela é fila vazia (o guard é `>=`).
- **O 656 bloqueia o CNPJ inteiro por 1 hora** depois de um 137 ("nada novo"), e insistir
  **reinicia a hora**; repetir a mesma chave muitas vezes na hora também dá 656; chaves
  diferentes não competem. Por isso o botão Buscar fica desabilitado com a hora em vermelho —
  **não é bug**. Outro consumidor do mesmo CNPJ (o contador) aparece como "liberado na tela,
  656 na SEFAZ". Conselho ao cliente: a contadora pega o XML do nosso sistema.
- **Resumo não é nota**: o `procNFe` completo nasce da Ciência ou Confirmação — a entrada no
  estoque passa obrigatoriamente pela manifestação, e manifestar não é bloqueado pelo 656.
- `cOrgao` = **91** à mão (senão vai para a UF do emitente — o antigo tinha 41 fixo);
  `nSeqEvento` = 1 (a norma aceita até 2 desde 08/2024; retificar é o segundo com 2, não
  "liberar" o botão); `MANIFESTACAO` guarda o código curto (200/210/220/240, `SMALLINT`); linha
  "Por Chave" recebe **NSU negativo**; nota completa **promove** o resumo; evento 110111 carimba
  cancelada; `xJust` pedido nos dois eventos; `descEvento` é read-only; 573 = sucesso.

---

## 21. Reforma tributária, tabelas de apoio e rejeições com receita própria

### 21.1 IBS/CBS e IS

- **O grupo só sai quando `CST` e `cClassTrib` estão os DOIS preenchidos**; o seed grava
  `CST = -1` e `cClassTrib` vazio. Por que não `CST = 0`: **000 é valor legítimo** — quem
  distingue "desligado" é o `cClassTrib` vazio. Vale para NF e CT-e.
- **O ACBr não soma o `IBSCBSTot`**: liga o grupo quando UM item sai com IBS/CBS e escreve o
  total como recebeu. Quem soma é o `MontaNF`, sob a **mesma** condição que gera o grupo no
  item (1076/1080/1084). O nome do campo muda entre item (`gIBSUF`) e total (`gIBSUFTot`); os
  dois lados saem em **2 casas** com coluna `NUMERIC(15,4)` — o sintoma clássico é *"com 1 item
  passa, com 2 não"*. `vIBS = vIBSUF + vIBSMun` (1150) — o `EditIBSCBS_VIBS` é editável e é o
  primeiro suspeito.
- Alíquotas 2026: `pIBSUF` 0,1 %, `pIBSMun` 0, `pCBS` 0,9 %. Os três primeiros dígitos do
  `cClassTrib` **são o CST** — o combo é filtrado pelo CST. `data/cclasstrib.csv` na v1.50, uma
  coluna por documento (a NF só rotula; o CT-e filtra; coluna ausente entra como TRUE no CT-e
  de propósito — combo vazio é tela travada).
- Datas: v1.51 homologação 01/09/2026, **produção 05/10/2026**; UB12-10 (IBS/CBS obrigatório em
  produção) **sem data**; CT-e do Simples 01/01/2027; NT 2026.009 (CFOP 1.949/2.949 em qualquer
  devolução) **17/09/2026**. `FISCAL.md § 4.3`.
- Fora do sistema, de propósito: PAA (`procEmi = 4`, série 970–979), NFS-e nacional, apuração
  assistida da cartilha do IBS. CNPJ alfanumérico já coberto (`VARCHAR(14)`, `LimpaDoc`
  preserva `A–Z`).

### 21.2 Tabelas de apoio: as fontes e as armadilhas

| Tabela | Fonte | Armadilha |
|---|---|---|
| NCM | JSON público do Siscomex (`portalunico.siscomex.gov.br/classif/api/publico/nomenclatura/download/json?perfil=PUBLICO`) | traz **só o vigente** (extinto e vigência futura não vêm); formato `COD;DESCR;INICIO;FIM;;;0`, cabeçalho + 2ª linha fixa `00000000;Industrialização`, UTF-8 sem BOM, CRLF, todos os níveis (só os de 8 dígitos entram); regerado em 10/09/2026 — o anterior estava parado em 04/2024 |
| CEST | texto consolidado do Convênio ICMS 142/18 (CONFAZ) | a redação anterior vem impressa abaixo da vigente (classe CSS `...verde`); só valem os Anexos II a XXVI; a 1ª ocorrência é a vigente **inclusive quando é REVOGADO**; o `cest.csv` tem **3 colunas** (`Cest;Descr;NCM`, NCM por último de propósito) |
| cBenef PR | PDF do SPED/PR | `extract_text(layout)`; as datas vêm antes da coluna DESCRIÇÃO (1ª início, última fim) — não mapear por offset de coluna |
| ANP | `T012-Codigos_de_produtos.xlsx` do ZIP do i-SIMP (descontinuado; procurar no DPP se faltar código) | filtrar por `Data Final Validade` |
| CFOP | `data/CFOP.txt` | não termina com quebra de linha (`wc -l` conta uma a menos) |

Os loaders `Cria*` pulam a linha 0 (cabeçalho) — arquivo sem cabeçalho perdia o 1º registro.
Truncamentos aceitos: `CEST.DESCR` 256 (54 descrições passam), `ANP.DESCR` 256.
**O arquivo certo mora no servidor**: trocar só o `data/` local faz a verificação diária
devolver o velho — subir para o servidor primeiro. O sistema **não valida NCM contra a tabela**
(a barreira só exige 8 dígitos); o perigo é a busca sugerir NCM extinto (778).

### 21.3 IE, códigos de tela e CEP

- IE × `indIEDest`: a tabela de recálculo (UF em branco não mexe; IE vazia + documento = 2;
  sem documento = 9; `ISENTO` = 2; válida = 1; inválida = 2 ou 9) roda ao sair dos campos — e
  **nunca no salvar**. Na tela de cliente o combo tem **um dono**: `DefineIndIEDest` é o único
  caminho de escrita, `FIndIEManual` cala a sugestão quando o operador tocou. A tela de
  fornecedor não tem esse desenho (o indicador de lá não vai para documento nenhum).
- NCM 8, CEST 7, CFOP 4: `LimpaNumeros(...).Substring(0, n)` nos setters; `MaxLength = 14`
  nos edits; limpeza no `OnExit`.
- **CEP é `INTEGER`** no banco e no ACBr (o writer completa com zeros); a tela é que errava —
  `FormataCEP` completava pela **direita** e corrompia o dado na volta. Hoje
  `Format('%.8d', [AValue])`, e `<= 0` devolve vazio.
- O código IBGE de município carrega a UF nos dois primeiros dígitos: o `Objects` do combo de UF
  **já é o `cUF`**, o de município é o `cMun`; `cMun div 100000` deriva a UF.

### 21.4 A ordem em que uma rejeição se explica

1. **Status do serviço** (botão da aba Fiscal): prova certificado, `Schemas`, ambiente, UF e
   internet sem emitir nada.
2. **Emitir.** Autorizada abre o preview sozinha; não abriu = erro de impressão, não de emissão.
3. O primeiro suspeito é o que a barreira **não** cobre: cadastro — IE do emitente, código do
   município, CSRT do ambiente certo.
4. Histórico importado exige **Consultar em cada um**.

---

<!-- ============================================================================ -->
<!--  PARTE V                                                                     -->
<!-- ============================================================================ -->

# Parte V — Regras de negócio

O código diz **o quê**; aqui fica o **porquê** e as convenções que surpreendem quem lê a tabela
sem contexto. Fonte: `DECISOES.md § 3` e § 11–18.

## 22. Venda, caixa, pagamentos e financeiro

### 22.1 Venda

- **`PAGA` e `TIPO` são materializados**, recalculados pelo *reanalisa*. Tipo **4 = IRREGULAR**.
- **Consignada é um pagamento-marcador de forma 90**, hard-deletado pelo primeiro pagamento
  real. Não é flag na venda. Trocar o tipo de venda **não limpa lançamentos — exceto
  CONSIGNADA**, que limpa tudo.
- **Parcelas exigem cliente cadastrado (ID > 1)**; voltando para Consumidor (ID ≤ 1) as
  parcelas são descartadas, os pagamentos ficam. A venda **pode misturar formas**.
- Itens: **F1 funde item idêntico**, **F2 remove por quantidade**, desconto **capado no
  subtotal**. `VendaModel.descoberto` = itens − parcelas ativas − pagamentos avulsos ("quanto
  falta combinar com o cliente") — **não** serve para o `detPag` da NF.
- **O vendedor é do ITEM** (`VENDA_ITENS.ID_VENDEDOR`), não da venda — venda atendida por dois
  é repartida entre os dois.
- O carrinho vive na `CAIXA_ITENS` (por terminal) e a tela se remonta dele; pagamentos e
  parcelas do Fechar Venda existem só em RAM até fechar (o F4 do cliente **sai direto**, por
  decisão).
- **`FFechandoVenda`** trava o segundo Enter enquanto a navegação assíncrona não trocou a tela —
  sem ela fechava venda fantasma e queimava número de NF (`NFVendaModel.gera` reserva o `NNF`
  antes de conferir itens).

### 22.2 Pagamentos e limite de crédito

- **Estorno é lançamento NEGATIVO**, não exclusão. Exclusão de pagamento é soft delete com
  auditoria (F2 alterna Excluir/Restaurar). Arredondamento em centavos **na origem**
  (`RegistraPagamentoAVista`), com `Round`.
- **`VendaController.permiteDivida(cliente, acréscimo, título)` é o ponto único** — fechar
  venda, item novo, acréscimo, excluir pagamento, restaurar venda chamam antes de gravar.
  Dívida = **saldo devedor TOTAL** de todas as vendas ativas (`resumoCliente`), não por tipo;
  venda IRREGULAR entra sozinha; dívida negativa vira zero (crédito não é folga).
  **`LIMITE = 0` = sem restrição** (valor de quem nunca preencheu). `Config.BloqueiaAtraso`
  (nasce desligada) bloqueia por parcela vencida há mais de **30 dias** (`DIAS_ATRASO_BLOQUEIO`,
  fixo) e vem **antes** do limite. **Bloqueio duro, sem override**: para liberar, o gerente
  aumenta o limite. Cliente **inativo é barrado** (o `find` filtra `ATIVO` e voltaria zerado):
  reativar → corrigir → desativar. **A trava vem sempre antes do grava**; fora dela, o que abaixa
  a dívida (receber, desconto, remover item, estorno) e criar/excluir parcela.

### 22.3 Caixa, balanço, contas a pagar

- **Sangria fica fora do saldo**; "Troco" na tela de fechamento = o **fundo da abertura**.
- Balanço filtra pela **data do lançamento**; "TODOS" de terminal é **-1**.
- Contas a pagar: cores por vencimento × detalhe; "Repetir" gera de +1 a +60.
- Exclusão de item no caixa/mesa/pedido/venda e ajuste de valor/quantidade são **auditados**
  (`§ 12.7`, `§ 17`); descrição do item não (é a observação de cozinha na mesa).

### 22.4 NF pela venda

- O **descoberto da venda vira `tPag 05`** (crédito loja); recebimento de parcela não entra
  de novo. **Denegação desvincula** a NF da venda (a mesma venda precisa poder tentar de novo).
  Cada botão emite a NF da **venda selecionada**, no seu modelo.
- NFC-e: `SomenteCPF = True` (decisão), nome do consumidor **em branco** se não digitado, CPF
  perguntado **na emissão, sem botão**.

### 22.5 Sistema, suporte e permissões

- `TPermissao = (pmCADASTRO_USUARIOS, pmAUDITORIA, pmVER_BALANCO, pmDESCONTO, pmACRESCIMO)` —
  permissão nova entra no **fim**. A auditoria **dispensa** permissão.
- **`PodeSuporte`** abre uma janela de **7 minutos** (`SUPORTE_JANELA_SEG = 420`) com senha;
  "Login Suporte"/"Logout Suporte" se revezam no menu Sistema pelo `TimerSuporteTimer`. Coisas
  de Suporte: Configurações, excluir NF (rascunho/rejeitada, DELETE físico sem auditoria),
  desvincular venda, excluir linha do relatório de XMLs, ativação, Migrar Dados.
- **Ativação** por chave: estado no `Config.ini`, não auditada, reinicia sempre, sem carência
  sem internet, tela dentro da Config. O suporte precisa do CNPJ (clicar no label copia).
- **Só o terminal 1** recarrega tabelas de apoio sozinho; o **backup de saída** só existe em
  modo local; `Config.AtualizarReports` (por máquina) desliga a troca dos `.lrf`.
- O relatório de envio de XMLs à contabilidade filtra pela `DATA_HORA` (não pela competência),
  abre com 12 meses, e **excluir a linha não desfaz envio** — libera o automático da virada do
  mês para remandar.

---

## 23. As frentes e suas decisões

Cada frente fechada deixou regras que não se leem no código. Resumo; o detalhe está no `§`.

### 23.1 Entrada de XML no estoque (`§ 2.1`, `§ 3`)

Tabela `ENTRADA_XML`/`ENTRADA_XML_ITENS` (a `NF` é **meu** documento; a nota de compra não é
minha). Custo do produto é **sobrescrito** pelo custo de **aquisição**
`(vProd − vDesc + vFrete + vSeg + vOutro + vIPI + vICMSST) / QTD` — ICMS próprio e PIS/COFINS
ficam dentro (excluí-los faria o preço nascer abaixo do desembolso). Margem única
`Config.MargemPadrao`. Item sem vínculo entra **pendente** (Vincular / Cadastrar / Ignorar) —
casa por vínculo (CNPJ + cProd) ou EAN validado, **nunca por descrição**. Fracionamento vira
memória do fornecedor (`PRODUTO_VINCULO`), com verificação de que a **unidade** não mudou;
mudou, entra com FATOR = 1 e marca CONFERIR. Nota `IMPORTADO = TRUE` é **imutável** (estorna
primeiro). Só o Ignorar manual escreve memória; o ignorado por CFOP é regra fiscal. "Adicionar
ao estoque" e "Estornar" ficam nos **itens**, não na listagem. Regra que o autor enunciou:
*"o sistema só tenta dar uma ajuda"* — automatismo que **erra para menos**.

### 23.2 Produto novo direto na NF (`§ 2.2`)

`cadastraRapido` nasce com custo, lucro e estoque **zero** (a NF não conhece custo e não mexe
em estoque). O código digitado vira `CPROD`, seja o que for; Enter com código inexistente
deixa o código no campo e vai para a Descrição (a busca é a lupa); **pergunta antes de
cadastrar** (`CPROD` é UNIQUE — código errado fica queimado). Não abre o `view.produto_cadastro`
(é frame, tiraria a NF da tela). Unidade padrão **`UN`**.

### 23.3 Etiquetas (`§ 9`)

Modelo 40 (Oasis 80×60, `ColCount = 2`) com o leiaute do sistema antigo convertido de pixel
para fração da zona — constantes quebradas (`TOPO_BARRAS = 0.517`) que **não se arredondam**.
Fantasia vem do `Config` (etiqueta sem cabeçalho = fantasia não cadastrada). Aba destacável
pelo `CheckBoxAbaTopo` (persiste por máquina). PDF sai em A4 (limitação do filtro). Modelos
00/20/30 aceitos pela estrutura, não implementados. `VALOR_PROMO` existe e o Oasis não imprime —
está certo.

### 23.4 Balança (`§ 11`)

A etiqueta EAN-13 se lê **pelas pontas**: prefixo e código da esquerda, valor da direita colado
no verificador, o meio ignorado; o **dígito verificador não entra no valor** (o antigo somava e
errava o centavo). Nasce ligado com os padrões do antigo (prefixo 2, código 4, valor 5) e só
vale para produto marcado como **BALANCA**; código procurado **com e sem** zeros à frente
(`ACodigoAlt`); resposta é enum (`lbOk`, `lbNaoEhEtiqueta`, `lbNaoCadastrado`, `lbSemPreco`);
a conta "cabe em 13" mora na tela; `EtiquetaBalanca` recebe o leiaute por parâmetro (é o que
permite o "Testar etiqueta" antes de salvar). Exportação `TXITENS.TXT` (Toledo MGV-5): só
ativo, `RemoveAcentos` antes do corte em 25 (bytes), produto que não cabe em 6 posições fica
de fora com aviso. Leitura de peso pela serial (`btnBalanca`) fica para quando houver cliente.

### 23.5 Mesas (`§ 12`)

`MESA_ITENS`; entra pela tecla **M** do caixa. A mesa **não mexe em estoque** (a baixa é do
faturamento, via `CaixaItemModel`). Nada é apagado (`ATIVO`/`FATURADO`), `DATA`/`HORA` são do
lançamento e `DATA_BAIXA`/`HORA_BAIXA` da saída. Faturar exige **caixa aberto e carrinho vazio**
(o título diz qual dos dois, em vermelho); ordem: caixa primeiro, marca depois; `faturar`
devolve `False` se outro terminal mexeu. Mapa em **uma** consulta (`getOcupadas`), número da
mesa na `Tag`. 40 mesas fixas; sem vendedor por mesa; sem tela de histórico.

### 23.6 Pedido e Orçamento (`§ 13`)

`PEDIDOS` + `PEDIDO_ITENS`; **uma tabela para os dois**, `TIPO` só troca o título da impressão
e separa na listagem (um frame instanciado duas vezes, como `vCTe`/`vCTeOS`). `TIPO` não se
edita (orçamento aprovado se **fatura**). Número = `ID`; nasce no cliente 1; F3 volta para o 1.
`FATURADO` do cabeçalho é **derivado** pelo model do **item**, na mesma transação; parcialmente
faturado continua aberto. Barreira nas duas camadas; troca de cliente grava na hora. "Tem o que
imprimir?" responde o `PedidoItemModel.Count`, não a grade. A4 pelo `ImprimeRelatorio`
(`pedido.lrf`, `[TITULO]`). Excluir item é **F5**; o botão que cancela chama-se `btnCancelar`
(o que faz alguma coisa se chama pelo nome).

### 23.7 Central de Relatórios (`§ 14`)

`view.relatorio`: um item do `RadioGroupRelatorios` = um relatório; **filtros montados em
código** (`PanelFiltros` vazio no `.lfm`, fábricas `FiltroPeriodo`/`FiltroVendedor`/
`FiltroProduto`/`FiltroFornecedor`, geometria em `FILTRO_*`). Relatório novo = 4 linhas na
mesma unit; filtro novo = um valor no `TFiltroRel` + um `Filtro*` + uma linha no
`AtualizaFiltros`. O valor mora no campo `F*` do frame. `EstilizaComponentes(PanelFiltros)`
depois de montar. Três relatórios: *Itens vendidos por vendedor* (vendedor do item; totais por
janela; 9 colunas = 680 px), *Produtos vendidos por período* (grupo por `P.CPROD`, descrição
do cadastro, filtro por `ID_PRODUTO` para cair em índice; total de quantidade soma unidades
diferentes de propósito), *Lista de compras* (sem período; `MINIMO > 0` é **regra** — relatório
vazio quase sempre é mínimo não cadastrado; `COALESCE` nas três colunas; `REPOR × CUSTO` é
estimativa). O `BufDados` é um só: `ABuf.Clear` no model.

### 23.8 Gerador de Chaves (`§ 15`)

Materializa no banco a numeração que **existe na SEFAZ e não tem XML** (as inutilizadas do
antigo). A NF nasce **TRANSMITINDO** (situação 1, `CSTAT = 0`) — a única que diz a verdade — e
o **Consultar** resolve (100 → autorizada; 101/135/151/155 → cancelada; 110/301-303 → denegada;
217 → rejeitada → Inutilizar → 563 → inutilizada). Chave pelo `GerarChaveAcesso` do ACBr com o
`cNF` determinístico; `tpEmis` fixo em 1 (o antigo punha o `finNFe` na casa 35 e gerava chaves
erradas); grava pelo `NFModel.importa` (ganha a UNIQUE e o empurrão do contador); a consulta
não refaz nota **sem itens**. Só 55/65, um número por vez, não navega até a nota. Conta como
pendente — não é bug.

### 23.9 Novidades / change log (`§ 16`)

Menu Sobre › Novidades (`view.change_log`). O texto mora **em código** (`CarregaAlteracoes`),
porque a atualização joga fora tudo do zip menos o exe. `Versao('x.y.z.w', 'dd/mm/aaaa')` no
topo, uma linha `Novo`/`Melhoria`/`Correcao` por alteração, escrita **para o cliente** (o que
ele vê na tela; nome de unit/tabela/método não entra; refatoração invisível não vira linha).
Publicar versão começa por aqui (cap. 26).

### 23.10 Auditoria (`§ 12.7`, `§ 17`)

O que se registra: exclusão de item (caixa, limpar venda, venda total/parcial, mesa), ajuste de
valor/quantidade (caixa, mesa, pedido), inclusão de item de venda, `PRODUTOS` (só quando
custo/venda/estoque mudaram, uma linha com os três), `DESPESAS`, `CONTAS_PAGAR(_DET)`,
`USUARIOS` (criação, nome, senha — só **que** mudou, nunca o valor —, ativo). **Model** quando o
método é o caminho único; **tela** quando o `acEditar` do model é o mesmo caminho do desconto
e acréscimo (caixa, mesa, pedido). Fora: descrição de item, cadastros de cliente/fornecedor/
vendedor/grupos, Configurações (já passa pelo `PodeSuporte`), pagamento e parcela (a linha é o
rastro), abrir/fechar caixa, fiscal. Ninguém apaga a `AUDITORIA`.

### 23.11 Tributação por cenário de destino (`§ 18`)

`TRIB_INTER`: uma linha por tributação **interna** com duas colunas de destino (consumidor
final, revenda). O cenário sai **só dos dois combos** do cabeçalho da NF (`idDest` ×
`indFinal`; exterior = `ctNenhum`, nada ajustado; combo em branco = `ctNenhum`, não "revenda").
Trocar o cliente não mexe em tributação. O `resolve` procura o ID nas três colunas — a mesma
regra **leva e traz**, e por isso cada tributação só pode aparecer **uma vez** na tabela (o
`salvar` recusa). Sem regra, devolve o que entrou — nunca zera. A conta do imposto tem uma fonte
(`AplicaTribNoItem`, `model.nf_item`), usada por `adiciona` e `retributa`; ⚠ as fórmulas são as
**mesmas** dos `SugereBases*`/`Recalcula*` da `view.nf_cadastro` — mudou num lado, muda no
outro. Seed de 5 regras casa por `DESCR` e roda só na criação da tabela. O ajuste em massa
coleta os pares antes de mexer, pula item sem `ID_TRIB` e devolve **contagem**.

### 23.12 Migração do sistema antigo

Restauração → pré-voo → XMLs → bomba das 13 tabelas (**banco↔banco, sem CSV** — CSV não sabe o
que é NULL) → pós-processamento → conferência. Sem usuário "MIGRAÇÃO". "FASE 1/2/4" é
vocabulário de runtime do relatório. Histórico de CT-e não migra. A base migrada tem `CPROD`
**com** zeros à esquerda e string vazia onde o cadastro novo tem NULL.

---

## 24. O que foi recusado — não voltar a propor

Decisão recusada não está em lugar nenhum do código. Regra de conduta: **quando ele já disse
não, não reabrir** sem que ele levante o assunto. Lista completa e datada: `DECISOES.md § 2` e
os "o que ficou de fora" de cada frente.

**Fiscal / NF** — thread de transmissão (definitivo); NFC-e com entrega em domicílio;
`retTransp`/`reboque`; NFC-e para CNPJ (`SomenteCPF`); nome do consumidor automático; botão
para o CPF; colunas `DEST_*` em `VENDAS`; eventos TIPO 4 "outros"; inutilizar por faixa;
auditoria na exclusão de NF; três abas PIS/COFINS/IPI; produto de exemplo no seed; carimbo
próprio de não transmitida; cancelamento descoberto por fora; caixa de diálogo de certificado
vencido; e-mail de aviso de ativação; campos `dhCont`/`xJust`/`idEstrangeiro`/`ISUF`/`IM`/
`indPag`/`dPag`/`CNPJPag`/`UFPag`/`CNPJReceb`/`idTermPag`/`obsCont`/`obsFisco`/`exporta`/
`compra`/`retTransp` na tela; apagar `CODIF`/`qTemp`/`CIDE` (não estão descontinuados);
limpar as colunas órfãs do DDL fiscal (é o DDL completo de propósito; `NF_EVENTOS` é vaga
reservada).

**CT-e / MDF-e / DF-e** — coluna `TOMA` (é `toma4` sempre); botão de editar cliente nos papéis;
atalhos no cadastro do CT-e; e-mail aos motoristas; MDF-e para a contabilidade; distribuição
DF-e para CT-e/MDF-e; aviso de documento sem manifestação na principal; busca automática de
NSU; botão da "Operação não Realizada"; MDF-e/CT-e no Gerador de Chaves.

**Estoque / entrada de XML** — custo médio ponderado; margem por produto; cadastro automático
de produto; casar por descrição; tabela `NF` para nota de compra; DBO novo; tela de manutenção
do de-para; botões de estoque na listagem; recalcular custo do passado; ICMS próprio e
PIS/COFINS fora do custo; CFOPs duvidosos na lista de não-compra.

**Venda / cliente** — balde de limite por tipo de venda; travar o que abaixa a dívida; config
para desligar o limite; tolerância de atraso configurável; permissão/senha de gerente para
liberar; perguntar antes de sair do Fechar Venda pelo F4; guardar "somente ativos" no filtro
padrão de produtos.

**Sistema** — backup em rede pelo cliente; senha do banco na tela de Config; usuário
"MIGRAÇÃO"; CSV no meio da migração; Excluir do relatório de XMLs para o usuário; repetir o
aviso do suporte a cada exclusão; auditar logout do suporte com o sistema bloqueado; filtros
de relatório no `.lfm` ou por diálogo; roteiro de teste como pendência.

**Mesas / pedido / balança / etiqueta / relatórios** — quantidade de mesas configurável;
vendedor por mesa/pedido; tela de histórico das mesas; permissão fina; validade de orçamento;
leitura de peso pela serial; outros leiautes de balança; etiqueta automática ao cadastrar
(não portado nem perguntado); contagem de vendas distintas por vendedor.

---

<!-- ============================================================================ -->
<!--  PARTE VI                                                                    -->
<!-- ============================================================================ -->

# Parte VI — Operação e ciclo de vida

## 25. Build e ferramentas

### 25.1 `lazbuild`

```bash
/c/lazarus/lazbuild.exe -B "D:/Documents/GitHub/NEW_Varejo/pVarejo.lpi" > build.log 2>&1
```

- Sem `-B` usa cache (~3 s, pode mascarar erro em unit já compilada); com `-B` é rebuild
  completo (~400k linhas, ~130 s). Saída limpa esperada: só `Hint (5023) Unit not used` (todas
  as units entram pelo `.lpr`) e `(5024) Parameter Sender not used`. Filtrar com
  `grep -E "\.pas\([0-9]+,[0-9]+\) (Warning|Error|Fatal)"` — os `Warning: (lazarus) Unidade
  duplicada` do ACBr são ruído pré-existente.
- ⚠ **Duas armadilhas de exit code**: em `run_in_background` a notificação traz o exit do
  último comando da linha; com cano (`| tail`) o exit é do `tail`. Redirecionar para arquivo e
  **ler o arquivo** (`grep -c "Error:"`).
- ⚠ **`lazbuild -B` incrementa o `BuildNr` do `.lpi`** (`AutoIncrementBuild`) **depois** de
  compilar: o exe publicado leva N e o `.lpi` commitado fica N+1. Para só conferir sem queimar
  versão: `--no-write-project`, ou compilar uma **cópia do projeto no scratchpad** (o `.lpi` usa
  caminhos relativos e os pacotes vêm da config da IDE — sem `lib/`, `bkp/`, `XMLs/`,
  `Schemas/`, `DB.FDB`, ~60 MB). É o jeito de **provar** uma correção antes de entregar.
- **Debug** → `Varejo_debug.exe`, checks IO/Range/Overflow/Stack, `heaptrc` (janela de
  vazamento ao fechar), `-dSEM_ATUALIZACAO_AUTOMATICA`. **Release** → `Varejo.exe`, `-O3`.
  `i386`/`win32` fixados nos dois. `Limpar.bash` apaga o runtime do Firebird da pasta (tudo
  gitignored; o app não roda até repor — o `TRiba.Create` repõe na abertura seguinte).

### 25.2 `fpc.exe` e `isql` para provar, não supor

```bash
/c/lazarus/fpc/3.2.2/bin/i386-win32/fpc.exe -O2 -Criot -FE"$SC" -FU"$SC" teste.pas
```

`-Criot` liga os mesmos checks do Debug. Foi assim que caíram as duas armadilhas do currency, o
"campo depois de método", o `-1 in [...]`, a resolução de `overload`. Para SQL, o `isql`
(cap. 12.3). ⚠ Git Bash converte caminhos em `-FU`/`-FE` (`C:C:\Program Files\...`): caminho
relativo ou `MSYS2_ARG_CONV_EXCL="*"`.

### 25.3 A versão do `.exe`

`Riba.VersaoApp` lê o recurso de versão do próprio exe (unit `fileinfo`, `GetProgramVersion`),
formato `Maior.Menor.Revisão.Construção`. Onde mora: Opções do Projeto › Informações da
Versão (`<VersionInfo>` do `.lpi`). Sobe com `lazbuild -B` e com IDE › Construir; **não** sobe
com Executar/Compilar (por isso o histórico dá saltos). **A versão do zip no site é sempre
`BuildNr do .lpi − 1`.** Consumidores: título do principal, `verProc` da NF-e, `MandaVersao`.

### 25.4 Onde estão as coisas

- Fontes do ACBr: `E:\Developer\ACBr` (`Fontes\`, `Exemplos\`, `Pacotes\`, `Doctos\`); quem sabe
  o caminho é `%LOCALAPPDATA%\lazarus\packagefiles.xml`. O fórum devolve 403 para leitura
  automatizada.
- LCL: `C:\lazarus\lcl\` (`controls.pp`, `include\wincontrol.inc`, `include\radiogroup.inc`);
  LazReport: `C:\lazarus\components\lazreport\source`; `datetimepicker.pas` em `datetimectrls`.
- Componentes próprios: `D:\Documents\GitHub\RibaSoftComponentes` (`libBotao.pas`,
  `libReiniciador.pas`); resource: `D:\Documents\GitHub\resource` (`lista.txt` + `.bat` do
  `lazres` — o `restart.exe` da lista não é mais usado pelo Varejo).
- Sistema antigo: `D:\Documents\GitHub\Varejo` (`rsForms/`, `rsReports/`, `rsTools/`,
  `rsLibs/`). Clientes locais: `D:\SistemasLocais\<cliente>\`.
- Firebird instalado: `C:\Program Files (x86)\Firebird\Firebird_5_0` (o `isql` também está em
  cada pasta de cliente e na raiz do projeto).

### 25.5 Shells

- Tool **Bash** (Git Bash): heredoc `<<'EOF'`; **nunca** `-m @'...'@` (vira `@` no assunto do
  commit — aconteceu duas vezes; ele escolheu deixar). Mensagem multi-linha: `git commit -F - <<'EOF'`.
- Tool **PowerShell** (`pwsh` 7): here-string `@'...'@` com `'@` na coluna 0. Scripts `.ps1`
  rodam do `pwsh` 7 (`RemoteSigned`); o `powershell` 5.1 recusa (`Restricted`) — não é ajuste
  de segurança para fazer. Curinga em argumento de `.ps1` não expande.
- **Comando que não foi rodado não se entrega.**

---

## 26. Publicar uma versão

Ordem, e cada passo existe por um motivo:

1. **Escrever o change log** (`CarregaAlteracoes` em `view/view.change_log.pas`):
   `Versao('x.y.z.w', 'dd/mm/aaaa')` no topo (a mais nova é a primeira e a única que abre
   expandida), uma linha `Novo`/`Melhoria`/`Correcao` por alteração, título curto sem ponto
   final, texto longo no 2º parâmetro, **na língua do usuário**. É o primeiro passo porque o
   texto viaja dentro do exe e a versão publicada tem de saber dizer o que mudou.
2. **Commitar** (cap. 27) — cada exe que chega no cliente tem um commit correspondente.
3. **`Limpar.bash`** com "Criar Release": `lazbuild -B --build-mode=Release` → (opcional)
   copiar o `Varejo.exe` para as pastas de `D:\SistemasLocais` que **já têm** um `Varejo.exe`
   (exe aberto falha e o script anota) → `7z` gera **`Varejo.zip` com o exe na RAIZ** (subpasta
   faz o `AtualizaSistema` desistir) → copia para
   `E:\arquivos_do_site\storage\app\public\arquivos\sistemas\` → idem `report.zip` → apaga os
   zips locais → `git add .` / commit / push → apaga `lib/`, `*.lps`, `*.res`.
4. O cliente pega na abertura seguinte (1×/dia): pergunta, baixa, troca por rename, reinicia. O
   hash comparado é o **do zip**, guardado no `Config.ini` (`Hash Sistema`) — cliente estreando
   o recurso baixa uma vez, de propósito.

Arquivos que vão pelo mesmo motor e **não** pelo git: `Schemas.zip` (achatado — `NFe\`, `CTe\`,
`MDFe\` no primeiro nível), `report.zip`, `NCMs.txt`, `cest.csv`, `anp.csv`, `cbenef.csv`,
`cclasstrib.csv`, `CFOP.txt`, `ibpt.csv`, municípios, `FB504-embarcado.zip`. Regerou tabela de
apoio: **subir para o servidor primeiro**.

---

## 27. Finalizar uma sessão de trabalho

"Mandar para o git" é uma sequência de três passos (`CLAUDE.md § 8`), e a razão é que quem cola
o código na IDE é o autor, um bloco por vez — **commit escrito a partir do que foi entregue
mente quando um bloco não entrou, e código que falta compila verde igual**. Caso real: o commit
`5efddbd` anunciava "MenuConfigClick pede PodeSuporte" e o diff nunca tocou nele — a Config
ficou um dia aberta para qualquer um.

### 27.1 Conferir se tudo foi mesmo aplicado

1. **`grep` do símbolo novo de cada bloco** entregue (nome do método, da coluna, da constante).
   Um grep por bloco. Pega bloco **faltando**.
2. **`git diff --stat`**: o tamanho de cada arquivo bate com o combinado? O que não bater, abrir
   o `git diff`. Pega bloco colado no **arquivo errado** (uma linha de comentário colada por
   cima de outra em `model.mdf_seguro` passou por grep e build) e separa o Ctrl+D (estética,
   se deixa) da perda de verdade (volta, com a edição de uma linha — não `git restore`).
3. **`lazbuild -B --no-write-project`**: pega bloco **duplicado** (`3028 overloaded functions
   have the same parameter list` — a colagem arrasta o vizinho), que grep de símbolo nunca
   denuncia.
4. **Evento declarado na classe × ligado no `.lfm`, nos dois sentidos** (Apêndice A). Handler
   sem `On... =` compila verde e mata o atalho em silêncio — num roteiro de 15 eventos
   escaparam dois, e com eles morreram o F2 e o F3 da tela.
5. `audita_lrf.ps1` se algum `.lrf` foi mexido; `git diff` de fim de sessão olha o `mtime` dos
   `.lrf`.

Achou bloco faltando, duplicado ou no arquivo errado: entregar a correção e **voltar ao
passo 1**.

### 27.2 Change log — e esperar ele aplicar

Entregar o código do `CarregaAlteracoes` (cap. 26, passo 1) e **parar**. Enviar sem ele
publica uma versão que não sabe dizer o que mudou.

### 27.3 Enviar

Mensagem de commit a partir do que foi **conferido**, não do prometido. Incluir **todos os
arquivos pendentes** do `git status` (ele edita na IDE em paralelo), revisando o que entra —
nada de `git add -A` cego. Mensagem torta **já enviada** fica (não reescrever histórico por
estética). Conferir com `git log -1 --format=%B` **antes** do push.

Nos projetos de uso próprio (`New_RibaSoftADM`, `EmissorDiario`) não há change log: dois
passos, não três.

---

## 28. Diagnóstico de campo

### 28.1 "O sistema não conecta"

Não olhar o firewall primeiro. Configuração › ADM › **Verificar Conexões** e pedir o
`Diagnostico_<data>.txt`. OpenSSL antigo na máquina (cap. 14.1) é a causa que já custou várias
rodadas. `RECUSOU` (porta fechada) ≠ `NÃO RESPONDEU` (DROP) — o tempo em ms separa.

### 28.2 "O comportamento não acontece"

A **primeira hipótese é bloco não aplicado**, não bug de lógica: `grep` do símbolo. A segunda é
evento não ligado no `.lfm`. A terceira é `case` sem o ramo novo.

### 28.3 "Emissão rejeitada"

A ordem do cap. 21.4. Depois, as rejeições com receita própria (cap. 17.2, `FISCAL.md § 5.2`):
206, 539, 976/977, 391, 434/435, 506, 1076/1080/1084, 1150, 327, 244, 655.

### 28.4 "A grade mostra linhas em branco" / "o Excluir apaga o errado"

`DataSource` apontando para o dataset errado (cap. 11.1). Uma propriedade no OI.

### 28.5 "Centavo que dança"

`currency` promovido a float, produto cortado em 4 casas, ou a mesma conta feita em SQL num
caminho e em Pascal noutro (cap. 10.1). Duas funções repetidas de propósito (`CustoAquisicao`)
que divergiram.

### 28.6 "Trava sem erro"

Model com transação aberta chamando outro model na **mesma tabela** (cap. 8.1). Ou
`ProcessMessages` drenando a fila de async e liberando o `FFrame` debaixo da pilha (cap. 7.2) —
esse mata o processo sem passar pelo `OnException`.

### 28.7 Ferramentas do próprio sistema

Sistema › **Último Erro** (o `Erros.log`); Sistema › **Auditoria**; Configuração › Dados ›
**Atualizar Dados** (recarrega tabelas de apoio em terminal ≠ 1); Configuração › ADM ›
**Verificar Conexões**; Sobre › **Atualizar** (confere versão nova na hora); Fiscal › **Status
do serviço** em cada tela de documento.

---

<!-- ============================================================================ -->
<!--  PARTE VII                                                                   -->
<!-- ============================================================================ -->

# Parte VII — Manual do usuário

Esta parte é escrita para quem **opera** o sistema. Não há nome de arquivo nem de tabela aqui —
só o que aparece na tela. (Quem der manutenção acha o código pelo nome do menu: cada item
`MenuXxx` do `view.principal` abre a `view.xxx` correspondente.)

## 29. Menus e atalhos

### 29.1 A barra de menus

| Menu | Itens |
|---|---|
| **Sistema** | Login (Enter) · Logout (Esc) · Último Erro · Configurações · Auditoria · Restaurar Backup · Reiniciar · Login Suporte / Logout Suporte (se revezam) |
| **Cadastros** | Usuários · Produtos (**F1**) · Grupos de Produtos · Clientes (**F2**) · Fornecedor · Grupos de Despesas · Vendedores · Importar estoque pelo XML |
| **Financeiro** | Caixa (**Enter**) · Vendas (**F3**) · Despesas (**F4**) · Balanço (**F5**) · Contas a Pagar (**F6**) |
| **Fiscal** | NFC (**F7**) · NFe (**F8**) · MDFe (**F9**) · CTe (**F10**) · CTe OS (**F11**) · Utilidades DANFE (distribuição DF-e) · Regras Fiscais · Relatório de Envio de XML · Gerador de Chaves |
| **Outros** | Etiquetas · Relatórios · Exportar produtos para balança · Pedido · Orçamento |
| **Sobre** | Novidades · Atualizar |

Os atalhos F1–F11 do menu valem na **tela inicial**. Dentro de cada tela, as teclas de função
passam a ser as dos botões daquela tela (o `Hint` de cada botão diz qual: `F1 - Novo`,
`F2 - Editar`, `F3 - Salvar`, `F4 - Cancelar`, `F5 - Excluir`, `F6 - Imprimir`, `F7 - Buscar`,
`Fechar - ESC`). **Esc** fecha qualquer tela e volta.

### 29.2 Convenções que valem em todas as telas

- **Enter avança para o próximo campo** (como Tab). Em memos, a quebra de linha é
  **Ctrl+Enter**.
- Texto sai em **MAIÚSCULAS** automaticamente (exceto e-mail).
- Nas listagens: a caixa **Ativos** alterna a grade entre ativos e excluídos, e o botão
  Excluir vira **Restaurar** quando ela está desmarcada.
- Linha colorida na grade é situação (verde autorizada, azul transmitindo, laranja rejeitada,
  vermelho cancelada, lilás denegada, cinza inutilizada/encerrada). A linha em foco mostra a
  **mesma cor**, mais forte.
- Combos longos (município, tributação) aceitam **digitar o começo do nome**; BackSpace limpa.
- Campos de código (NCM, CEST, CFOP, CNPJ, CEP) aceitam **colar com pontuação** — o sistema
  limpa ao sair do campo.
- Datas: não há data "vazia" (a tecla N no campo de data está desligada), exceto onde o
  documento fiscal permite.
- **Botão desabilitado** quase sempre tem o motivo escrito na tela (no título, em vermelho, ou
  no `Hint`). Ver o cap. 31 antes de reportar.

### 29.3 O Caixa (Financeiro › Caixa, ou Enter na tela inicial)

Funciona **sem tirar a mão do teclado**, com o foco em qualquer lugar:

| Tecla | Faz |
|---|---|
| dígitos / leitor de código de barras + Enter | lança o item pelo código (ou pela etiqueta da balança) |
| `*` | fecha a **quantidade** digitada antes do código (`3*` + código) |
| **Espaço** | **Fechar Venda** (só com itens) |
| F1 / F2 | Desconto / Acréscimo |
| F3 / F4 | Excluir item / Limpar venda |
| F5 / F6 | Despesas / Sangria |
| V · D · Q · U | Vendedor · Descrição do item · Quantidade · Valor unitário |
| B · G · T · C | Balança · Gaveta · Troco · Calculadora |
| **M** | mapa das **Mesas** (funciona com o caixa fechado) |
| **P** | **Pizza** (montagem por sabores) |

O carrinho fica gravado por terminal: fechar o sistema no meio não perde os itens.

### 29.4 Vendas (Financeiro › Vendas)

Letras aceleradoras na grade: **I** itens da venda · **P** parcelas · **A** pagamentos ·
**E** excluir venda · **G** gerar **NFC-e** da venda em foco · **R** gerar **NF-e** ·
**C** calculadora. F2 busca cliente, F3 limpa. O tipo da venda (à vista, parcelada, consignada,
crédito loja) é definido no Fechar Venda; parcelas só para cliente cadastrado.

---

## 30. As telas e os fluxos principais

### 30.1 Cadastros (produtos, clientes, fornecedores, vendedores, usuários, grupos)

Listagem com busca (F7 leva o foco à busca; Enter filtra), Novo (F1), Editar (F2), Excluir
(F5), Imprimir (F6) e, em alguns, Clonar (F10). Excluir é reversível: desmarque **Ativos** e
use Restaurar. No cadastro de cliente/fornecedor, o botão ao lado do CNPJ **busca os dados da
empresa** na Receita; o botão ao lado do CEP busca o endereço; a IE define sozinha o indicador
de contribuinte — **mas se você escolher o indicador à mão, ele fica** (é o caso das UFs que não
aceitam isento).

No produto, **Custo, Venda e Estoque são auditados** quando mudam; NCM e CEST têm lupa de
busca; o campo **Mínimo** é o que alimenta a Lista de Compras (produto com mínimo zero não
entra nela); a caixa **Balança** é o que permite ler a etiqueta de peso no caixa.

### 30.2 Fluxo de venda

1. Caixa aberto (Financeiro › Caixa pede a abertura com o fundo de troco).
2. Lançar itens (código, leitor, balança, mesa ou pizza). Desconto é limitado ao subtotal.
3. **Espaço** → Fechar Venda: escolher o cliente (F2 busca, F3 volta ao consumidor, F4 abre o
   cadastro e volta), o tipo, lançar pagamentos (pode misturar formas) e/ou parcelas.
4. Se o cliente tem **limite de crédito** e a dívida total passa dele, ou tem parcela vencida há
   mais de 30 dias (quando ligado na Configuração), a venda a prazo é **barrada** — o gerente
   libera aumentando o limite no cadastro.
5. Da tela de Vendas: **G** emite a NFC-e, **R** a NF-e, da venda em foco. O que faltou pagar
   vira "crédito loja" na nota.

### 30.3 Fluxo fiscal (NFC-e, NF-e, CT-e, CT-e OS, MDF-e)

As cinco telas têm a mesma barra de botões: **Novo · Editar · Excluir · Clonar · Imprimir ·
Transmitir · Consultar · Cancelar · Inutilizar (só NF) · Carta de Correção (NF e CT-e) ·
Encerrar (só MDF-e) · Eventos · Enviar e-mail · Enviar para a contabilidade · XMLs ·
Vincular venda (NF)**. Filtro por período e por cliente (F1 alterna digitar o código; F2 busca;
F3 "Todos").

1. **Status do serviço** (na aba Fiscal da Configuração): prova certificado, schemas, ambiente
   e internet **sem emitir nada**. É o primeiro passo quando algo rejeita.
2. **Novo** abre o cadastro em abas. Os campos obrigatórios são conferidos **antes** de falar
   com a SEFAZ — a tela lista o que falta, item por item.
3. **Transmitir**. A tela fica travada ("Transmitindo...") até a SEFAZ responder — é assim de
   propósito. Autorizada, o documento **abre o preview sozinho**; se não abriu, o problema é de
   impressão, não de emissão (o documento está autorizado; Imprimir traz de volta).
4. Rejeitada: a linha fica laranja com o motivo. **Editar** (série e número são editáveis em
   rascunho/rejeitada), corrigir e transmitir de novo. Duas rejeições têm caminho próprio:
   **206** (numeração já inutilizada) pergunta se marca a nota como inutilizada; **539**
   (número já usado por outro documento) não se inutiliza — troca-se o número, ou o Suporte
   exclui.
5. **Consultar** traz a situação real da SEFAZ (é obrigatório em todo documento **importado**
   e em toda numeração criada pelo Gerador de Chaves).
6. **Cancelar** e **Carta de Correção** pedem justificativa/texto; o cancelamento e o
   encerramento do MDF-e só aparecem na tela **depois de consultar**.
7. **XMLs**: exporta XML + PDF para uma pasta, ou importa XMLs seus feitos por outro sistema
   (migração de histórico). **Enviar para a contabilidade** manda os XMLs do período por
   e-mail; na virada do mês o sistema faz isso sozinho, e o *Relatório de Envio de XML* mostra
   o que já foi.

Na NF: trocar **Destino** (interna/interestadual) ou **Consumidor final** com itens lançados
pergunta se refaz a tributação de todos os itens pela regra de destino cadastrada
(Configuração › ADM › Ajustar tributação interestadual). Trocar o cliente **não** mexe na
tributação. O NCM/CEST do último item pode vir preenchido no próximo (Configuração › Fiscal).

### 30.4 Entrada de mercadoria (Cadastros › Importar estoque pelo XML)

Importe o XML da nota do fornecedor (arquivo, ou vindo da distribuição em *Utilidades DANFE*).
Abra os **Itens**: cada item aparece vinculado (o sistema lembra o de-para do fornecedor),
pendente (**Vincular / Cadastrar / Ignorar**) ou **a conferir** (a embalagem mudou). O custo do
produto é **substituído** pelo custo de aquisição da nota e o preço de venda sugerido pela
margem padrão. Só depois de olhar os itens, **Adicionar ao estoque**. Nota importada não se
altera mais — **Estornar** primeiro. *"É de responsabilidade do usuário verificar itens, custos,
fracionamentos e vínculos; o sistema só tenta dar uma ajuda."*

### 30.5 Utilidades DANFE (distribuição DF-e)

**Buscar** traz da SEFAZ o que emitiram contra o seu CNPJ. Cada nota chega como **resumo**;
**Ciência** ou **Confirmar** libera a nota completa, e daí **Importar** leva para a entrada de
estoque. **Rejeitar** (desconhecimento) pede justificativa. O botão Buscar fica desabilitado
por **1 hora** depois de cada consulta que não trouxe nada — é regra da SEFAZ, e a hora aparece
em vermelho ao lado. Peça à contabilidade que pegue os XMLs **do sistema**, não da SEFAZ pelo
mesmo CNPJ.

### 30.6 Mesas, Pedido e Orçamento

**Mesas** (tecla M no caixa): mapa de 40 mesas com o total no `Hint`; dentro da mesa, o mesmo
teclado do caixa; o **Espaço** marca/desmarca a linha; **Faturar** leva os itens marcados para
o carrinho do caixa (exige caixa aberto e carrinho vazio — o título diz qual dos dois falta).
Lançar na mesa não mexe no estoque; faturar sim.

**Pedido / Orçamento** (menu Outros): listagem com filtro; um pedido tem cliente (F2/F3/F4) e
itens; **Imprimir** (A4) acende quando há item; **Faturar** manda para o caixa; **Cancelar**
marca cancelado (não apaga). Orçamento aprovado se **fatura** — não "vira" pedido.

### 30.7 Relatórios (Outros › Relatórios)

Escolha o relatório à esquerda; os filtros aparecem à direita conforme o relatório (período,
vendedor, produto, fornecedor). *Itens vendidos por vendedor*, *Produtos vendidos por período*
(o total de quantidade soma unidades diferentes — o que vale é o R$) e *Lista de compras*
(produtos com **mínimo cadastrado** que caíram até ele; sem período — é o estoque de agora).

### 30.8 Etiquetas e balança

**Outros › Etiquetas**: fila de produtos, quantidade por produto, modelo Oasis 80×60 com
**aba destacável** (caixa "aba no topo"), calibração e pré-visualização. A fantasia da loja
(Configuração) sai no cabeçalho — sem fantasia, sem cabeçalho.
**Outros › Exportar produtos para balança**: gera o `TXITENS.TXT` (Toledo MGV-5) na pasta
`ToledoMGV5` ao lado do sistema, só com produtos ativos que caibam no leiaute (os que não cabem
são listados). O leiaute da etiqueta que a balança imprime (prefixo, dígitos de código e de
valor) se configura em Configuração, com um campo **Testar etiqueta** para provar antes de
salvar.

### 30.9 Configurações (Sistema › Configurações — só Suporte)

Abas: **Padrões** (comportamentos do dia a dia, margem de lucro padrão, bloqueio por parcelas
em atraso, leiaute da etiqueta de balança com o "Testar etiqueta"), **Dados** (conexão — a
senha do banco não aparece —, Atualizar Dados, Atualizar Reports), **Emissor** (a empresa:
documento, IE, endereço, regime), **Impressão** (recibos e opções de impressão), **Fiscal** (certificado, séries, CSC/CSRT, RNTRC, devolução por referência,
repetir NCM) e **ADM** (Verificar Conexões, Ajustar tributação interestadual, ajuste de
tributação por produto, Migrar Dados, ativação). Mudança de conexão vale no **próximo início**
— a tela oferece reiniciar.

### 30.10 Atualização, Novidades e suporte

O sistema confere **uma vez por dia**, na abertura, se há versão nova; pergunta antes de
baixar; troca e reinicia. **Sobre › Atualizar** força a conferência agora; **Sobre › Novidades**
mostra o que mudou em cada versão, com busca por palavra ("caixa", "nota", "etiqueta").
**Sistema › Login Suporte** abre 7 minutos de operações de suporte com senha; **Logout
Suporte** fecha antes. **Sistema › Último Erro** mostra o registro do último problema.
**Sistema › Restaurar Backup** cria um banco à parte para conferência, não escreve no banco vivo.

---

## 31. O que parece defeito e não é

| O que se vê | Por quê |
|---|---|
| Botão **Faturar** apagado (mesa/pedido) | caixa fechado ou venda em andamento no carrinho — o título diz qual, em vermelho |
| Botão **Buscar** apagado com hora em vermelho (Utilidades DANFE) | trava de 1 hora da SEFAZ depois de uma consulta sem novidade |
| Botão **Imprimir** apagado no pedido | não há item para sair no papel (pedido novo vazio ou cancelado sem faturado) |
| Etiqueta de balança cai na busca normal em vez de lançar | o produto não está marcado como **Balança** no cadastro |
| Lista de compras vazia | mínimo não cadastrado nos produtos |
| Numeração do Gerador de Chaves conta como pendente | está pendente mesmo: é número em aberto esperando o Consultar |
| Manifesto importado aparece "em aberto" | encerramento só entra pelo **Consultar** |
| Nota antiga ainda imprime "Dados da fatura" | XML autorizado é imutável |
| Etiqueta sai sem cabeçalho | fantasia da loja não cadastrada |
| PDF da etiqueta sai em A4 | limitação do exportador; a impressão direta sai certa |
| Barra de progresso do zip "reinicia" | é por arquivo de dentro do pacote |
| "EMITIDA EM AMBIENTE DE HOMOLOGAÇÃO" numa nota autorizada | é homologação; some em produção |
| Carimbo de cancelado não aparece no DACTE em homologação | o literal de teste ocupa o mesmo lugar; só em produção |
| Cliente inativo barrado na venda a prazo | proposital: reativar → corrigir → desativar |
| Total de quantidade do relatório por produto soma KG com UN | proposital; o número que vale é o R$ |
| Nota parcialmente faturada (pedido) continua "aberta" | proposital |
| Trocar o cliente da NF não muda a tributação | o cenário sai só dos combos Destino e Consumidor final |
| Busca por número de versão em Novidades mostra a versão sem itens | o filtro é por palavra |

---

<!-- ============================================================================ -->
<!--  PARTE VIII                                                                  -->
<!-- ============================================================================ -->

# Parte VIII — Padronização para novos projetos

Dois projetos já nasceram deste padrão em setembro de 2026: o **New_RibaSoftADM** (reescrita do
ADM, sem ACBr, sem atualização automática, sem change log, sem tabelas de apoio — roda da pasta)
e o **EmissorDiario** (emissão diária de NFC-e em lote para as pastas de `D:\SistemasLocais`,
uma tela só). Os dois têm `CLAUDE.md`, `ESTADO.md` e `DECISOES.md` próprios na raiz. O que
segue é o que se replica — e o que se decide de novo.

## 32. O que se replica e em que ordem

### 32.1 Esqueleto

1. **Pastas**: `dataObject/`, `model/`, `controller/`, `view/`, `thread/`, `utils/`, `report/`
   (as que o projeto usar; o ADM não tem `report/`). `.gitignore` igual ao do NEW_Varejo.
2. **`utils/` replicado enxuto**: `RibaCore` (interfaces + `TPadraoView` + factories), `RibaDB`,
   `RibaTools`, `RibaConfig`, `RibaTypes`. `RibaApi`/`RibaACBr`/`RibaAtivacao`/`RibaEtiqueta`
   só se o projeto precisa (o ADM tem `ValidaCNPJ_CPF` próprio para não carregar o ACBr). O
   `RibaCore.lrs` só se o projeto embute o Firebird.
3. **`pVarejo.lpr` como molde do `.lpr`**: todas as units entram por ele; `Application.Scaled`;
   um form auto-criado só (`PrincipalView`). `.lpi` com `OtherUnitFiles` das pastas do projeto,
   modos Debug/Release separados (`lib\$(TargetCPU)-$(TargetOS)` × `...\release`),
   `i386`/`win32` fixados, `VersionInfo` com `AutoIncrementBuild`.
4. **`Limpar.bash`** adaptado (sem o bloco de Release se não publica).
5. **Pacote `ribasoft`** (`TBotao`) e o `ACBrEnterTab` no principal.
6. **Os três `.md`** na raiz desde o primeiro dia: `CLAUDE.md` (regras da sessão — copiar e
   ajustar), `ESTADO.md` (painel), `DECISOES.md` (começa pelas recusas do projeto novo).

### 32.2 As regras que valem em qualquer projeto RibaSoft

- Interfaces centralizadas (`RibaInterfaceData` para entidade, `RibaCore` para serviço);
  método público novo = classe + interface.
- Model factory, fluente, uma conexão por instância, `auxDB := nil` antes do `try`, `Rollback`
  + `raise CreateFmt` com `ClassName`/`%CURRENTROUTINE%`/`%LINE%`; crítica com `Riba.Aviso`
  antes.
- Esquema em código: `CriaTabelas` + `AtualizaColunas` com data no comentário; coluna nova nos
  dois lugares.
- Frames `TPadraoView`; diálogos `TForm` em variável local sem `ProcessMessages`; atalhos
  centralizados no principal; `TViews` no principal; navegação assíncrona com trava onde grava
  e navega.
- `EstilizaComponentes` como fonte do padrão visual (maiúsculas, pickers sem nulo, `KeyPreview`).
- Grades: colunas em código, `PintaLinhaGrade`, seleção por `'X'`, valor e quantidade
  centralizados, `Inc(I)` só com ocultas no fim.
- Português em tudo; cabeçalhos `//====`; `F*`/`A*`/`aux*`; sem "fase" em nome nenhum.
- Enum persistido cresce pelo fim; `TPermissao` idem.
- Todo caminho é **relativo ao diretório corrente** (`ARQUIVO_CONFIG = '.\Config.ini'`) — é o
  achado que sustenta o EmissorDiario: `SetCurrentDir(pasta do cliente)` + `NewConfig` faz o
  processo "virar" aquele cliente (banco, certificado, CSC, série e numeração vêm de lá).
- O que o cliente-alvo não usa não vira UI.

### 32.3 O que se decide de novo em cada projeto

Escrever no `DECISOES.md § 2` do projeto novo, no primeiro dia: atualização automática (sim/
não), change log (sim/não — e com ele, se "finalizar sessão" tem três passos ou dois), login/
usuário/permissões, fiscal (ACBr sim/não), tabelas de apoio, relatórios, backup, ativação.
O ADM recusou quase tudo isso porque é de uso próprio.

### 32.4 Regra de entrega nos projetos novos

Só a **primeira leva** (framework replicado, `.lpi`/`.lpr`, `.gitignore`, `Limpar.bash`, os
`.md`) foi escrita direto no disco, por ser volume grande em projeto vazio. **Daí em diante
todo código vai pelo chat** e é aplicado na IDE, como no NEW_Varejo. Os `.md` continuam sendo
editados direto.

## 33. Como trabalhar com assistente de código neste padrão

O que aprendemos sobre o **processo**, e que vale para qualquer projeto em que o código é
entregue no chat e aplicado à mão:

### 33.1 A entrega

- **Modo somente leitura no fonte** (`.pas`, `.lfm`, `.lpi`): o assistente analisa e propõe;
  quem aplica é o autor. Os `.md` o assistente edita direto.
- **Reler o arquivo do disco antes de propor código nele**, mesmo já lido na mesma sessão — o
  autor edita em paralelo. **Número de linha só vale para o arquivo que ele tem na tela agora**;
  nunca numerar em cima de um estado hipotético ("depois do `git checkout`").
- Cada instrução começa pela **ação em maiúsculas** — `SUBSTITUIÇÃO`, `INSERÇÃO`, `EXCLUSÃO` —
  seguida de `Depois da linha N — âncora:`. Substituição diz **"APAGUE as linhas X a Y"**,
  senão o código novo soma ao antigo. Acrescentar uma linha ao lado de uma âncora mostra o
  **bloco final com as duas** (senão vira substituição da âncora).
- **De baixo para cima** dentro de cada arquivo (maior linha primeiro): assim uma edição nunca
  desloca as seguintes. Vários arquivos: agrupar por arquivo.
- **Bloco colado sem a indentação inicial** (coluna 0, indentação relativa preservada): o
  Lazarus reindenta a partir do ponto de colagem. Bloco de **uma** linha vai junto do vizinho
  (uma linha sozinha cai na coluna 0).
- **SQL montado por `SQL.Add` é sempre bloco inteiro** — a vírgula da linha anterior some e o
  compilador não vê.
- Em tela com blocos quase idênticos (Rem/Rec/Dest/Exp), a âncora leva o **nome do
  `procedure` e a linha onde ele começa** — uma letra de diferença já mandou um bloco para o
  método errado.
- **`.lfm` novo = arquivo inteiro** (sem âncoras, sem `Glyph`; ele ajusta o visual).
  **`.lfm` existente = roteiro de componentes**, nunca patch de texto: nome, tipo, pai, evento →
  método, `Caption`, `MaxLength` e o que muda comportamento — sem `Left/Top/Width/Height/
  AnchorSide/BorderSpacing`. Componente novo = **dois passos** (lista → ele aplica → reler →
  código numerado), porque criar componente desloca as linhas do `.pas`; com handler novo,
  **três** (componentes → código com handlers declarados → ligar eventos), porque handler que
  não existe não aparece no OI.
- **Diff de formatação (Ctrl+D) e `ActivePage` regravado não se reportam.** Em vez de avisar
  o `ActivePage`, entregar a linha do `Create` que fixa a aba.
- Ao fechar uma frente: registrar "compila verde" + commit, e o que ele **testou e contou**.
  Nada de "runtime não testado".

### 33.2 A conferência

- **Commit não prova que foi aplicado.** `grep` do símbolo por bloco (pega o que **falta**);
  `git diff --stat` (pega colagem no arquivo **errado** e separa estética de perda);
  `lazbuild -B` (pega o **duplicado**); evento declarado × ligado no `.lfm` (pega o handler
  órfão). Só então o change log; só então o push.
- Quando ele diz "o comportamento não acontece", a primeira hipótese é **bloco não aplicado**.
- **Provar, não supor**: `fpc.exe` num `.pas` isolado para semântica, `isql` para DDL, cópia do
  projeto no scratchpad para compilar uma correção, script para conferir `INSERT` de 150
  colunas, `grep -rn` no ACBr inteiro antes de afirmar ausência.
- **Ao entregar regra fiscal, dizer em qual fonte se apoiou** — e não amaciar quando a fonte
  foi só o exemplo.

### 33.3 O que não se faz

- Não propor o que ele já recusou (cap. 24) sem que ele levante.
- Não listar esqueleto de tela, "fase", roteiro de teste ou prova de campo como pendência.
- Não criar helper novo (`InputQuery`, diálogo) sem `grep` no `RibaTools`/`view/` antes.
- Não introduzir convenção nova: olhar a tela irmã, a F-key que o projeto já usa, o alinhamento
  que as grades prontas têm.
- Não reescrever histórico publicado por estética (mensagem de commit torta fica).
- Não entregar comando que não foi rodado.

---

<!-- ============================================================================ -->
<!--  APÊNDICES                                                                   -->
<!-- ============================================================================ -->

# Apêndices

## A. Scripts de varredura

Todos rodam em segundos e pegam defeitos que **compilam verde**. Vale rodar depois de uma leva
grande de mexida em tela.

**A.1 Handler órfão** (declarado no `.pas`, sem evento no `.lfm`):

```bash
for u in view.cte view.cte_cadastro view.nf view.nf_cadastro; do
  grep -oE "procedure [A-Za-z0-9_]+\(Sender: TObject\);" view/$u.pas \
  | sed -E 's/procedure ([A-Za-z0-9_]+).*/\1/' | sort -u | while read h; do
      grep -q "= $h$" view/$u.lfm || echo "ORFAO em $u: $h"
    done
done
```

**A.2 `DataSource` apontando para o `Buf*` errado** (casa o sufixo do `DataSourceX` com o do
`DataSet`):

```bash
for f in view/*.lfm; do awk -v F="$f" '
/object DataSource[A-Za-z0-9_]*: TDataSource/ { name=$2; sub(":","",name); next }
name!="" && /DataSet = / { ds=$3; a=name; sub(/^DataSource/,"",a);
  b=ds; sub(/^(Buf|Query|Q|Zeos|Mem|DS)/,"",b);
  if (a!=b) printf "%s: %s -> %s\n", F, name, ds; name=""; next }
name!="" && /^  end/ { name="" }' "$f"; done
```

**A.3 Componente × campo publicado, e evento ligado × declarado, nos dois sentidos**: comparar
por script os `object X: TY` do `.lfm` com as declarações `X: TY;` do bloco publicado da classe
(do `= class(TPadraoView)` até o `private`), e os `On*** = Handler` com os `procedure Handler(`.
~20 linhas de Python.

**A.4 Reentrância**: `grep -rn "Application.CreateForm(T" --include=*.pas view/` (a variável
que recebe tem de ser `aux*`) e `grep -rn "Application.ProcessMessages" --include=*.pas view/ utils/`.

**A.5 Comentário que vira To-Do**: `grep -rniE "^\s*//\s*todo\b" --include=*.pas .`

**A.6 Métodos duplicados numa unit**: `grep -n "^function TClasse\.\|^procedure TClasse\." unit.pas`
e procurar nome repetido; na dúvida, `md5sum` das duas faixas.

**A.7 Pacote do ACBr no `.lpi`**: `grep PackageName pVarejo.lpi`.

**A.8 `.lrf`**: `.\audita_lrf.ps1` (do `pwsh` 7, sem argumento).

**A.9 Colunas órfãs do DDL**: cruzar as colunas de cada `CREATE TABLE` do `RibaDB.pas` com todo
`.pas`/`.lfm` — 47 tabelas, 657 colunas na última contagem; o que sobra no fiscal é DDL
completo de propósito.

## B. Mapa da `ImageList24_botoes` — 43 imagens, índices 0 a 42

| Idx | | Idx | | Idx | |
|---:|---|---:|---|---:|---|
| 0 | OK / Confirmar / Selecionar | 15 | Adicionar / Gerar | 30 | Ativar |
| 1 | Novo | 16 | Gerar carnê | 31 | Ver itens |
| 2 | Editar / Alterar | 17 | Estornar | 32 | Adicionar ao estoque |
| 3 | Salvar | 18 | Detalhar | 33 | E-mail |
| 4 | Cancelar | 19 | Transmitir | 34 | Restaurar QTD / desfazer |
| 5 | Excluir | 20 | Consultar / **buscar** (`btnBuscar` do DF-e, `btnConsultar` do CT-e) | 35 | Desvincular |
| 6 | Restaurar *(par do 5)* | 21 | Cancelar NF | 36 | Fracionar |
| 7 | Imprimir | 22 | Carta de correção | 37 | Ignorar |
| 8 | Lupa (os `btnBusca*` de cadastro) | 23 | Eventos | 38 | Itens da venda |
| 9 | Clonar | 24 | Exportar | 39 | NFC-e 65 |
| 10 | Aniversariantes | 25 | *(livre)* | 40 | NF-e 55 |
| 11 | *(livre)* | 26 | Contabilidade | 41 | Pagamentos |
| 12 | *(livre)* | 27 | XMLs | 42 | Parcelas |
| 13 | Filtrar | 28 | Vincular | | |
| 14 | Recalcular | 29 | Permissões | | |

⚠ 8 e 20 são os dois "busca" e já foram confundidos — **perguntar**, não deduzir pelo nome.
Atribuídos em código (não só no `.lfm`): 0, 5, 6, 8, 17. O par 5 ↔ 6 é aplicado nos **dois**
lugares que habilitam o botão (o `ModoEdicao` e o `CarregaDados`).

## C. Glossário

| Termo | Significado neste projeto |
|---|---|
| **Barreira** | `Valida*ParaEmissao`: o que se confere antes de falar com a SEFAZ |
| **dbo** | `dataObject` — entidade/DTO |
| **Factory** | as funções globais do `RibaCore` que devolvem instância nova de model/controller/entidade |
| **Frame × diálogo** | tela cheia `TPadraoView` × janela modal `TForm` |
| **Fluente** | métodos que devolvem `Self` para encadear (`acao(...).produto(...).salvar`) |
| **Snapshot** | a NF copia os dados do cliente no momento em que ele é aplicado |
| **Situação** | 0 rascunho · 1 transmitindo · 2 autorizada · 3 rejeitada · 4 cancelada · 5 denegada · 6 inutilizada/encerrado |
| **Suporte** | janela de 7 minutos com senha que libera operações administrativas (`PodeSuporte`) |
| **Terminal 1** | a estação que recarrega as tabelas de apoio sozinha |
| **NSU** | número sequencial da fila de documentos do CNPJ no Ambiente Nacional |
| **Resumo × nota** | `resNFe` (cabeçalho, antes da manifestação) × `procNFe` (completa) |
| **Esqueleto** | tela criada só no Object Inspector, sem lógica — proposital, não pendência |
| **Compila verde** | passa no `lazbuild` — o que não prova que foi aplicado, ligado ou que funciona |
| **Prova de campo** | uso real em cliente — estado que se registra, roteiro que não se escreve |
| **`§`** | seção do `DECISOES.md` |

<div style="text-align:center; margin-top:4em;">

*Fim.*

Este livro é um retrato de 12/09/2026. O estado vivo está no `ESTADO.md`; o porquê, no
`DECISOES.md`; o fiscal, no `FISCAL.md`. Quando discordarem, valem eles.

</div>
