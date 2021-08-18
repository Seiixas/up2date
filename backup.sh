#! /bin/bash

Configuracao() {
  echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■ Configurações ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
  echo ""
  read -p " Usuário /home deste computador  :  " usuario
  read -p " Usuário do banco de dados       :  " usuario_bd
  read -p " Senha do banco de dados         :  " pswd

  echo "  pcuser = $usuario
  userdb = $usuario_bd
  passdb = $pswd" > /home/backup.conf
  
  if [ $? -eq 0 ]; then
    echo ""
    echo " Seu arquivo de configurações foi criado em: /home/backup.conf"
  else
    echo " O arquivo de configurações /home/backup.conf não foi criado"
    echo " Diretório de backup criado com sucesso em: /home/$usuario/backup/" 
  fi
  echo ""
  echo " Para iniciar o backup, execute o comando: "
  echo "    sudo sh backup.sh database=NOME_DO_BANCO rclone=NOME_DO_RCLONE"
  echo ""
  echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
}

ProcessoBackup() {
  echo "------------------------------------------------------------------------------------------------------------------------------" >> $LOG_FILE
  DATA_ATUAL=$(date +"%d/%m/%Y-%H:%M:%S")
  echo "[$DATA_ATUAL] PROCESSO DE BACKUP INICIADO"

  # Define nome do arquivo .sql com a data do backup
  DATA_ATUAL=$(date +"%d-%m-%Y_%H-%M-%S")
  NOME_FINAL="$DB"_"$DATA_ATUAL.sql"
    
  # Realiza o backup do banco de dados
  $(`mysqldump --user=$USER -p$PSWD $DB > $LOCAL_DIR/$NOME_FINAL` > /dev/null 2>&1) 

  # Se o backup deu certo
  if [ $? -eq 0 ]; then 

    # Escreve mensagem em tela e no arquivo de log
    echo "[$(date +"%d/%m/%Y-%H:%M:%S")] BACKUP LOCAL REALIZADO COM SUCESSO ($LOCAL_DIR/$NOME_FINAL)"
    echo "[$(date +"%d/%m/%Y-%H:%M:%S")] BACKUP LOCAL CRIADO EM   : $LOCAL_DIR/$NOME_FINAL" >> $LOG_FILE

    # Copia backup local para Google Drive
    $(/usr/bin/rclone copy --update --verbose --transfers 30 --checkers 8 --contimeout 60s --timeout 60s --retries 3 --low-level-retries 10 --stats 1s "$LOCAL_DIR/$NOME_FINAL" "$GDRIVE_DIR" > /dev/null 2>&1)

    # Se a cópia para o GDrive foi bem sucedida:
    if [ $? -eq 0 ]; then

      # Escreve mensagem em tela e no arquivo de log
      echo "[$(date +"%d/%m/%Y-%H:%M:%S")] BACKUP COPIADO PARA GDRIVE COM SUCESSO! ($GDRIVE_DIR/$NOME_FINAL)"
      echo "[$(date +"%d/%m/%Y-%H:%M:%S")] BACKUP ENVIADO AO GDRIVE : $GDRIVE_DIR/$NOME_FINAL" >> $LOG_FILE

      # Aguarda 3 segundos e apaga o backup local
      sleep 3

      $(`rm -rf $LOCAL_DIR/$NOME_FINAL`)
      
      # Escreve mensagem em tela e no arquivo de log
      echo "[$(date +"%d/%m/%Y-%H:%M:%S")] BACKUP LOCAL DELETADO! ($LOCAL_DIR/$NOME_FINAL)"
      echo "[$(date +"%d/%m/%Y-%H:%M:%S")] BACKUP LOCAL DELETADO    : $LOCAL_DIR/$NOME_FINAL" >> $LOG_FILE

      $(/usr/bin/rclone copy --update --verbose --transfers 30 --checkers 8 --contimeout 60s --timeout 60s --retries 3 --low-level-retries 10 --stats 1s "$LOG_FILE" "$GDRIVE_DIR_LOG" > /dev/null 2>&1)


    # Se a cópia para o GDrive não foi bem sucedida
    else
      echo "ERRO AO COPIAR ARQUIVO PARA O GOOGLE DRIVE"
      echo "Por motivos de segurança, o backup local será mantido em $LOCAL_DIR"
    fi

  # Se o backup não deu certo
  else
    echo "ERRO AO TENTAR BACKUP!"
  fi

  echo "------------------------------------------------------------------------------------------------------------------------------" >> $LOG_FILE
}

