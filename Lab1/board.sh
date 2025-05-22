#!/bin/bash

# board.sh - Script para crear y limpiar el tablero del juego

# Directorio base donde se creará la estructura
BOARD_ROOT="$(dirname "$0")/treasure_game"
depth=-1  # Variable global para la profundidad
width=-1   # Variable global para el ancho
files=-1   # Variable global para archivos
file_counter=1 # Contador de archivos

# Función para limpiar el tablero anterior
clean_board() {
    if [ -d "$BOARD_ROOT" ]; then
        if rm -rf "$BOARD_ROOT"; then
            echo "Tablero anterior limpiado en $BOARD_ROOT."
        else
            echo "Error: No se pudo limpiar el tablero anterior. ¿Problema de permisos?" >&2
            return 1
        fi
    else
        echo "No existía un tablero anterior en $BOARD_ROOT."
    fi
}

# Función para crear el tablero
create_board() {
    depth=$1
    width=$2
    files=$3
    file_counter=1  # Reiniciar contador de archivos
    
    # Validar parámetros
    if [ "$depth" -lt 1 ] || [ "$width" -lt 1 ] || [ "$files" -lt 1 ]; then
        echo "Error: Todos los parámetros deben ser mayores a 0" >&2
        return 1
    fi
    
    if ! clean_board; then
        return 1
    fi
    
    echo "Creando tablero con depth=$depth, width=$width, files=$files en $BOARD_ROOT..."
    
    # Crear directorio raíz (nivel 0)
    mkdir -p "$BOARD_ROOT" || return 1
    
    # Inicializar lista de directorios del nivel actual (comienza en nivel 0)
    current_dirs=("$BOARD_ROOT")
    
    # Crear estructura de directorios nivel por nivel (empezando desde nivel 1)
    for ((level=0; level<=depth; level++)); do
        next_dirs=()
        for dir in "${current_dirs[@]}"; do
            if [ "$level" -eq "$depth" ]; then
                # En el último nivel, crear archivos
                for ((f=1; f<=files; f++)); do
                    # Crear un archivo con un nombre único
                    # Crear el archivo en el directorio actual
                    touch "${dir}/file_${file_counter}.txt" || return 1
                    file_counter=$((file_counter + 1))
                done
            else
                # En niveles intermedios, crear subdirectorios
                for ((w=1; w<=width; w++)); do
                    new_dir="${dir}/dir_${w}"
                    mkdir -p "$new_dir" || return 1
                    next_dirs+=("$new_dir")
                done
            fi
        done
        if [ "$level" -ne "$depth" ]; then
            current_dirs=("${next_dirs[@]}")
        fi
    done
    
    echo "Tablero creado exitosamente en $BOARD_ROOT"
    echo "Estructura creada:"
    tree "$BOARD_ROOT" -L "$depth" 2>/dev/null || ls -R "$BOARD_ROOT"
    return 0
}

# Función para llenar el tablero según el modo de juego (sin usar find)
fill_board() {
    local mode=$1
    local passphrase="mysecretpassphrase"  # Passphrase para encriptación
    local private_key="private.pem"        # Llave privada para firma
    
    echo "Llenando tablero en modo: $mode"
    
    # Función recursiva para procesar directorios
    process_directories() {
        local current_dir=$1
        local current_depth=$2
        
        if [ "$current_depth" -eq "$depth" ]; then
            # Estamos en el último nivel, procesar archivos
            for file in "$current_dir"/file_*.txt; do
                case $mode in
                    "name")
                        # Modo name: archivos pueden quedar vacíos
                        ;;
                    "content"|"checksum")
                        # Modo content/checksum: contenido aleatorio
                        echo "$(date +%s%N | sha256sum | base64 | head -c 32)" > "$file"
                        ;;
                    "encrypted")
                        # Modo encrypted: contenido no vacío + encriptar
                        echo "Contenido para encriptar $(date +%s%N)" > "$file"
                        gpg --batch --passphrase "$passphrase" -c "$file" && rm "$file"
                        ;;
                    "signed")
                        # Modo signed: contenido no vacío + firmar
                        echo "Contenido para firmar $(date +%s%N)" > "$file"
                        # Generar par de llaves si no existen
                        if [ ! -f "$private_key" ]; then
                            openssl genrsa -out "$private_key" 2048
                            openssl rsa -in "$private_key" -pubout -out public.pem
                        fi
                        openssl dgst -sha256 -sign "$private_key" -out "$file.sig" "$file"
                        ;;
                esac
            done
        else
            # Procesar subdirectorios recursivamente
            for subdir in "$current_dir"/dir_*/; do
                process_directories "$subdir" $((current_depth + 1))
            done
        fi
    }
    
    # Comenzar el procesamiento desde el directorio raíz (nivel 0)
    process_directories "$BOARD_ROOT" 0
    
    echo "Tablero llenado exitosamente en modo $mode"
}

# Función auxiliar para generar contenido aleatorio (alternativa)
generate_random_content() {
    LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32
}




