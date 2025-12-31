function validate_datatype() {
value="$1"
dtype="$2"

if [ "$dtype" = "int" ]; then
if [[ "$value" =~ ^[0-9]+$ ]]; then
return 0
else
return 1
fi
else
return 0
fi
}

function validate_table_name() {
    local table_name=$1

    if [ -z "$table_name" ]; then
        echo "Error: Table name cannot be empty"
        return 1
    fi

    if [[ "$table_name" =~ ^[0-9] ]]; then
        echo "Error: Table name cannot start with a number"
        return 1
    fi

    if ! [[ "$table_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Error: Table name can only contain letters, numbers, and underscores"
        return 1
    fi

    # Check for reserved words
    local reserved_words=("select" "insert" "update" "delete" "drop" "create" "table" "database")
    local lower_table_name=$(echo "$table_name" | tr '[:upper:]' '[:lower:]')
    for word in "${reserved_words[@]}"; do
        if [ "$lower_table_name" = "$word" ]; then
            echo "Error: '$table_name' is a reserved word"
            return 1
        fi
    done

    return 0
}

function validate_database_name() {
    local db_name=$1

    if [ -z "$db_name" ]; then
        echo "Error: Database name cannot be empty"
        return 1
    fi

    if [[ "$db_name" =~ ^[0-9] ]]; then
        echo "Error: Database name cannot start with a number"
        return 1
    fi

    if ! [[ "$db_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Error: Database name can only contain letters, numbers, and underscores"
        return 1
    fi

    # Check for reserved words
    local reserved_words=("select" "insert" "update" "delete" "drop" "create" "table" "database" "system" "root" "admin")
    local lower_db_name=$(echo "$db_name" | tr '[:upper:]' '[:lower:]')
    for word in "${reserved_words[@]}"; do
        if [ "$lower_db_name" = "$word" ]; then
            echo "Error: '$db_name' is a reserved word"
            return 1
        fi
    done

    # Check for dangerous directory names
    if [ "$db_name" = "." ] || [ "$db_name" = ".." ]; then
        echo "Error: Invalid database name"
        return 1
    fi

    return 0
}

function table_exists() {
    local table=$1
    
    if [ ! -f "$DB_PATH/$table.meta" ] || [ ! -f "$DB_PATH/$table.data" ]; then
        echo "Error: Table '$table' does not exist"
        return 1
    fi
    
    return 0
}

function database_exists() {
    local db=$1

    if [ ! -d "$DB_ROOT/$db" ]; then
        echo "Error: Database '$db' does not exist"
        return 1
    fi

    return 0
}
