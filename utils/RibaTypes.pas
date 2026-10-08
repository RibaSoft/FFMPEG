unit RibaTypes; {$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

const
  COR_FUNDO = $0008bbff;
  COR_FONTE = $00D27619;
  COR_FUNDO_COMPONENT = $00faf9f8;

  //========================================================== EXECUTÁVEIS =====================================================\\
  // Procurados no PATH (instalados pelo Chocolatey). O yt-dlp tem uma exceção: se existir uma
  // cópia na pasta do programa, ela vence — é a cópia que o botão "Atualizar yt-dlp" mantém
  // (DECISOES.md § 3).
  YTDLP_EXE = 'yt-dlp.exe';
  YTDLP_LOCAL = '.\yt-dlp.exe';
  FFMPEG_EXE = 'ffmpeg.exe';
  FFPROBE_EXE = 'ffprobe.exe';
  CURL_EXE = 'curl.exe';
  TASKKILL_EXE = 'taskkill.exe';

  // Endereço oficial do executável do yt-dlp (sempre a versão estável mais nova).
  YTDLP_URL_DOWNLOAD = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';

  //=========================================================== DOWNLOAD =======================================================\\
  // O formato do baixar_Video_projetor.bat: até 1080p, só H.264 (avc1) + AAC (mp4a).
  YTDLP_FORMATO_H264 = 'bv*[height<=1080][vcodec^=avc1]+ba[acodec^=mp4a]/b[height<=1080][vcodec^=avc1]';
  // Acrescentado ao de cima quando o "converter se não for H.264" está marcado: se o vídeo não
  // tem avc1, aceita o melhor até 1080p — e a conversão depois resolve o codec.
  YTDLP_FORMATO_QUALQUER = '/bv*[height<=1080]+ba[acodec^=mp4a]/bv*[height<=1080]+ba/b[height<=1080]';
  // Lista dos IDs já baixados, na pasta de destino (o --download-archive do baixar_hinos.sh).
  YTDLP_HISTORICO = '.baixados.txt';

  // Marcadores que os templates de --print / --progress-template põem na frente de cada linha,
  // para a leitura da saída separar o que é progresso do que é mensagem.
  MARCA_PROGRESSO = '[PROG]';
  MARCA_POS_PROCESSO = '[POS]';
  MARCA_ITEM = '[ITEM]';
  MARCA_ARQUIVO = '[ARQ]';

  //========================================================== CONVERSÃO =======================================================\\
  PREFIXO_CONVERTIDO = 'conv_';
  // Arquivo temporário da conversão automática depois do download (vira o nome original no fim).
  SUFIXO_TEMPORARIO = '.convertendo.mp4';
  // Status do WhatsApp: o vídeo sai cortado em pedaços deste tamanho (o último fica com a sobra).
  PEDACO_SEGUNDOS = 30;

  FILTRO_VIDEOS = 'Vídeos|*.mp4;*.mkv;*.webm;*.mov;*.avi;*.wmv;*.flv;*.m4v;*.mpg;*.mpeg;*.ts;*.3gp|Todos os arquivos|*.*';
  FILTRO_LISTA = 'Lista de links (*.txt)|*.txt|Todos os arquivos|*.*';

type
  //============================================================= ENUMERATORS ==================================================\\
  // ⚠ A ordem é a do RadioGroupTipo (Items no .lfm): ItemIndex 0 = Vídeo, 1 = MP3.
  TTipoBaixar = (tbVideo, tbMP3);

  // ⚠ A ordem é a do ComboBoxTipo, que é preenchido em código a partir do PRESET_NOME.
  TPresetConversao = (pcSite1080, pcSite720, pcProjetor, pcWhatsApp);

  TTipoTarefa = (ttBaixar, ttConverter, ttAtualizar);

  // O que uma linha da saída do yt-dlp / ffmpeg é, depois de lida pelo model.
  TTipoLinha = (tlLog, tlProgresso, tlItem, tlArquivo, tlIgnorar);

  //=============================================================== RECORDS ====================================================\\
  // Um passo de progresso, já pronto para a tela.
  //   Percentual = 0..100, ou -1 quando não dá para saber (a barra fica parada).
  //   Detalhe    = o que vai no LabelStatus depois do nome do item.
  TProgresso = record
    Percentual: double;
    Detalhe: string;
  end;

  // O que o ffprobe diz de um arquivo. Codec vazio = o arquivo não tem aquela trilha.
  TSonda = record
    Duracao: double;          // em segundos; 0 = desconhecida
    CodecVideo: string;
    CodecAudio: string;
  end;

const
  PRESET_NOME: array[TPresetConversao] of string = (
    'Site 1080p (MP4 H.264 + AAC)',
    'Site 720p - menor (MP4 H.264 + AAC)',
    'Projetor 1080p (MP4 H.264 + AAC)',
    'Status WhatsApp - pedaços de 30s (MP4 H.264 + AAC)');

implementation

//==============================================================================================================================\\
end.
