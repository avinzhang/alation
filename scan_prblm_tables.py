#!/opt/alation/env/bin/python
#!! safe : true
#!! hidden : false
#!! description : clean up tables that cause problems during upgrades
#!! warning : this will override existing settings

'''
Runs database tooling to clean up postgres problematic tables
    Use 'p' flag to prune tables
    If no 'p' flag is passed, the script will only print statements
'''
from __future__ import print_function
import os
import logging
import sys
import argparse
import math
import alation_util.pgsql_util as util
from logging.handlers import RotatingFileHandler
from datetime import datetime, timedelta
from prettytable import PrettyTable
import pandas as pd
import subprocess
import shlex

logger = logging.getLogger('scan_prblm_tables')

def init_logging():
    """
    Initialize logging for postgres scan
    """
    scan_log = '/opt/alation/site/logs/scan-prblm-tables.log'
    if os.path.isfile(scan_log):
        if not os.access(scan_log, os.W_OK):
            os.system("sudo chmod 664 {}".format(scan_log))
    streamhandler = logging.StreamHandler(sys.stdout)
    filehandler = logging.handlers.RotatingFileHandler(
        scan_log, maxBytes=5000000, backupCount=5)
    logger.addHandler(streamhandler)
    logger.addHandler(filehandler)  
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    streamhandler.setFormatter(formatter)
    filehandler.setFormatter(formatter)
    logger.setLevel(logging.DEBUG)
    logger.info("")
    logger.info("--------------------------------------")
    logger.info("                                      ")
    logger.info("   Scan Postgres Problematic Tables   ")
    logger.info("                                      ")
    logger.info("--------------------------------------")
    logger.info("")
    logger.info("   By: Alation Professional Services")
    logger.info("Timestamp: {}".format(datetime.now()))
    logger.info("")
    logger.info("--------------------------------------")

def set_indexscan(cursor, scan):
    """
    Disable/Enable postgresql indexscan
    """
    cursor.execute('SET enable_indexscan = {};'.format(scan))
    cursor.execute('SET enable_bitmapscan = {};'.format(scan))
    cursor.execute('SET enable_indexonlyscan = {};'.format(scan))

def run_psql(sql, variables=None, index_scan=True):
    """
    Runs the given sql query and returns the fetched results
    """
    try:
        conn = util.connect()
        cursor = conn.cursor()
        command = sql.split()[0].lower()
        if (command == "drop" or command == "delete" or command == "vacuum") :
            conn.autocommit = True
        else:
            conn.autocommit = False
        if index_scan:
            set_indexscan(cursor, 'on')
        else:
            set_indexscan(cursor, 'off')
        if variables is None:
            cursor.execute(sql)
        else:
            cursor.execute(sql, variables)
        
        if (command == "select" or command == "explain" or "with") :
            records = cursor.fetchall()
        elif (command == "delete"):
            records = cursor.rowcount
        else :
            records = None
        conn.close()
        return records
    except Exception as err:
        logger.error("Postgres run psql failed: {}".format(err))
        return err
    finally:
        logger.info("Sql statement executed successfully")
        if conn is not None:
            conn.close()

