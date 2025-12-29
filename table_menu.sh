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

