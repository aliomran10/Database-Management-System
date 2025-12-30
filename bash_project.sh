#!/bin/bash

DB_ROOT=./databases
mkdir -p $DB_ROOT

function main_menu() {
while true
do
echo "1) Create Database"
echo "2) List Databases"
echo "3) Connect To Database"
echo "4) Drop Database"
echo "5) Exit"
read -p "Choose option: " choice

case $choice in
1) create_database ;;
2) list_databases ;;
3) connect_database ;;
4) drop_database ;;
5) exit ;;
*) echo "Invalid choice" ;;
esac
done
}

function create_database() {
read -p "Enter database name: " db
if [ -d "$DB_ROOT/$db" ]
then
echo "Database already exists"
else
mkdir $DB_ROOT/$db
echo "Database created"
fi
}

function list_databases() {
ls $DB_ROOT
}

function drop_database() {
read -p "Enter database name: " db
if [ -d "$DB_ROOT/$db" ]
then
rm -r $DB_ROOT/$db
echo "Database deleted"
else
echo "Database not found"
fi
}

function connect_database() {
read -p "Enter database name: " db
if [ -d "$DB_ROOT/$db" ]
then
DB_PATH=$DB_ROOT/$db
table_menu
else
echo "Database not found"
fi
}

function table_menu() {
while true
do
echo "1) Create Table"
echo "2) List Tables"
echo "3) Drop Table"
echo "4) Insert Into Table"
echo "5) Select From Table"
echo "6) Delete From Table"
echo "7) Update Table"
echo "8) Back"
read -p "Choose option: " choice

case $choice in
1) create_table ;;
2) list_tables ;;
3) drop_table ;;
4) insert_table ;;
5) select_table ;;
6) delete_table ;;
7) update_table ;;
8) break ;;
*) echo "Invalid choice" ;;
esac
done
}

function create_table() {
read -p "Enter table name: " table
if [ -f $DB_PATH/$table.data ]
then
echo "Table exists"
return
fi

read -p "Number of columns: " cols
> $DB_PATH/$table.meta

pk_set=0

for ((i=1;i<=cols;i++))
do
read -p "Column name: " cname
read -p "Datatype (int|string): " dtype
read -p "Primary key? (y/n): " pk

if [ "$pk" = "y" ] && [ $pk_set -eq 1 ]
then
echo "Primary key already set"
pk=""
fi

if [ "$pk" = "y" ]
then
echo "$cname:$dtype:PK" >> $DB_PATH/$table.meta
pk_set=1
else
echo "$cname:$dtype:" >> $DB_PATH/$table.meta
fi
done

touch $DB_PATH/$table.data
echo "Table created"
}

function list_tables() {
ls $DB_PATH | grep ".data" | cut -d. -f1
}

function drop_table() {
read -p "Enter table name: " table
rm -f $DB_PATH/$table.data $DB_PATH/$table.meta
echo "Table deleted"
}

function validate_datatype() {
value=$1
dtype=$2

if [ "$dtype" = "int" ]
then
[[ $value =~ ^[0-9]+$ ]]
else
return 0
fi
}

function insert_table() {
read -p "Enter table name: " table

meta=$DB_PATH/$table.meta
data=$DB_PATH/$table.data

record=""

while IFS=: read cname dtype pk
do
read -p "Enter $cname: " value

validate_datatype $value $dtype || { echo "Invalid datatype"; return; }

if [ "$pk" = "PK" ]
then
cut -d: -f1 $data | grep -x $value && { echo "Primary key exists"; return; }
fi

record="$record$value:"
done < $meta

echo ${record%:} >> $data
echo "Record inserted"
}

function select_table() {
read -p "Enter table name: " table
column -t -s ':' $DB_PATH/$table.data
}

function delete_table() {
read -p "Enter table name: " table
read -p "Enter primary key value: " pk

line=$(cut -d: -f1 $DB_PATH/$table.data | grep -n -x $pk | cut -d: -f1)
[ -z "$line" ] && echo "Record not found" || sed -i "${line}d" $DB_PATH/$table.data
}

function update_table() {
read -p "Enter table name: " table
meta=$DB_PATH/$table.meta
data=$DB_PATH/$table.data

read -p "Enter primary key value: " pk
line_num=$(cut -d: -f1 $data | grep -n -x $pk | cut -d: -f1)
[ -z "$line_num" ] && echo "Record not found" && return

old_record=$(sed -n "${line_num}p" $data)
IFS=: read -a old_vals <<< $old_record

new_record=""

i=0
while IFS=: read cname dtype pkflag
do
read -p "New $cname (${old_vals[$i]}): " value
[ -z "$value" ] && value=${old_vals[$i]}

validate_datatype $value $dtype || { echo "Invalid datatype"; return; }

new_record="$new_record$value:"
((i++))
done < $meta

sed -i "${line_num}s/.*/${new_record%:}/" $data
echo "Record updated"
}

main_menu

