#Limpa
cd /d/Documents/GitHub/FFMPEG
rm -rf lib
rm -f *.lps
rm -f *.res
rm -f *.log
rm -f *.dbg
rm -f pFFMPEG_debug.exe

# ⚠ O yt-dlp.exe da pasta NÃO se apaga: é a cópia que o "Atualizar yt-dlp" mantém e que o
# programa usa no lugar da do Chocolatey (DECISOES.md § 3). O *.exe do .gitignore já a deixa
# fora do git.

git status

# Manda Pro GitHub
echo "Precione Enter para Mandar para o Git..."
read -p ""
clear

# Sem bloco de Release/publicação: o FFMPEG é de uso próprio, roda direto da pasta do projeto,
# sem .zip no servidor e sem atualização automática.

# Pede a mensagem do commit
data_hora=$(date +"%Y%m%d_%H%M")
read -p "Digite a mensagem do commit (Enter para usar a data/hora): " mensagem
if [ -z "$mensagem" ]; then
    mensagem="$data_hora"
fi

git add .
git commit -m "$mensagem"
git push -u origin main

rm -rf lib
rm -f *.lps
rm -f *.res

echo "Enviado ao GitHub com sucesso!"
read -p "";
clear
