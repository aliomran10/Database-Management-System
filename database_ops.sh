function create_database() {
read -p "Enter database name: " db
if [ -d $DB_ROOT/$db ]
then
echo "Database already exists"
else
mkdir -p $DB_ROOT/$db
echo "Database created"
fi
}

function list_databases() {
ls $DB_ROOT
}

function drop_database() {
read -p "Enter database name: " db
if [ -d $DB_ROOT/$db ]
then
rm -r $DB_ROOT/$db
echo "Database deleted"
else
echo "Database not found"
fi
}

function connect_database() {
read -p "Enter database name: " db
if [ -d $DB_ROOT/$db ]
then
DB_PATH=$DB_ROOT/$db
table_menu
else
echo "Database not found"
fi
}