def get_top100_tables(null1, null2):
    """
    Get a list of top 100 biggest tables
    """
    try:
        logger.info("--- Starting execution of get top 100 tables ---")
        sql = "WITH RECURSIVE pg_inherit(inhrelid, inhparent) AS \
        (select inhrelid, inhparent \
        FROM pg_inherits \
        UNION \
        SELECT child.inhrelid, parent.inhparent \
        FROM pg_inherit child, pg_inherits parent \
        WHERE child.inhparent = parent.inhrelid), \
        pg_inherit_short AS (SELECT * FROM pg_inherit WHERE inhparent NOT IN (SELECT inhrelid FROM pg_inherit)) \
        SELECT table_schema, TABLE_NAME , row_estimate, pg_size_pretty(total_bytes) AS total, pg_size_pretty(index_bytes) AS INDEX, \
        pg_size_pretty(toast_bytes) AS toast, pg_size_pretty(table_bytes) AS TABLE \
        FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes \
            FROM ( \
            SELECT c.oid , nspname AS table_schema, relname AS TABLE_NAME, SUM(c.reltuples) OVER (partition BY parent) AS row_estimate, \
            SUM(pg_total_relation_size(c.oid)) OVER (partition BY parent) AS total_bytes, SUM(pg_indexes_size(c.oid)) OVER (partition BY parent) AS index_bytes, \
            SUM(pg_total_relation_size(reltoastrelid)) OVER (partition BY parent) AS toast_bytes, parent \
          FROM ( \
                SELECT pg_class.oid, relkind, reltuples, relname, relnamespace, pg_class.reltoastrelid, COALESCE(inhparent, pg_class.oid) parent \
                FROM pg_class \
                    LEFT JOIN pg_inherit_short ON inhrelid = oid \
                WHERE relkind IN ('r', 'p') \
             ) c \
             LEFT JOIN pg_namespace n ON n.oid = c.relnamespace \
            WHERE nspname NOT IN ( 'pg_catalog', 'information_schema') \
            AND c.relkind <> 'i' AND nspname !~ '^pg_toast' \
            ) a \
            WHERE oid = parent \
        ) a \
        ORDER BY total_bytes DESC limit 100;"
        records = run_psql(sql, None, True)
        table = PrettyTable(['Schema', 'Relation', 'Row Estimate', 'Total Size', 'Index', 'Toast', 'Table'])
        for row in records:
            table.add_row([row[0], row[1], row[2], row[3], row[4], row[5], row[6]])
        logger.info("*** Top 100 tables by size *** \n" + str(table))
        return records
    except Exception as error:
        logger.error("Postgres get top 100 tables failed: {}".format(error))
        raise Exception("Postgres get top 100 tables failed: {}".format(error))
    finally:
        logger.info("--- Finished execution of get top 100 tables ---")

def purge_old_metadata_tables(purge, null2):
    """
    Purge metadata tables that are no longer needed as Alation will only display 20 weeks old
    """
    try:
        logger.info("--- Starting execution of purge old metadata tables ---")
        twth_week_of = datetime.now() - timedelta(days=((datetime.now().isoweekday() + 133)))
        current_week_of = datetime.now() - timedelta(days=((datetime.now().isoweekday() % 7)))
        range = pd.date_range(twth_week_of,current_week_of, freq='MS').strftime("y%Y-%m").tolist()
        tables_not_to_purge = []
        tables_to_purge = []
        for m_y in range:
            tables_not_to_purge.append("'rosemeta_metadatachangelog_"+m_y.replace("-","m")+"'")
            tables_not_to_purge.append("'rosemeta_metadatachangestats_"+m_y.replace("-","m")+"'")
            tables_not_to_purge.append("'rosemeta_metadatachangechildrenstats_"+m_y.replace("-","m")+"'")
        sql = "SELECT table_name, table_schema, pg_size_pretty(pg_relation_size(quote_ident(table_name))) AS total_size \
        FROM information_schema.tables \
        WHERE (table_name ~ '^rosemeta_metadatachangelog_' or table_name ~ '^rosemeta_metadatachangestats_' or table_name ~ 'rosemeta_metadatachangechildrenstats_') \
        AND table_name NOT IN ("+','.join(tables_not_to_purge)+")" \
        +"union all \
        select '-------------------------------------------------', '------------' as table_schema, '------------' as total_size \
        union all \
        select 'TOTAL', '' as table_schema, pg_size_pretty(sum(total_size)) as total \
        from (SELECT table_name, table_schema, pg_relation_size(quote_ident(table_name))::BIGINT AS total_size \
        FROM information_schema.tables \
        WHERE (table_name ~ '^rosemeta_metadatachangelog_' or table_name ~ '^rosemeta_metadatachangestats_' or table_name ~ 'rosemeta_metadatachangechildrenstats_') \
        AND table_name NOT IN ("+','.join(tables_not_to_purge)+")) as metadata;"
        records = run_psql(sql, None, True)
        if (len(records) > 2) :
            table = PrettyTable(['Relation', 'Schema Name', 'Total Size'])
            for row in records:
                table.add_row([row[0], row[1], row[2]])
                tables_to_purge.append("DROP TABLE IF EXISTS "+row[1]+"."+row[0]+";")
            logger.info("*** Scan revealed the metadata tables below can be removed *** \n" + str(table))
            if (purge == "purge"):
                logger.info("Attempting to purge tables")
                for row in tables_to_purge:
                    logger.info(row)
                    run_psql(row, None, True)
        else :
            logger.info("***** Scan revealed NO metadata tables can be purged *****")
    except Exception as error:
        logger.error("Postgres purge old metadata tables failed: {}".format(error))
    finally:
        logger.info("--- Finished execution of purge old metadata tables ---")
        
