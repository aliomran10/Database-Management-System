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

