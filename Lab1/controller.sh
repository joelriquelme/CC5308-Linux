#!/bin/bash

# controller.sh - Script para manejar la lógica del juego

# Importar funciones de board.sh si es necesario
if [ -f "board.sh" ]; then
    source board.sh
fi

# Directorio base del juego
BOARD_ROOT="./treasure_game"
TREASURE_INFO_FILE="./treasure_info"
TREASURE_ROUTE_FILE="./treasure_route"

# Función para seleccionar el tesoro
place_treasure() {
    local mode=$1
    local passphrase="mysecretpassphrase"
    local key_file="private.pem"
    
    # Verificar que el tablero existe
    if [ ! -d "$BOARD_ROOT" ]; then
        echo "Error: El tablero no existe. Crea el tablero primero." >&2
        return 1
    fi
    
    # Encontrar todos los archivos en el último nivel
    last_level_files=()
    while IFS= read -r -d $'\0' file; do
        last_level_files+=("$file")
    done < <(list_last_level_files)
    
    # Seleccionar un archivo al azar
    local total_files=${#last_level_files[@]}
    if [ "$total_files" -eq 0 ]; then
        echo "Error: No hay archivos en el tablero." >&2
        return 1
    fi
    
    local selected_index=$((RANDOM % total_files))
    local treasure_file="${last_level_files[$selected_index]}"
    
    # Procesar según el modo
    local relative_path="${treasure_file#$BOARD_ROOT/}"
    case $mode in
        "name")
            local relative_path="${treasure_file#$BOARD_ROOT/}"
            echo "$relative_path" > "$TREASURE_INFO_FILE"
            echo "$relative_path" > "$TREASURE_ROUTE_FILE"
            echo "Tesoro seleccionado: [nombre oculto]"  # Muestra la ruta completa
            ;;
            
        "content")
            local content=$(cat "$treasure_file")
            echo "$content" > "$TREASURE_INFO_FILE"
            echo "$relative_path" > "$TREASURE_ROUTE_FILE"
            echo "Tesoro seleccionado: [contenido oculto]"
            ;;
            
        "checksum")
            local checksum=$(sha256sum "$treasure_file" | awk '{print $1}')
            echo "$checksum" > "$TREASURE_INFO_FILE"
            echo "$relative_path" > "$TREASURE_ROUTE_FILE"
            echo "Tesoro seleccionado: [checksum oculto]"
            ;;
            
        "encrypted")
            # Generar nueva passphrase
            local new_passphrase=$(openssl rand -base64 16)
            
            # Crear nombre de archivo final (asegurar solo un .gpg)
            local final_file="${treasure_file%.gpg}.gpg"
            
            # Crear contenido nuevo y encriptarlo
            echo "Tesoro-$(date +%s)-${RANDOM}" | \
            gpg --batch --yes --passphrase "$new_passphrase" -o "$final_file" -c - 2>/dev/null
            
            # Eliminar el archivo original si existe
            [ -f "$treasure_file" ] 
            
            # Guardar la nueva passphrase
            echo "$new_passphrase" > "$TREASURE_INFO_FILE"
            echo "$relative_path" > "$TREASURE_ROUTE_FILE"
            echo "Tesoro seleccionado: [archivo re-encriptado]"
            ;;
            
        "signed")
            # Generar nuevo par de llaves
            openssl genrsa -out temp_private.pem 2048 2>/dev/null
            openssl rsa -in temp_private.pem -pubout -out temp_public.pem 2>/dev/null
            
            # Eliminar cualquier firma previa
            rm -f "${treasure_file}.sig"
            
            # Crear contenido nuevo para el archivo
            echo "ContenidoFirmado-$(date +%s)-${RANDOM}" > "$treasure_file"
            
            # Firmar el archivo (creará solo un archivo.sig)
            openssl dgst -sha256 -sign temp_private.pem -out "${treasure_file}.sig" "$treasure_file"
            
            # Guardar solo la llave pública en TREASURE_INFO_FILE
            cat temp_public.pem > "$TREASURE_INFO_FILE"
            
            # Limpieza
            rm -f temp_private.pem temp_public.pem
            
            # Retornar la llave pública
            cat "$TREASURE_INFO_FILE"
            echo "Tesoro seleccionado: $treasure_file (firmado con nueva llave)"
            ;;

    esac
    
    return 0
}

# Función auxiliar para listar archivos del último nivel (alternativa a find)
list_last_level_files() {
    local current_depth=0
    local current_dirs=("$BOARD_ROOT")
    
    while [ "$current_depth" -lt "$depth" ]; do
        local next_dirs=()
        for dir in "${current_dirs[@]}"; do
            for subdir in "$dir"/dir_*/; do
                next_dirs+=("$subdir")
            done
        done
        current_dirs=("${next_dirs[@]}")
        current_depth=$((current_depth + 1))
    done
    
    for dir in "${current_dirs[@]}"; do
        for file in "$dir"/file_*.txt*; do
            if [ -f "$file" ]; then
                printf "%s\0" "$file"
            fi
        done
    done
}

# Función para verificar el tesoro (P4)
verify() {
    local candidate=$1
    local mode=$2
    
    if [ ! -f "$TREASURE_INFO_FILE" ]; then
        echo "Error: No se ha seleccionado un tesoro aún." >&2
        return 2
    fi
    
    case $mode in
        "name")
            local treasure_name=$(cat "$TREASURE_INFO_FILE")
            [ "$(basename "$candidate")" == "$(basename "$treasure_name")" ] && return 0 || return 1
            ;;
            
        "content")
            local treasure_content=$(cat "$TREASURE_INFO_FILE")
            [ "$(cat "$candidate")" == "$treasure_content" ] && return 0 || return 1
            ;;
            
        "checksum")
            local treasure_checksum=$(cat "$TREASURE_INFO_FILE")
            [ "$(sha256sum "$candidate" | awk '{print $1}')" == "$treasure_checksum" ] && return 0 || return 1
            ;;
            
        "encrypted")
            candidate="${candidate}.gpg"
            # Verificar que existe el archivo de passphrase
            if [ ! -f "$TREASURE_INFO_FILE" ]; then
                echo "Error: No se ha configurado una passphrase" >&2
                return 2
            fi
            
            # Verificar que el candidato existe y es un archivo .gpg
            if [ ! -f "$candidate" ] || [[ "$candidate" != *.gpg ]]; then
                return 1
            fi
            
            # Intentar desencriptar con la passphrase almacenada
            local passphrase=$(cat "$TREASURE_INFO_FILE")
            if gpg --batch --passphrase "$passphrase" -d "$candidate" &>/dev/null; then
                return 0
            else
                return 1
            fi
            ;;
            
        "signed")
            # Verificar que existe la llave pública
            if [ ! -f "$TREASURE_INFO_FILE" ]; then
                echo "Error: No se encontró la llave pública" >&2
                return 2
            fi
            
            # Verificar que existen tanto el archivo como su firma
            if [ ! -f "$candidate" ] || [ ! -f "${candidate}.sig" ]; then
                return 1
            fi
            
            # Verificar la firma usando la llave pública almacenada
            if openssl dgst -sha256 -verify "$TREASURE_INFO_FILE" -signature "${candidate}.sig" "$candidate" &>/dev/null; then
                return 0
            else
                return 1
            fi
            ;;
            
        *)
            echo "Error: Modo no válido" >&2
            return 2
            ;;
    esac
}