def get_table_stats(table_name, query_count):
    sql = "SELECT l.metric,  \
        CASE \
            WHEN l.metric = '---------------------------------' THEN '-------------' \
            ELSE l.nr::TEXT \
        END AS bytes, \
        CASE \
            WHEN l.metric = '---------------------------------' THEN '-------------' \
            WHEN is_size THEN pg_size_pretty(nr)::TEXT \
            WHEN is_size = 'false' THEN 'N/A' \
        END AS bytes_pretty, \
        CASE \
            WHEN l.metric = '---------------------------------' THEN '-------------' \
            WHEN is_size THEN round(cast(nr as decimal) / NULLIF(x.ct, 0),3)::TEXT \
            WHEN is_size = 'false' THEN 'N/A' \
        END AS bytes_per_row \
    FROM  ( \
    SELECT min(tableoid)        AS tbl \
            , count(*)             AS ct \
            , sum(length(t::text)) AS txt_len \
    FROM {} t \
    ) x \
    CROSS  JOIN LATERAL ( \
    VALUES \
    (true , 'core_relation_size'               , pg_relation_size(tbl)) \
    , (true , 'visibility_map'                   , pg_relation_size(tbl, 'vm')) \
    , (true , 'free_space_map'                   , pg_relation_size(tbl, 'fsm')) \
    , (true , 'table_size_incl_toast'            , pg_table_size(tbl)) \
    , (true , 'indexes_size'                     , pg_indexes_size(tbl)) \
    , (true , 'total_size_incl_toast_and_indexes', pg_total_relation_size(tbl)) \
    , (true , 'live_rows_in_text_representation' , txt_len) \
    , (false, '---------------------------------'   , NULL) \
    , (false, 'row_count'                        , ct) \
    , (false, 'live_tuples'                      , pg_stat_get_live_tuples(tbl)) \
    , (false, 'dead_tuples'                      , pg_stat_get_dead_tuples(tbl)) \
    , (false, 'rows_to_purge'                    , ({}) \
    ) l(is_size, metric, nr);".format(table_name,query_count)
    records = run_psql(sql, None, True)
    total_rows = records[8][1]
    total_size = records[5][2]
    total_removed_rows = records[11][1]
    total_removed_size = convert_size(float(total_removed_rows)*float(records[5][3]))
    table = PrettyTable(['Metric', 'Bytes', 'Bytes Pretty', 'Bytes Per Row'])
    for row in records:
        table.add_row([row[0], row[1], row[2], row[3]])   
    logger.info("*** {} stats *** \n{}".format(table_name,str(table)))
    logger.info("*** Scan revealed {} records from a total of {} records can be removed from {} table ***".format(total_removed_rows, total_rows, table_name))
    logger.info("*** Overall space saved if purge was executed: {} of total: {} ***".format(total_removed_size, total_size))

