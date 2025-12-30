function create_database() {
    read -p "Enter database name: " db
    
    if ! validate_database_name "$db"; then
        return
    fi
    
    # Check if database exists
    if  database_exists "$db"; then
        echo "Database already exists"
    else
        mkdir -p "$DB_ROOT/$db"
        echo "Database created"
    fi
}

function list_databases() {
    if [ ! -d "$DB_ROOT" ]; then
        echo "Error: Database root does not exist"
        return
    fi
    
    local databases=$(ls -d "$DB_ROOT"/*/ 2>/dev/null | xargs -n 1 basename)
    
    if [ -z "$databases" ]; then
        echo "No databases found"
    else
        echo "Databases:"
        echo "$databases"
    fi
}

function drop_database() {
    read -p "Enter database name: " db
    
    # Validate database name
    if ! validate_database_name "$db"; then
        return
    fi
    
    # Check if database exists
    if ! database_exists "$db"; then
        return
    fi
    
    # Count tables in database
    local table_count=$(ls "$DB_ROOT/$db"/*.data 2>/dev/null | wc -l)
    
    if [ $table_count -gt 0 ]; then
        echo "Warning: Database contains $table_count table(s)"
    fi
    
    read -p "Are you sure you want to drop database '$db'? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Drop cancelled"
        return
    fi
    
    rm -rf "$DB_ROOT/$db"
    echo "Database deleted"
}

function connect_database() {
read -p "Enter database name: " db
# Validate database name
if ! validate_database_name "$db"; then
    return
fi

if [ -d $DB_ROOT/$db ]
then
DB_PATH=$DB_ROOT/$db
table_menu
else
echo "Database not found"
fi
}

