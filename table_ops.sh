function create_table() {
    read -p "Enter table name: " table
    
    # Validate table name
    if ! validate_table_name "$table"; then
        return
    fi
    
    if [ -f "$DB_PATH/$table.data" ]; then
        echo "Table exists"
        return
    fi
    
    read -p "Number of columns: " cols
    
    # Validate number of columns
    if ! [[ "$cols" =~ ^[0-9]+$ ]] || [ "$cols" -lt 1 ]; then
        echo "Error: Number of columns must be a positive integer"
        return
    fi
    
    > "$DB_PATH/$table.meta"
    pk_set=0
    
    for ((i=1; i<=cols; i++)); do
        read -p "Column name: " cname
        
        # Validate column name (similar rules as table name)
        if ! validate_table_name "$cname"; then
            echo "Error: Invalid column name"
            rm -f "$DB_PATH/$table.meta"
            return
        fi
        
        read -p "Datatype (int|string): " dtype
        
        # Validate datatype
        if [ "$dtype" != "int" ] && [ "$dtype" != "string" ]; then
            echo "Error: Datatype must be 'int' or 'string'"
            rm -f "$DB_PATH/$table.meta"
            return
        fi
        
        read -p "Primary key? (y/n): " pk
        
        if [ "$pk" = "y" ] && [ $pk_set -eq 1 ]; then
            echo "Primary key already set"
            pk=""
        fi
        
        if [ "$pk" = "y" ]; then
            echo "$cname:$dtype:PK" >> "$DB_PATH/$table.meta"
            pk_set=1
        else
            echo "$cname:$dtype:" >> "$DB_PATH/$table.meta"
        fi
    done
    
    touch "$DB_PATH/$table.data"
    echo "Table created"
}

function list_tables() {
    if [ ! -d "$DB_PATH" ]; then
        echo "Error: Database path does not exist"
        return
    fi
    
    local tables=$(ls "$DB_PATH" 2>/dev/null | grep ".data" | cut -d. -f1)
    
    if [ -z "$tables" ]; then
        echo "No tables found"
    else
        echo "Tables:"
        echo "$tables"
    fi
}

function drop_table() {
    read -p "Enter table name: " table
    
    # Validate table name
    if ! validate_table_name "$table"; then
        return
    fi
    
    # Check if table exists
    if ! table_exists "$table"; then
        return
    fi
    
    read -p "Are you sure you want to drop table '$table'? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Drop cancelled"
        return
    fi
    
    rm -f "$DB_PATH/$table.data" "$DB_PATH/$table.meta"
    echo "Table deleted"
}

function insert_table() {
    read -p "Enter table name: " table

    # Validate table name
    if ! validate_table_name "$table"; then
        return
    fi
    
    # Check if table exists
    if ! table_exists "$table"; then
        return
    fi

    # Read metadata
    declare -a col_names
    declare -a col_types
    declare -a col_pk
    pk_col=-1
    col_count=0

    while IFS=: read -r cname dtype pk; do
        col_names[$col_count]=$cname
        col_types[$col_count]=$dtype
        col_pk[$col_count]=$pk
        if [ "$pk" = "PK" ]; then
            pk_col=$col_count
        fi
        ((col_count++))
    done < "$DB_PATH/$table.meta"

    # Collect values for each column
    declare -a values
    for ((i=0; i<col_count; i++)); do
        read -p "Enter ${col_names[$i]} (${col_types[$i]}): " value

        # Validate datatype
        # if [ "${col_types[$i]}" = "int" ]; then
        #    if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
        #        echo "Error: ${col_names[$i]} must be an integer"
        #        return
        #    fi
        #fi

	if ! validate_datatype "$value" "${col_types[$i]}"; then
	    echo "Error: ${col_names[$i]} must be an integer"
            return
        fi

        # Check for empty value
        if [ -z "$value" ]; then
            echo "Error: ${col_names[$i]} cannot be empty"
            return
        fi

        values[$i]=$value
    done

    # Check primary key uniqueness
    if [ $pk_col -ge 0 ]; then
        pk_value="${values[$pk_col]}"
        if [ -f "$DB_PATH/$table.data" ]; then
            while IFS=: read -r line; do
                IFS=: read -ra fields <<< "$line"
                if [ "${fields[$pk_col]}" = "$pk_value" ]; then
                    echo "Error: Primary key value '$pk_value' already exists"
                    return
                fi
            done < "$DB_PATH/$table.data"
        fi
    fi

    # Insert record (colon-separated)
    record=$(IFS=:; echo "${values[*]}")
    echo "$record" >> "$DB_PATH/$table.data"

    echo "Record inserted successfully"
}

