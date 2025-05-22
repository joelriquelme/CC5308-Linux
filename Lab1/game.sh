#!/bin/bash

# game.sh - Script principal del juego

# Importar los scripts necesarios
source board.sh
source controller.sh

# Configuración inicial
BOARD_ROOT="./treasure_game"
GAME_MODE=""
DIFFICULTY_LEVEL=""
TREASURE_ROUTE_FILE="./treasure_route"

# Función para mostrar el menú principal
show_main_menu() {
    clear
    echo "===================================="
    echo "      JUEGO DE BÚSQUEDA DEL TESORO"
    echo "===================================="
    echo
    echo "Modos de juego disponibles:"
    echo "1) Buscar por nombre de archivo"
    echo "2) Buscar por contenido"
    echo "3) Buscar por checksum"
    echo "4) Buscar archivo encriptado"
    echo "5) Buscar archivo firmado"
    echo "6) Salir"
    echo
    read -p "Seleccione un modo de juego (1-6): " mode_choice

    case $mode_choice in
        1) GAME_MODE="name";;
        2) GAME_MODE="content";;
        3) GAME_MODE="checksum";;
        4) GAME_MODE="encrypted";;
        5) GAME_MODE="signed";;
        6) exit 0;;
        *) echo "Opción inválida"; sleep 1; return 1;;
    esac

    echo
    echo "Niveles de dificultad:"
    echo "1) Fácil (3 niveles, 2 directorios, 3 archivos)"
    echo "2) Medio (4 niveles, 3 directorios, 5 archivos)"
    echo "3) Difícil (5 niveles, 4 directorios, 7 archivos)"
    echo "4) Personalizado"
    echo
    read -p "Seleccione dificultad (1-4): " diff_choice

    case $diff_choice in
        1) create_board 3 2 3;;
        2) create_board 4 3 5;;
        3) create_board 5 4 7;;
        4)
            read -p "Profundidad (niveles): " depth
            read -p "Ancho (directorios por nivel): " width
            read -p "Archivos por directorio final: " files
            create_board $depth $width $files
            ;;
        *) echo "Opción inválida"; sleep 1; return 1;;
    esac
}

# Función para llenar el tablero según el modo
prepare_game() {
    echo
    echo "Preparando el juego en modo $GAME_MODE..."
    
    # Llenar el tablero según el modo
    fill_board "$GAME_MODE"
    
    # Esconder el tesoro
    place_treasure "$GAME_MODE"
    
    echo "¡Todo listo! El tesoro está escondido."
    sleep 3
}

# Función principal del juego
game_loop() {
    attempts=0
    found=false
    
    while ! $found; do
        clear
        echo "=== Modo: $GAME_MODE ==="
        echo "Intentos: $attempts"
        echo
        echo "Ingrese la ruta completa del archivo que cree es el tesoro"
        echo "o escriba 'salir' para terminar el juego"
        echo "La ruta debe tener la forma: treasure_game//dir_1//dir_2//...//file_n.txt"
        echo
        read -p "Ruta: " user_path

        # Verificar si quiere salir
        if [ "$user_path" = "salir" ]; then
            echo
            read -p "¿Quiere revelar la ubicación del tesoro? (s/n): " reveal
            if [ "$reveal" = "s" ]; then
                echo "El tesoro está en: $(cat $TREASURE_ROUTE_FILE| head -n 2 | tail -n 1)"
                sleep 5
            fi
            return
        fi

        # Verificar la ruta
        if verify "$user_path" "$GAME_MODE"; then
            echo "¡Felicidades! ¡Encontraste el tesoro!"
            echo "Ubicación: $user_path"
            found=true
        else
            echo "Lo siento, ese no es el tesoro. Sigue intentando."
            ((attempts++))
        fi
        
        sleep 1
    done
    
    echo
    echo "Juego terminado. Total de intentos: $attempts"
    read -p "Presione Enter para volver al menú principal..."
}

# Bucle principal del juego
while true; do
    if show_main_menu; then
        prepare_game
        game_loop
    fi
done