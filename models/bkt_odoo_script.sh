#!/bin/bash
# Script que reinicia odoo y el módulo pasado por el archivo de configuraciones.odoo,
# siempre que este último exista.

# Variables que determinan el valor por defecto de los
# distintos archivos a manejar.
declare -r ruta_archivo_conf_default='/etc/odoo/odoo.conf'
declare -r ruta_archivo_log_default='/var/log/odoo/odoo-server.log'
declare -r ruta_archivo_servicio='/lib/systemd/system/bkt_odoo.service'

# Variables cuyo valor dependen del archivo de configuración,
# y de las condiciones codificadas.
ruta_archivo_conf=''
ruta_archivo_log=''
rutas_addons_arr=()
nombre_base_datos=$1
nombre_modulo=$2

# Método el cual saca la ruta de configuración de Odoo del archivo .service, 
# el cual representa 
get_archivo_configuracion() {
    grep_exec_start_odoo_service=$(cat /lib/systemd/system/odoo.service | grep -w ExecStart)

    exec_start_array=($(echo $grep_exec_start_odoo_service | tr " " "\n"))
    
    ruta_archivo_conf="${exec_start_array[2]}"

    # ruta_archivo_conf=${grep_w_archivo_configuracion#*archivo_conf = }

    echo $ruta_archivo_conf
}

# Salida a consola para obtener la ruta al archivo de configuración,
# y por consiguiente las rutas de addons y el archivo de .log
echo "Leyendo el archivo de configuración..."
get_archivo_configuracion

