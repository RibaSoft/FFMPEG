#!/bin/bash
# Script para baixar as músicas da lista em MP3 usando yt-dlp
# Uso: ./baixar_hinos.sh [arquivo_com_links.txt]

LISTA="${1:-lista.txt}"
DESTINO="./Musicas"

# Verifica se o yt-dlp está instalado
if ! command -v yt-dlp &> /dev/null; then
    echo "yt-dlp não encontrado. Instale com:"
    echo "  sudo apt update && sudo apt install -y yt-dlp"
    echo "ou (versão mais recente):"
    echo "  pip install -U yt-dlp"
    exit 1
fi

# Verifica se o arquivo de lista existe
if [ ! -f "$LISTA" ]; then
    echo "Arquivo '$LISTA' não encontrado!"
    echo "Coloque o arquivo com os links na mesma pasta ou passe o caminho:"
    echo "  ./baixar_hinos.sh /caminho/para/lista.txt"
    exit 1
fi

mkdir -p "$DESTINO"

# Remove duplicatas e linhas vazias, mantendo a ordem original
LISTA_LIMPA=$(mktemp)
awk 'NF && !visto[$0]++' "$LISTA" > "$LISTA_LIMPA"

TOTAL=$(wc -l < "$LISTA_LIMPA")
echo "Iniciando download de $TOTAL músicas para $DESTINO ..."
echo ""

yt-dlp \
    -x --audio-format mp3 --audio-quality 0 \
    -o "$DESTINO/%(title)s.%(ext)s" \
    --download-archive "$DESTINO/.baixados.txt" \
    --ignore-errors \
    --no-overwrites \
    -a "$LISTA_LIMPA"

rm -f "$LISTA_LIMPA"

echo ""
echo "Concluído! Arquivos salvos em: $DESTINO"