function select_table() {
    read -p "Enter table name: " table
    
    # Validate table name
    if ! validate_table_name "$table"; then
        return
    fi
    
    # Check if table exists
    if ! table_exists "$table"; then
        return
    fi
    
    # Read metadata
    declare -a col_names
    declare -a col_types
    declare -a col_selected
    col_count=0
    
    while IFS=: read -r cname dtype pk; do
        col_names[$col_count]=$cname
        col_types[$col_count]=$dtype
        col_selected[$col_count]=0
        ((col_count++))
    done < "$DB_PATH/$table.meta"
    
    # Ask user which columns to select
    echo ""
    echo "Select columns to display:"
    selected_count=0
    for ((i=0; i<col_count; i++)); do
        read -p "Select ${col_names[$i]}? (y/n): " choice
        if [ "$choice" = "y" ]; then
            col_selected[$i]=1
            ((selected_count++))
        fi
    done
    
    # Check if at least one column is selected
    if [ $selected_count -eq 0 ]; then
        echo "Error: No columns selected"
        return
    fi
    
    # Build array of selected column indices and widths
    declare -a selected_indices
    declare -a selected_widths
    idx=0
    for ((i=0; i<col_count; i++)); do
        if [ ${col_selected[$i]} -eq 1 ]; then
            selected_indices[$idx]=$i
            selected_widths[$idx]=${#col_names[$i]}
            ((idx++))
        fi
    done
    
    # Read all data to calculate column widths
    declare -a all_records
    record_count=0
    
    if [ -f "$DB_PATH/$table.data" ]; then
        while IFS= read -r line; do
            all_records[$record_count]=$line
            IFS=: read -ra fields <<< "$line"
            for ((i=0; i<selected_count; i++)); do
                col_idx=${selected_indices[$i]}
                field_len=${#fields[$col_idx]}
                if [ $field_len -gt ${selected_widths[$i]} ]; then
                    selected_widths[$i]=$field_len
                fi
            done
            ((record_count++))
        done < "$DB_PATH/$table.data"
    fi
    
    # Print header
    echo ""
    for ((i=0; i<selected_count; i++)); do
        col_idx=${selected_indices[$i]}
        printf "| %-${selected_widths[$i]}s " "${col_names[$col_idx]}"
    done
    echo "|"
    
    # Print separator line
    for ((i=0; i<selected_count; i++)); do
        printf "|"
        printf '%*s' $((selected_widths[$i] + 2)) '' | tr ' ' '-'
    done
    echo "|"
    
    # Print data rows
    if [ $record_count -eq 0 ]; then
        echo "| No records found"
        echo ""
    else
        for ((r=0; r<record_count; r++)); do
            IFS=: read -ra fields <<< "${all_records[$r]}"
            for ((i=0; i<selected_count; i++)); do
                col_idx=${selected_indices[$i]}
                printf "| %-${selected_widths[$i]}s " "${fields[$col_idx]}"
            done
            echo "|"
        done
        echo ""
        echo "$record_count record(s) selected"
    fi
}

function delete_table() {
    read -p "Enter table name: " table

    # Check if table exists
    if [ ! -f "$DB_PATH/$table.meta" ]; then
        echo "Table does not exist"
        return
    fi

    # Check if data file exists
    if [ ! -f "$DB_PATH/$table.data" ]; then
        echo "Table has no records"
        return
    fi

    # Read metadata to find primary key
    declare -a col_names
    declare -a col_pk
    pk_col=-1
    pk_name=""
    col_count=0

    while IFS=: read -r cname dtype pk; do
        col_names[$col_count]=$cname
        col_pk[$col_count]=$pk
        if [ "$pk" = "PK" ]; then
            pk_col=$col_count
            pk_name=$cname
        fi
        ((col_count++))
    done < "$DB_PATH/$table.meta"

    # Check if table has primary key
    if [ $pk_col -eq -1 ]; then
        echo "Error: Table has no primary key defined"
        echo "Cannot delete records without primary key"
        return
    fi

    # Count existing records
    record_count=$(wc -l < "$DB_PATH/$table.data")
    if [ $record_count -eq 0 ]; then
        echo "Table has no records"
        return
    fi

    # Ask for primary key value to delete
    read -p "Enter $pk_name value to delete (or 'all' to delete all records): " pk_value

    # Handle delete all
    if [ "$pk_value" = "all" ]; then
        read -p "Are you sure you want to delete all $record_count record(s)? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            > "$DB_PATH/$table.data"
            echo "All records deleted successfully"
        else
            echo "Delete cancelled"
        fi
        return
    fi

    # Search and delete specific record
    found=0
    temp_file="$DB_PATH/$table.data.tmp"
    > "$temp_file"

    while IFS= read -r line; do
        IFS=: read -ra fields <<< "$line"
        if [ "${fields[$pk_col]}" = "$pk_value" ]; then
            found=1
            # Display the record being deleted
            echo "Deleting record:"
            for ((i=0; i<col_count; i++)); do
                echo "  ${col_names[$i]}: ${fields[$i]}"
            done
        else
            # Keep this record
            echo "$line" >> "$temp_file"
        fi
    done < "$DB_PATH/$table.data"

    if [ $found -eq 1 ]; then
        mv "$temp_file" "$DB_PATH/$table.data"
        echo "Record deleted successfully"
    else
        rm "$temp_file"
        echo "Error: No record found with $pk_name = '$pk_value'"
    fi
}

function update_table() {
    read -p "Enter table name: " table

    # Check if table exists
    if [ ! -f "$DB_PATH/$table.meta" ]; then
        echo "Table does not exist"
        return
    fi

    # Check if data file exists
    if [ ! -f "$DB_PATH/$table.data" ]; then
        echo "Table has no records"
        return
    fi

    # Read metadata
    declare -a col_names
    declare -a col_types
    declare -a col_pk
    pk_col=-1
    pk_name=""
    col_count=0

    while IFS=: read -r cname dtype pk; do
        col_names[$col_count]=$cname
        col_types[$col_count]=$dtype
        col_pk[$col_count]=$pk
        if [ "$pk" = "PK" ]; then
            pk_col=$col_count
            pk_name=$cname
        fi
        ((col_count++))
    done < "$DB_PATH/$table.meta"

    # Check if table has primary key
    if [ $pk_col -eq -1 ]; then
        echo "Error: Table has no primary key defined"
        echo "Cannot update records without primary key"
        return
    fi

    # Count existing records
    record_count=$(wc -l < "$DB_PATH/$table.data")
    if [ $record_count -eq 0 ]; then
        echo "Table has no records"
        return
    fi

    # Ask for primary key value to update
    read -p "Enter $pk_name value to update: " pk_value

    # Search for the record
    found=0
    declare -a old_values

    while IFS= read -r line; do
        IFS=: read -ra fields <<< "$line"
        if [ "${fields[$pk_col]}" = "$pk_value" ]; then
            found=1
            old_values=("${fields[@]}")
            break
        fi
    done < "$DB_PATH/$table.data"

    if [ $found -eq 0 ]; then
        echo "Error: No record found with $pk_name = '$pk_value'"
        return
    fi

    # Display current values
    echo ""
    echo "Current record:"
    for ((i=0; i<col_count; i++)); do
        echo "  ${col_names[$i]}: ${old_values[$i]}"
    done
    echo ""

    # Collect new values for each column
    declare -a new_values
    for ((i=0; i<col_count; i++)); do
        # Don't allow updating primary key
        if [ $i -eq $pk_col ]; then
            new_values[$i]="${old_values[$i]}"
            continue
        fi

        read -p "Enter new ${col_names[$i]} (${col_types[$i]}) [current: ${old_values[$i]}]: " value

        # If user presses enter without input, keep old value
        if [ -z "$value" ]; then
            new_values[$i]="${old_values[$i]}"
            continue
        fi

        # Validate datatype
        if [ "${col_types[$i]}" = "int" ]; then
            if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
                echo "Error: ${col_names[$i]} must be an integer"
                return
            fi
        fi

        new_values[$i]=$value
    done

    # Update the record
    temp_file="$DB_PATH/$table.data.tmp"
    > "$temp_file"

    while IFS= read -r line; do
        IFS=: read -ra fields <<< "$line"
        if [ "${fields[$pk_col]}" = "$pk_value" ]; then
            # Write updated record
            record=$(IFS=:; echo "${new_values[*]}")
            echo "$record" >> "$temp_file"
        else
            # Keep original record
            echo "$line" >> "$temp_file"
        fi
    done < "$DB_PATH/$table.data"

    mv "$temp_file" "$DB_PATH/$table.data"

    # Display updated record
    echo ""
    echo "Updated record:"
    for ((i=0; i<col_count; i++)); do
        echo "  ${col_names[$i]}: ${new_values[$i]}"
    done
    echo ""
    echo "Record updated successfully"
}