# Método para conseguir al ruta del archivo log del archivo .conf de Odoo
get_ruta_log() {
    # Sacamos la línea donde aparece el parámetro logfile del archivo .conf
    # de Odoo
    grep_w_ruta_log=$(grep -w 'logfile' $ruta_archivo_conf)

    # Solo muestra apartir de lo que venga después de #*,
    # en este caso conseguimos la ruta de el archivo .log
    ruta_archivo_log=${grep_w_ruta_log#*logfile = }
}

# Método para conseguir las rutas de addons del archivo .conf de Odoo
get_rutas_addons() {
    # En este caso sacamos el parámetro addons_path del archivo
    # de configuración de Odoo
    grep_w_ruta_addons=$(grep -w 'addons_path' $ruta_archivo_conf)

    # Solo muestra apartir de lo que venga después de #*,
    # en este caso conseguimos las rutas de modulos addons
    addons_paths_str=${grep_w_ruta_addons#*addons_path = }

    # En este caso hace un split del string con las distintas rutas,
    # convirtiendo este string en un array(addons_paths_arr), el cual tiene como delimiter
    # la coma.
    IFS=',' read -ra rutas_addons_arr <<<"$addons_paths_str"
}

# Método para comprobar la existencia de los archivos existentes en odoo.conf
comprobante_conf_log() {
    # Condición en el caso de que el archivo .conf no exista
    if [ ! -f "$ruta_archivo_conf" ]; then
        # Cambio de valor de la variable de ruta al archivo de
        # configuración de Odoo
        echo "El archivo configuración pasado por parámetro no existe, procediendo a utilizar el de por defecto"
        ruta_archivo_conf=$ruta_archivo_conf_default
    fi
    get_ruta_log
    # Condición en el caso de que el archivo .log no exista
    if ! test -f "$ruta_archivo_log"; then
        # Cambio de valor de la variable de ruta al archivo
        # .log de Odoo
        ruta_archivo_log=$ruta_archivo_log_default
    fi

    # Llamada a métodos get para conseguir datos esenciales ()
    get_rutas_addons

    # # Imprimir en consola todas las rutas recogidas de addons
    # printf '%s\n' "${rutas_addons_arr[@]}"
}

# Llamada al método de comprobación de existencia de el archivo .conf
comprobante_conf_log

echo "Leyendo la base de datos..."
echo "Nombre de base de datos: $nombre_base_datos"

comprobante_base_datos() {
    # Constantes las cuales definen los alias de los campos con los
    # que trabajamos de la base de datos
    declare -r nombre_alias_sql="\"Name\""
    declare -r owner_alias_sql="\"Owner\""

    # Comando para conectarse a la base de datos y realizar una consulta,
    # la cual da de resultado el usuario odoo de la base de datos, siempre
    # que exista el usuario, y por lo tanto esté Odoo instalado.
    get_username_command=$(sudo -u postgres -H -- psql -c "SELECT usename
    FROM pg_catalog.pg_user
    WHERE pg_user.usename = 'odoo'
    ORDER BY pg_user.usename desc;" | grep "odoo")

    # En este condicional complejo se valora si el string resultante del comando
    # anterior, y basado en eso se sigue con la ejecución normal o para en seco debido
    # a la no existencia del mismo.
    if test -z $get_username_command; then
        echo "No existe el usuario 'odoo' en la base de datos, comprobar la existencia del mismo"
        restart_odoo
    else
        # Comando preparado para comprobar si existe la base de datos en cuestión, y en
        # tal caso conseguir su dueño para comprobar si el mismo es el usuario odoo.
        get_database_owner_command=$(sudo -u postgres -H -- psql -c "SELECT d.datname as ${nombre_alias_sql},
            pg_catalog.pg_get_userbyid(d.datdba) as ${owner_alias_sql}
            FROM pg_catalog.pg_database d
            WHERE d.datname = '${nombre_base_datos}'
            ORDER BY 1;" | grep "${nombre_base_datos}")

        # Condicional el cual comprueba la existencia del registro con el nombre de la base de datos
        # pasado por parámetro, en resumen, si existe o no la base de datos en cuestión.
        if [ -n "$get_database_owner_command" ]; then
            # Conversión de salida de consola de postgresql, a string preparado para hacer
            # split ($get_database_owner_command_output), ya que el mismo tiene el nombre de la
            # base de datos en el caso de que exista y el dueño de la misma
            get_database_owner_command_output=${get_database_owner_command//[|]/,}

            get_database_owner_command_output=${get_database_owner_command_output// /}

            # En esta línea de código hacemos split a la variable $get_database_owner_command_output.
            # mediante el método read, y utilizando el delimitador pasado por la variable IFS, dando
            # lugar a un array el cual tiene los dos datos que necesitamos.
            IFS="," read -ra database_owner_arr <<<"$get_database_owner_command_output"

            # En este caso, tenemos un condicional el cual comprueba si la base de datos en cuestión
            # tiene como dueño el usuario 'odoo', por obvias razones.
            if [ "${database_owner_arr[1]}" != "odoo" ]; then
                echo "La base de datos especificada por parámetro no tiene como dueño el usuario odoo"
                exit
            fi
        else
            echo "La base de datos especificada por parámetro no existe"
            exit
        fi
    fi
}

comprobante_base_datos

echo "Comprobando la existencia del módulo en cuestión..."
echo $nombre_modulo

# Método el cual comprueba la existencia del módulo pasado por parámetro,
# comprobando si está en alguna de las rutas de módulos, las cuales fueron
# sacadas del archivo .conf de Odoo. En este caso cambia el valor de la
# variable booleana module_exists a true, y rompe el bucle en caso que se
# cumpla la condición.
comprobante_modulo() {
    module_exists=false
    for addons_path_index in "${rutas_addons_arr[@]}"; do
        if ! test -z $(ls $addons_path_index | grep -w $nombre_modulo); then
            module_exists=true
            break
        fi
    done
}

# Función preparada para cambiar el comando que ejecuta el comando bkt_odoo, 
# para que así después de haber sido parado, se modifique el comando que ejecute
# el odoo junto con la actualización del módulo
modificador_comando_servicio() {
    # Aquí actualiza el campo ExecStart del archivo .service de bkt_odoo, para así
    # saber donde remplazar con el sed después
    grep_execstart_service=$(grep 'ExecStart=' $ruta_archivo_servicio)

    # Aquí se ensambla el texto el cual va a estar en esa línea en cuestión
    new_execstart_service="ExecStart=sudo -u odoo /usr/bin/python3 /usr/bin/odoo --config $ruta_archivo_conf --logfile $ruta_archivo_log -u $nombre_modulo -d $nombre_base_datos"
    
    if [ "$grep_execstart_service" != "$new_execstart_service" ]; then
        # Remplazamos el comando antiguo por el nuevo del archivo .service
        sed -i "s|$grep_execstart_service|$new_execstart_service|g" $ruta_archivo_servicio
        echo "Si se ha remplazado"
    fi
}

# Método en el cual se realizan los comandos principales de la aplicación, donde se inicia odoo, actualizando
# el módulo en cuestión además de añadiendo los parámetros de la ruta del archivo .conf, del archivo .log y
# la base de datos en cuestión.
condicionante_modulos() {
    # Llamada al módulo el cual comprueba si existe el módulo o no.
    comprobante_modulo

    # Condición para los casos de la variable booleana, la cual determina si existe o no, el módulo en cuestión.
    if ! $module_exists; then
        echo "No se ha escrito un nombre de módulo válido"
        exit
    else
        # En este caso se para el servicio, se modifica el comando en el servicio, y se vuelve a iniciar
        is_odoo_active=$(systemctl is-active odoo)
        if [[ "$is_odoo_active" == "active" ]]; 
        then
            systemctl stop odoo
            echo 'El servicio de Odoo ha sido detenido con éxito'
        fi
        # Reinicio y modificación de el servicio propio para el reinicio de Odoo
        systemctl stop bkt_odoo
        modificador_comando_servicio
        systemctl daemon-reload
        systemctl start bkt_odoo
        # Imprimir en pantalla si el servicio está activo
        systemctl is-active bkt_odoo
        # Imprimir los errores y variables que se imprimen en el logger del módulo
    fi
}

condicionante_modulos