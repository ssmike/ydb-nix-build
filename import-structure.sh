#!/usr/bin/env bash
unset IAM_TOKEN
TO=${TO:-grpc://man4-3240.search.yandex.net}
TODB=${TODB:-/Root/ssmike-dev-slice}
TOPREFIX=${TOPREFIX:-/market-loyalty}

FROM=${FROM:-ydb-ru.yandex.net}
FROMDB=${FROMDB:-/ru/home/mydb}

YA=${YA:-~/work/arcadia/ya}

function list() {
    $YA ydb -e $FROM -d $FROMDB scheme ls $FROMDB$1
}

function describe() {
    $YA ydb -e $FROM -d $FROMDB scheme describe $FROMDB$1 --format proto-json-base64 2>/dev/null
}

function describe-table() {
    describe $1 | tail -1
}


#list /


#isdir /caches || echo OK

function alter-table-query() {
python - "$1" "$2" <<EOF
import json
import sys
name = sys.argv[1]
describe = sys.argv[2]
describe_json = describe[describe.find('{'):]
#print(describe_json)
parsed = json.loads(describe_json)
settings = parsed["partitioning_settings"]
if settings["partitioning_by_size"] == "ENABLED":
    print('alter table \`' + name + '\` SET AUTO_PARTITIONING_BY_LOAD Enabled;', end='')
if settings["partitioning_by_load"] == "ENABLED":
    print('alter table \`' + name + '\` SET AUTO_PARTITIONING_BY_SIZE Enabled;', end='')
    if "partition_size_mb" in settings:
        print('alter table \`' + name + '\` SET AUTO_PARTITIONING_PARTITION_SIZE_MB ' + str(settings["partition_size_mb"])  + ' ;', end='')
if 'min_partitions_count' in settings:
    print('alter table \`' + name + '\` SET AUTO_PARTITIONING_MIN_PARTITIONS_COUNT ' + str(settings["min_partitions_count"])  + ' ;', end='')
if 'max_partitions_count' in settings:
    print('alter table \`' + name + '\` SET AUTO_PARTITIONING_MAX_PARTITIONS_COUNT ' + str(settings["max_partitions_count"])  + ' ;', end='')
EOF
}

# columns primary-key 
function create-table-query() {
python - "$1" "$2" <<EOF
import json
import sys

name = sys.argv[1]
describe = sys.argv[2]
describe_json = describe[describe.find('{'):]
#print(describe_json)
parsed = json.loads(describe_json)

#CREATE TABLE \`KeyValue\` (
#    Key Uint64,
#    Value String,
#    PRIMARY KEY (Key)
#);

result = 'CREATE TABLE \`' + name + '\` (\n'

def get_type(type):
    #print(type)
    if 'optional_type' not in type:
        return type['type_id'] + ' NOT NULL'
    return type['optional_type']['item']['type_id']

for column in parsed["columns"]:
    result += '  ' + column['name'] + ' ' + get_type(column['type']) + ',\n'

result += '  PRIMARY KEY (' + ', '.join(parsed['primary_key']) + ')'

if "indexes" in parsed:
    for index in parsed["indexes"]:
        #print(index)
        kind = 'global'
        if 'global_index' in index:
            kind = 'GLOBAL'
        elif 'global_async_index' in index:
            kind = 'GLOBAL ASYNC'
        else:
            assert False

        result += ",\n  INDEX " + index["name"]  + " " + kind + " ON (" + ", ".join(index["index_columns"]) + ")"

result += "\n"

result += ');\n'

print(result)
EOF
}

function trace_call() {
    echo $@
    env YDB_TOKEN='' "$@"
    return $?
}

function transfer() {
    if echo $1 | grep .sys >/dev/null; then
        return
    fi

    #echo transfer $1
    for table in `list $1/`; do
        #echo explore $table
        desc=`describe $1/$table`
        if echo $desc | grep '<dir>' >/dev/null; then
            #echo $1/$table is dir
            trace_call $YA ydb -e $TO -d $TODB scheme mkdir "$TODB$TOPREFIX$1/$table"
            transfer $1/$table
        else
            name=$1/$table
            echo processing $name 

            query=`create-table-query "$TODB$TOPREFIX$1/$table" "$desc"`
            trace_call $YA ydb -e $TO -d $TODB yql -s "$query"
            cache_path=.`sed -e 's$/$__$g' <<<$FROMDB$1/$table`
            if ! [ -f "$cache_path" ] ; then
                echo 'copying table to ' $cache_path;
                cache_tmp="$cache_path-tmp"
                $YA ydb -e $FROM -d $FROMDB table read $FROMDB$1/$table --format json-unicode >table-tmp && mv table-tmp $cache_path
            fi

            merged_marker="$cache_path.upload"
            if ! [ -f $merged_marker ]; then
                trace_call $YA ydb -e $TO -d $TODB import file json --path $TODB$TOPREFIX$1/$table --input-file $cache_path && touch "$merged_marker"
            fi

            trace_call $YA ydb -e $TO -d $TODB yql -s "`alter-table-query "$TODB$TOPREFIX$1/$table" "$desc"`"
        fi

        #echo $desc
    done
}

transfer
