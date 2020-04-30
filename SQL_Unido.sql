-- Borramos la tabla por si ha tenido problemas, aunque en teoría no existe
DROP TABLE `help_relation_recovered`;

--Creamos la Tabla con el sufijo "_recovered" o le pueden poner uno a su gusto
CREATE TABLE `help_relation_recovered` (
  `help_topic_id` int(10) unsigned NOT NULL  /* MYSQL_TYPE_LONG */,
  `help_keyword_id` int(10) unsigned NOT NULL  /* MYSQL_TYPE_LONG */,
  PRIMARY KEY (`help_keyword_id`,`help_topic_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 STATS_PERSISTENT=0 COMMENT='keyword-topic relation';

-- Eliminamos el TABLESPACE que se creo nuevo
ALTER TABLE `help_relation_recovered` DISCARD TABLESPACE;

-- ! Ejecutar en Terminal de archivos
-- * Copiar archivo con los datos en tabla nueva
cp help_relation.ibd help_relation_recovered.ibd

-- * Asignarle los permisos al usuario de MySqL
chown mysql:mysql help_relation_recovered.ibd

-- ! Volvemos a la consola con MySql
-- * Importamos los Datos (TABLESPACE) del archivo que recien copiamos
ALTER TABLE `help_relation_recovered` IMPORT TABLESPACE;

-- * Validamos que funcione correctamente
SELECT * FROM `help_relation_recovered` LIMIT 10;

-- * Borramos la tabla dañada
DROP TABLE `help_relation`;

-- ! Ejecutar en Terminal de archivos
-- * Borrar el archivo viejo
rm help_relation.ibd

-- ! Volvemos a la consola con MySql
-- * Renombramos la tabla nueva, como la original
ALTER TABLE `help_relation_recovered` RENAME `help_relation`;

-- * Validamos que todo esté correcto
SELECT * FROM help_relation LIMIT 10;


-- ! Validar el tipo de Registro si vienen de diferente versión de MySql
-- ROW_FORMAT=compact
