# Recuperar datos desde archivos .frm y .ibd de MySql

Esto es una recopilación de información que encontré en diferentes foros de ayuda ([1](https://superuser.com/questions/675445/mysql-innodb-lost-tables-but-files-exist), [2](https://medium.com/@alexquick/transporting-mysql-tablespaces-from-5-6-to-5-7-517c01345fbb), [3](https://stackoverflow.com/questions/47075429/error-setting-up-mysql-table-mysql-plugin-doesnt-exist) y otros por ahí en **Inglés**) que me sirvió para recuperar más de 40 tablas luego de que fallaran las 3 fuentes de energía y el servidor se apagara repentinamente. 

*(Algunos en la comunidad seguro se sentirán más cómodos leyendo las instrucciones en español, por eso dediqué algo de tiempo a crear esta pequeña guía)*

**Con esta guía se recuperaron Datos de MySql 5.6 para luego importarlos a MySql 5.7 (incluyendo sus cambios en *ROW_FORMAT*; no he corroborado su funcionamiento en versiones más recientes**

# Errores

Había perdido información en varias tablas de varias bases de datos en el mismo servidor, por eso los procesos fallaban al iniciarse, pero además, no se podían ejecutar las actualizaciones de paquetes tipo **apt-get upgrade** porque siempre habían errores dentro de *MySql*.

**Error de actualización de MySql**
```
Checking if update is needed.
Checking server version.
Running queries to upgrade MySQL server.
mysql_upgrade: [ERROR] 1146: Table 'mysql.plugin' doesn't exist
mysql_upgrade failed with exit status 5
 dpkg: error processing package mysql-server-5.7 (--configure):
  subprocess installed post-installation script returned error exit status 1
```
**Errores en Tablas**

    mysqlcheck -u root -p --all-databases --auto-repair

> Error : Table 'mysql.help_relation' doesn't exist
> status : Operation failed
> mysql.help_topic
> Error : Table 'mysql.help_topic' doesn't exist
> status : Operation failed
> mysql.innodb_index_stats
> Error : Table 'mysql.innodb_index_stats' doesn't exist
> status : Operation failed
> mysql.innodb_table_stats
> Error : Table 'mysql.innodb_table_stats' doesn't exist
> status : Operation failed
> mysql.plugin
> Error : Table 'mysql.plugin' doesn't exist
> status : Operation failed

## Explicación Corta

**SIEMPRE CREA UN RESPALDO DE TODOS LOS ARCHIVOS DE *MySql* (antes de comenzar)**

La solución es recrear el DDL de la creación de la tabla con toda su estructura igual a la que se perdió, eliminar el TABLESPACE de la nueva, copiar el IBD anterior, importar el TABLESPACE anterior (que si contiene los datos), eliminar tabla vieja y archivos viejos para seguidamente cambiar el nombre de la tabla por la original.

Es algo tedioso hacerlo tabla por tabla, se puede hacer un script que lo intente recuperar, pero preferí ver los outputs uno por uno, pues me dio oportunidad de corregir errores mientras iban sucediendo. *(el cambio de ROW_FORMAT entre versiones por ejemplo)*

## Recuperación DDL Estructura de tablas

En teoría se puede extraer la estructura de la tabla con **mysqlfrm**, sin embargo si tienes un usuario root con contraseña seguramente la pasarás mal tratando de extraer los datos y levantar una segunda instancia de MySql.

A mi, particularmente me funcionó muy bien [DBSake](https://github.com/abg/dbsake/) que es de código abierto, fácil de instalar, accesible desde GitHub, y realizo el trabajo rápidamente y sin complicaciones.

**Instrucciones**: Descargar el programa, Darle permisos de ejecución:

```sh
$  curl -s http://get.dbsake.net > dbsake

$  chmod u+x dbsake
```

El siguiente comando te imprimirá en pantalla el "CREATE TABLE" de la tabla que necesitas:
```sh
$ ./dbsake frmdump --type-codes /var/lib/mysql/database-name/tbl.frm
```
En mi caso preferí extraer todos los DDL de todos los archivos .FRM que tenía en la carpeta pues eran muchas las tablas con errores.

```sh
$ ./dbsake frmdump --type-codes /var/lib/mysql/mysql/*.frm > mysqlSchemas.sql
```
Ejemplo del DDL Generado dentro de mysqlSchemas.sql:

```sql
    --
    -- Table structure for table `help_relation`
    -- Created with MySQL Version 5.7.25
    --

    CREATE  TABLE  `help_relation` (
    `help_topic_id`  int(10) unsigned NOT  NULL  /* MYSQL_TYPE_LONG */,
    `help_keyword_id`  int(10) unsigned NOT  NULL  /* MYSQL_TYPE_LONG */,
    PRIMARY  KEY (`help_keyword_id`,`help_topic_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 STATS_PERSISTENT=0 COMMENT='keyword-topic relation';
```

## Recuperando los Datos

*(Recuerda que al inicio mencioné que debías haber hecho un respaldo, nada mejor que estar preparados en caso de borrar un archivo que no debías borrar, o que el mismo MySql lo decida eliminar) - **Además recuerda que estos archivos se copian luego de haber detenido el servicio de MySql, si los copias mientras el motor de bases de datos se encuentra activo, es probable que los copies con errores, es decir archivos corruptos***

Comencemos: 

Accede desde terminar a MySql, y seguidamente a tu base de datos, ejemplo:

```sh
$ mysql -u root -p
```

y luego :

```sql
    USE mysql;
```

**Abre otra consola** *(Si, tendrás 2 abiertas)* para que tengas a mano los archivos que necesitas ir copiando y ubícate en la carpeta donde se encuentren los archivos de datos de MySql. 
```sh
    su
```

(ingresas la contraseña de root)

vamos a ubicarnos en donde tenemos los archivos de la base de datos, en mi caso

```sh
    cd /var/lib/mysql/mysql
```

Ahora comenzaremos a recuperar los datos, creando una tabla temporal con la copia idéntica de la estructura antigua, que ya hemos recuperado en el paso anterior.

Pensé en agregar "_recovered" a cada tabla mientras iba trabajando con ella de forma temporal, vamos a la consola que se encuentra conectada a MySql:

```sql
    CREATE TABLE `help_relation_recovered` (
      `help_topic_id` int(10) unsigned NOT NULL  /* MYSQL_TYPE_LONG */,
      `help_keyword_id` int(10) unsigned NOT NULL  /* MYSQL_TYPE_LONG */,
      PRIMARY KEY (`help_keyword_id`,`help_topic_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 STATS_PERSISTENT=0 COMMENT='keyword-topic relation';
```

**------ En caso que tu Tabla venga de MySQL 5.6 o anteriores ------**

Debes validar bien el valor *ROW_FORMAT* pues es diferente en cada versión de MySql.
La Tabla que estas creando debe tener el mismo valor de ROW_FORMAT que el IBD anterior, de lo contrario tendrás un error llamado "mismatch" que se produce cuando las filas tienen diferente formato.

Para solucionar esto debes agregar al final del Create Table:

```sql
    ROW_FORMAT=compact
```

Dependiendo del formato que del que venía anteriormente (Segun la versión de MySql).

**-------------------------------------------------------------------------------**

Luego de haber creado la tabla se debe de eliminar su IBD desde MySql:

```sql
    ALTER  TABLE  `help_relation_recovered` DISCARD TABLESPACE;
```

Seguidamente desde la consola de archivos (segunda consola que abrimos), vamos a copiar el IBD con los datos que queremos recuperar, a la tabla nueva que hemos creado temporal : 

```sh
    cp help_relation.ibd  help_relation_recovered.ibd
```

y seguidamente le vamos a dar permiso al usuario de MySql para que pueda accesar el archivo :

```sh
    chown mysql:mysql help_relation_recovered.ibd
```

Volvemos a la consola conectada a MySql y ahora importamos el TABLESPACE que hemos copiado del archivo:

```sql
    ALTER  TABLE  `help_relation_recovered` IMPORT TABLESPACE;
```

y verificamos que la tabla sea accesible, si contiene datos veremos los primeros 10, si no contiene, simplemente dirá que contiene 0 registros:

```sql
    SELECT  *  FROM  `help_relation_recovered`  LIMIT  10;
```

Limpiamos MySql de la tabla que estamos rescatando inicialmente, asegurándonos que no exista dentro del motor:

```sql
    DROP  TABLE  `help_relation`;
```

Regresamos a la Segunda Consola (archivos) y eliminamos el archivo de datos IBD antiguo:

```sh
    rm help_relation.ibd
```

Como se encuentra limpio y la tabla inicial ya no existe ni en archivos ni el motor de base de datos, ahora procedemos a renombrar la tabla recuperada, tal como el nombre de la original :

```sql
    ALTER  TABLE  `help_relation_recovered` RENAME `help_relation`;
```

y por último validamos que todo esté correcto : 

```sql
    SELECT  *  FROM help_relation LIMIT  10;
```

**¡FELICIDADES! Lograste recuperar la tabla desde los archivos FRM (Esquema) e IBD (Datos) de MySQL**

## Posibles Errores

Como mencioné anteriormente, dependiendo si la versión donde están importando los Datos IBD es diferente; deben validar el Parámetro *ROW_FORMAT*, de lo contrario pueden aparecer errores como el siguiente : 

> ERROR 1808 (HY000): Schema mismatch (Table has ROW_TYPE_DYNAMIC row
> format, .ibd file has ROW_TYPE_COMPACT row format.)

En este caso del ejemplo, MySQL 5.7 usa por defecto **ROW_TYPE_DYNAMIC** 
y MySql 5.6 (de donde lo estaba importando) usa por defecto **ROW_TYPE_COMPACT** 

Es por eso que arriba les indicaba el valor que debe agregarse al final del CREATE TABLE, para indicar el formato de Registro de la Tabla, y así ser compatibles con el archivo IBD que están por restaurar.

    ROW_FORMAT=compact


Gracias! , si te sirvió, agradezco que le coloques una estrella al repo.