Principal() {
  
  config="/home/backup.conf"
  # Carrega os dados do arquivo /home/backup.conf
  USUARIOPC=$(grep 'pcuser' $config | awk -F" " '{print $3 ; }')
  USER=$(grep 'userdb' $config | awk -F" " '{print $3 ; }')
  PSWD=$(grep 'passdb' $config | awk -F" " '{print $3 ; }')

  # Define o diretório local e on-line (GDrive) para o destino do backup e do log
  FOLDER_NAME="$(date +%Y)/$(date +%b)"
  GDRIVE_DIR_LOG="$GDRIVE_DIR:DATABASE_$DB"
  GDRIVE_DIR="$GDRIVE_DIR:DATABASE_$DB/$FOLDER_NAME"
  LOCAL_DIR="/home/$USUARIOPC/backup/DATABASE_$DB/$FOLDER_NAME"
  LOG_FILE="/home/$USUARIOPC/backup/DATABASE_$DB/$DB.log"
  

  if [ ! -d $LOCAL_DIR ]; then
    $(`mkdir -p $LOCAL_DIR`)
  fi
    
  # Inicia o processo de backup
  ProcessoBackup

}

clear

if ! [ $(id -u) = 0 ]; then
  echo "■■■■■■■■■■■■■■■■■■■■■■■■■ ROOT REQUERIDO ■■■■■■■■■■■■■■■■■■■■■■■■■"
  echo "■                   Execute o script com sudo                    ■"
  echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
  exit 1
else
  if [ -z "$1" ]; then
    echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ OOPS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
    echo "■               Insira algum parâmetro                                  ■"
    echo "■                                                                       ■"
    echo "■ Para executar o backup automaticamente, use:                          ■"
    echo "■   sudo sh backup.sh database=NOME_DO_BANCO rclone=NOME_DO_RCLONE      ■"
    echo "■                                                                       ■"
    echo "■ Para configurar o backup, use:                                        ■"
    echo "■   sudo sh backup.sh config                                            ■"
    echo "■                                                                       ■"
    echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
    exit 1
  elif [ $1 = "config" ]; then
    Configuracao
  else
    params=$1
    params_prefix="${params%%=*}"
    if [ $params_prefix = "database" ]; then
      DB="${params#*=}"

      if [ -z "$2" ]; then
        echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ OOPS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
        echo "■               Insira algum parâmetro                                  ■"
        echo "■                                                                       ■"
        echo "■ Para executar o backup automaticamente, use:                          ■"
        echo "■   sudo sh backup.sh database=NOME_DO_BANCO rclone=NOME_DO_RCLONE      ■"
        echo "■                                                                       ■"
        echo "■ Para configurar o backup, use:                                        ■"
        echo "■   sudo sh backup.sh config                                            ■"
        echo "■                                                                       ■"
        echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
        exit 1
      else
        params=$2
        params_prefix="${params%%=*}"
        if [ $params_prefix = "rclone" ]; then
          GDRIVE_DIR="${params#*=}"
          Principal
        else
          echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ OOPS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
          echo "■               Está faltando o parâmetro database                      ■"
          echo "■                                                                       ■"
          echo "■ Para executar o backup automaticamente, use:                          ■"
          echo "■   sudo sh backup.sh database=NOME_DO_BANCO rclone=NOME_DO_RCLONE      ■"
          echo "■                                             ^^^^                      ■"
          echo "■ Para configurar o backup, use:                                        ■"
          echo "■   sudo sh backup.sh config                                            ■"
          echo "■                                                                       ■"
          echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
          exit 1
        fi
      fi
    else 
        echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ OOPS ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
        echo "■               Está faltando o parâmetro database                      ■"
        echo "■                                                                       ■"
        echo "■ Para executar o backup automaticamente, use:                          ■"
        echo "■   sudo sh backup.sh database=NOME_DO_BANCO rclone=NOME_DO_RCLONE      ■"
        echo "■                      ^^^^^^                                           ■"
        echo "■ Para configurar o backup, use:                                        ■"
        echo "■   sudo sh backup.sh config                                            ■"
        echo "■                                                                       ■"
        echo "■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■"
        exit 1
    fi
  fi
fi
