# FFMPEG — Estado

Painel: uma linha por frente. O porquê está no `DECISOES.md`.

## 1. Frentes

| Frente | Estado |
|---|---|
| Baixar vídeo (link do campo), ≤1080p H.264 + AAC | Código pronto, compila verde (03/10/2026). **Ainda não rodou download real.** |
| Baixar MP3 (link do campo), com histórico `.baixados.txt` | Código pronto, compila verde. **Ainda não rodou download real.** |
| Importar lista `.txt` (limpa vazios, comentários e repetidos) | Código pronto; `LimpaLista` provada no teste de console (03/10/2026). **Ainda não rodou download real.** |
| "Converter se não for H.264" no download de vídeo | Código pronto, compila verde. **Ainda não rodou** (depende de download real). |
| Converter vários vídeos (`conv_<nome>.mp4`), 4 presets | **Provado** por teste de console no scratchpad (03/10/2026): nome com acento, nome repetido vira `(2)`, altura ímpar corrigida, arquivo inexistente conta erro. |
| Status WhatsApp (pedaços de 30s exatos) e corte de início/fim na conversão | **Provado** por teste de console com a thread real (08/10/2026): pedaços de 30,00s, vertical/horizontal, `%` no nome, repetido vira `(2)`, corte maior que o vídeo conta erro, cancelar apaga todos os pedaços. Testado pela tela pelo Ribamar (08/10/2026): ok. |
| Cancelar | **Provado** na conversão (03/10/2026): parou no meio, apagou a saída parcial, nenhum `ffmpeg.exe` sobrou. No download, ainda não rodou. |
| Atualizar yt-dlp (cópia local + `--update`) | Código pronto, compila verde. **Ainda não rodou.** |
| Tela | Componentes criados e ligados; abre sem erro de `.lfm` (03/10/2026). Layout e ancoragem: do Ribamar. |