def convert_size(size_bytes):
   if size_bytes == 0:
       return "0B"
   size_name = ("bytes", "kB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
   i = int(math.floor(math.log(size_bytes, 1024)))
   p = math.pow(1024, i)
   s = round(size_bytes / p, 2)
   return "%s %s" % (s, size_name[i])

def clear_metrics_tables(purge, date):
    try:
        logger.info("--- Starting execution of clear metrics tables ---")        
        date = datetime.strptime(date, '%Y-%m-%d').strftime("%Y-%m-%d")
        count_query = "select count(event_id) as count from metrics_event where metric_ptr_id in (select id from metrics_metric where ts_created < '{}'))".format(date)
        get_table_stats("metrics_event", count_query)
        count_query = "select count(id) from metrics_metric where ts_created < '{}')".format(date)
        get_table_stats("metrics_metric", count_query)
        if (purge == "purge"):
            sql = "delete from metrics_event where metric_ptr_id in (select id from metrics_metric where ts_created < '"+date+"');"
            records = run_psql(sql, None, True)
            logger.info("*** Number of records removed from metrics_event table: {} ***".format(records))
            sql = "vacuum full metrics_event;"
            records = run_psql(sql, None, True)
            logger.info("*** Vacuum against metrics_event was successful")
            sql = "delete from metrics_metric where ts_created < '"+date+"';"
            records = run_psql(sql, None, True)
            logger.info("*** Number of records removed from metrics_metric table: {} ***".format(records))
            sql = "vacuum full metrics_metric;"
            records = run_psql(sql, None, True)
            logger.info("*** Vacuum against metrics_metric was successful")
    except Exception as error:
        logger.error("Postgres clear metrics tables failed: {}".format(error))
    finally:
        logger.info("--- Finished execution of clear metrics tables ---")

def run_command(command):
    process = subprocess.Popen(shlex.split(command), stdout=subprocess.PIPE)
    while process:
        output = process.stdout.readline().decode("utf-8") 
        if output == '' and process.poll() is not None:
            break
        if output:
            logger.info(output.strip().format(output))
    rc = process.poll()
    return rc

def cleanup_blobaccesspostgres(purge, date):
    try:
        logger.info("--- Starting execution of cleanup blobaccesspostgres ---")
        logger.info("Invoking purge_execution_results from django manager")
        # Use default values for batch size and log location
        sql = "select min(ts_created) from public.rosemeta_executionresult;"
        records = run_psql(sql, None, True)
        start_date = records[0][0]
        start_date = start_date.strftime('%Y-%m-%d')
        end_date = date
        batch_size_days = 10
        log = '/opt/alation/site/logs/'
        
        output = run_command("python /opt/alation/django/manage.py purge_execution_results {} {} {} {} {}".format(
            start_date,
            end_date,
            "-bs {}".format(batch_size_days),
            "-p {}".format(purge),
            "-lf {}".format(log),
        ))
        logger.info("purge_execution_results returned with exit code: {}".format(output))
        if (purge == 'purge'):
            sql = "vacuum full data_storage_blobaccesspostgres;"
            records = run_psql(sql, None, True)
            logger.info("*** Vacuum against data_storage_blobaccesspostgres was successful")
            sql = "vacuum full rosemeta_executionresult;"
            records = run_psql(sql, None, True)
            logger.info("*** Vacuum against rosemeta_executionresult was successful")
    except Exception as error:
        logger.error("Postgres cleanup blobaccesspostgres failed: {}".format(error))
    finally:
        logger.info("--- Finished execution of cleanup blobaccesspostgres ---")
        
def get_qli_archive_stats(purge, date):
    
    EXECUTION_EVENT_TABLE = 'rosemeta_executionevent'
    
    EXECUTION_MENTIONS_TABLES = [
    'rosemeta_executioneventmention',
    'rosemeta_executioneventunresolvedmention',
    'rosemeta_executioneventexpressionmention',
    ]
    
    try:
        logger.info("--- Starting execution of QLI archive ---")
        sql = "SELECT id FROM {} ORDER BY id ASC LIMIT 1;".format(EXECUTION_EVENT_TABLE)
        first_event_id = run_psql(sql, None, True)
        if (len(first_event_id) == 0):
            logger.warning("rosemeta_executionevent does not have any data. Unable to run QLI Archive.")
            return
        else:
            first_event_id = first_event_id[0][0]
            max_event_id_to_archive = None
            for table_name in EXECUTION_MENTIONS_TABLES:
                sql = "SELECT coalesce(min(event_id), 0) FROM {0} \
                WHERE id >= ( SELECT coalesce(min(pointer), 0) FROM message_queue_pointer WHERE table_name = '{0}');".format(table_name)
                table_max_event_id = run_psql(sql, None, True)[0][0]
                if max_event_id_to_archive is None:
                    max_event_id_to_archive = table_max_event_id
                else:
                    max_event_id_to_archive = min(max_event_id_to_archive, table_max_event_id)
            max_event_id_to_archive = max_event_id_to_archive - 1
        
        if first_event_id >= max_event_id_to_archive or max_event_id_to_archive <= 0:
            logger.warning("QLI hasn't processed enough data yet, so nothing can be archived.")
        else:
            archive_struct = []
            archive_struct.append([EXECUTION_EVENT_TABLE,first_event_id, max_event_id_to_archive])
            for table in EXECUTION_MENTIONS_TABLES:
                sql = "SELECT coalesce(max(id), 0) FROM {} WHERE event_id <= {};".format(table_name, max_event_id_to_archive)
                table_max_id = run_psql(sql, None, True)
                sql = "SELECT id FROM {} ORDER BY id ASC LIMIT 1;".format(table_name)
                table_min_id = run_psql(sql, None, True)
                if table_max_id <= table_min_id:
                    continue
                archive_struct.append([table,first_event_id, max_event_id_to_archive])
            
            if (len(archive_struct) <= 0):
                logger.info("Nothing to archive. Cannot reduce space on execution tables.")
            else :
                sql = ""
                for struct in archive_struct:
                    count_query = "SELECT count(*) FROM {} WHERE ID >= {} AND id <= {})".format(struct[0], struct[1], struct[2])
                    get_table_stats(struct[0], count_query)
                    
            if (purge == 'purge'):
                logger.info("Invoking archive_execution_events_and_mentions from alation_django_shell")
                os.system('sudo mkdir /data2/backup/pgsql_archive')
                os.system('sudo chmod -R 777 /data2/backup/pgsql_archive')
                process = subprocess.Popen(('echo', \
                'from util.dbutil.event_archiver import archive_execution_events_and_mentions\narchive_execution_events_and_mentions(archive_dir=None,batch_size=None,reclaim_space=True)'), \
                stdout=subprocess.PIPE)
                output = subprocess.check_output(('alation_django_shell'), stdin=process.stdout).decode("utf-8")
                process.wait() 
                logger.info(output.strip().format(output))
        
    except Exception as error:
        logger.error("QLI archive failed: {}".format(error))
    finally:
        logger.info("--- Finished execution of QLI archive ---")
        
def validate_date(date_text):
    try:
        datetime.strptime(date_text, '%Y-%m-%d')
        return True
    except:
        print(date_text + " : incorrect date format, should be yyyy-mm-dd")
        return False

if __name__ == '__main__':
    
    # Dictionary to map arguments to functions
    function_map = {
    "top100": get_top100_tables,
    "metrics": clear_metrics_tables,
    "metadata": purge_old_metadata_tables,
    "blob": cleanup_blobaccesspostgres,
    "qli": get_qli_archive_stats
    }
    
    # Create the parser
    parser = argparse.ArgumentParser(description='Scan problematic tables in postgres db.')
    # Add the arguments
    parser.add_argument('-p', '--purge', choices=['scan', 'purge'], help='Option to scan or purge the results in the postgres db.', default='scan')
    parser.add_argument('-i', '--include', choices=function_map.keys(), nargs='+', help='The section to include in the script to run.', default='all')
    requiredNamed = parser.add_argument_group('required named arguments')
    requiredNamed.add_argument('-d', '--date', help='Date in the format yyyy-mm-dd. Script will look for range less than date provided', required=True)
    # Parse arguments
    args = parser.parse_args()
    
    # Validate date
    if validate_date(args.date) :
        startdate = args.date
    else:
        sys.exit(2)
    
    # Main execution    
    try:
        init_logging()
    except Exception as error:
        logger.error("Unable to log scan problematic tables: {}".format(error))
    try:
        logger.info("--- Start execution of scan problematic tables ---")
        if args.include == "all":
            get_top100_tables(None, None)
            clear_metrics_tables(args.purge, startdate)
            purge_old_metadata_tables(args.purge, None)
            cleanup_blobaccesspostgres(args.purge, startdate)
            get_qli_archive_stats(args.purge,None)
        else:
            for arg in args.include:
                func = function_map[arg]
                func(args.purge, startdate)
    except Exception as error:
        logger.error("ERROR: {}".format(error))
    finally:
        logger.info("--- Finished execution of scan problematic tables ---")
