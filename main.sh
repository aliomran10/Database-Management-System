#!/bin/bash

source ./config.sh
DB_PATH="$DB_ROOT"
mkdir -p "$DB_PATH"

source ./utils.sh
source ./database_ops.sh
source ./table_ops.sh
source ./table_menu.sh
source ./main_menu.sh

main_menu

