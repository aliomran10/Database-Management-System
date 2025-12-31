function create_table() {
    read -p "Enter table name: " table
    
    if ! validate_table_name "$table"; then
        return
    fi
    
    if [ -f "$DB_PATH/$table.data" ]; then
        echo "Table exists"
        return
    fi
    
    read -p "Number of columns: " cols
    
    if ! [[ "$cols" =~ ^[0-9]+$ ]] || [ "$cols" -lt 1 ]; then
        echo "Error: Number of columns must be a positive integer"
        return
    fi
    
    > "$DB_PATH/$table.meta"
    pk_set=0
    
    for ((i=1; i<=cols; i++)); do
        read -p "Column name: " cname
        
        if ! validate_table_name "$cname"; then
            echo "Error: Invalid column name"
            rm -f "$DB_PATH/$table.meta"
            return
        fi
        
        read -p "Datatype (int|string): " dtype
        
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
    
    if ! validate_table_name "$table"; then
        return
    fi
    
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

    if ! validate_table_name "$table"; then
        return
    fi
    
    if ! table_exists "$table"; then
        return
    fi

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

    declare -a values
    for ((i=0; i<col_count; i++)); do
        read -p "Enter ${col_names[$i]} (${col_types[$i]}): " value

	if ! validate_datatype "$value" "${col_types[$i]}"; then
	    echo "Error: ${col_names[$i]} must be an integer"
            return
        fi

        if [ -z "$value" ]; then
            echo "Error: ${col_names[$i]} cannot be empty"
            return
        fi

        values[$i]=$value
    done

    # Check primary key didn't exist before
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

    record=$(IFS=:; echo "${values[*]}")
    echo "$record" >> "$DB_PATH/$table.data"

    echo "Record inserted successfully"
}

function select_table() {
    read -p "Enter table name: " table
    
    if ! validate_table_name "$table"; then
        return
    fi
    
    if ! table_exists "$table"; then
        return
    fi
    
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
    
    if [ $selected_count -eq 0 ]; then
        echo "Error: No columns selected"
        return
    fi
    
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
    
    echo ""
    for ((i=0; i<selected_count; i++)); do
        col_idx=${selected_indices[$i]}
        printf "| %-${selected_widths[$i]}s " "${col_names[$col_idx]}"
    done
    echo "|"
    
    for ((i=0; i<selected_count; i++)); do
        printf "|"
        printf '%*s' $((selected_widths[$i] + 2)) '' | tr ' ' '-'
    done
    echo "|"
    
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
    
    if ! validate_table_name "$table"; then
        return
    fi
    
    if ! table_exists "$table"; then
        return
    fi
    
    if [ ! -f "$DB_PATH/$table.data" ]; then
        echo "Table has no records"
        return
    fi
    
    declare -a col_names
    declare -a col_types
    declare -a col_pk
    col_count=0
    
    while IFS=: read -r cname dtype pk; do
        col_names[$col_count]=$cname
        col_types[$col_count]=$dtype
        col_pk[$col_count]=$pk
        ((col_count++))
    done < "$DB_PATH/$table.meta"
    
    record_count=$(wc -l < "$DB_PATH/$table.data")
    if [ $record_count -eq 0 ]; then
        echo "Table has no records"
        return
    fi
    
    read -p "Delete all records? (y/n): " delete_all
    if [ "$delete_all" = "y" ]; then
        read -p "Are you sure you want to delete all $record_count record(s)? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            > "$DB_PATH/$table.data"
            echo "All records deleted successfully"
        else
            echo "Delete cancelled"
        fi
        return
    fi
    
    echo ""
    echo "Available columns:"
    for ((i=0; i<col_count; i++)); do
        echo "  $((i+1)). ${col_names[$i]} (${col_types[$i]})"
    done
    echo ""
    
    read -p "Select column number to delete by: " col_choice
    
    if ! [[ "$col_choice" =~ ^[0-9]+$ ]] || [ $col_choice -lt 1 ] || [ $col_choice -gt $col_count ]; then
        echo "Error: Invalid column number"
        return
    fi
    
    col_idx=$((col_choice - 1))
    selected_col="${col_names[$col_idx]}"
    selected_type="${col_types[$col_idx]}"
    
    read -p "Enter $selected_col value to delete: " search_value
    
    if ! validate_datatype "$search_value" "$selected_type"; then
        echo "Error: $selected_col must be an integer"
        return
    fi
    
    declare -a matching_records
    declare -a matching_lines
    match_count=0
    
    while IFS= read -r line; do
        IFS=: read -ra fields <<< "$line"
        if [ "${fields[$col_idx]}" = "$search_value" ]; then
            matching_records[$match_count]="$line"
            ((match_count++))
        fi
    done < "$DB_PATH/$table.data"
    
    if [ $match_count -eq 0 ]; then
        echo "Error: No records found with $selected_col = '$search_value'"
        return
    fi
    
    echo ""
    echo "Found $match_count matching record(s):"
    echo ""
    
    for ((i=0; i<col_count; i++)); do
        printf "%-15s " "${col_names[$i]}"
    done
    echo ""
    
    for ((i=0; i<col_count; i++)); do
        printf "%-15s " "---------------"
    done
    echo ""
    
    for ((r=0; r<match_count; r++)); do
        IFS=: read -ra fields <<< "${matching_records[$r]}"
        for ((i=0; i<col_count; i++)); do
            printf "%-15s " "${fields[$i]}"
        done
        echo ""
    done
    
    echo ""
    
    if [ $match_count -eq 1 ]; then
        read -p "Delete this record? (y/n): " confirm
    else
        read -p "Delete all $match_count records? (y/n): " confirm
    fi
    
    if [ "$confirm" != "y" ]; then
        echo "Delete cancelled"
        return
    fi
    
    temp_file="$DB_PATH/$table.data.tmp"
    > "$temp_file"
    
    while IFS= read -r line; do
        IFS=: read -ra fields <<< "$line"
        if [ "${fields[$col_idx]}" != "$search_value" ]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$DB_PATH/$table.data"
    
    mv "$temp_file" "$DB_PATH/$table.data"
    
    if [ $match_count -eq 1 ]; then
        echo "Record deleted successfully"
    else
        echo "$match_count records deleted successfully"
    fi
}

function update_table() {
    read -p "Enter table name: " table

    if ! validate_table_name "$table"; then
        return
    fi

    if ! table_exists "$table"; then
        return
    fi

    if [ ! -f "$DB_PATH/$table.data" ]; then
        echo "Table has no records"
        return
    fi

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

    record_count=$(wc -l < "$DB_PATH/$table.data")
    if [ $record_count -eq 0 ]; then
        echo "Table has no records"
        return
    fi

    echo ""
    echo "Available columns:"
    for ((i=0; i<col_count; i++)); do
        echo "  $((i+1)). ${col_names[$i]} (${col_types[$i]})"
    done
    echo ""

    read -p "Select column number to search by: " col_choice

    if ! [[ "$col_choice" =~ ^[0-9]+$ ]] || [ $col_choice -lt 1 ] || [ $col_choice -gt $col_count ]; then
        echo "Error: Invalid column number"
        return
    fi

    search_col_idx=$((col_choice - 1))
    search_col_name="${col_names[$search_col_idx]}"
    search_col_type="${col_types[$search_col_idx]}"

    read -p "Enter $search_col_name value to search: " search_value

    if ! validate_datatype "$search_value" "$search_col_type"; then
        echo "Error: $search_col_name must be an integer"
        return
    fi

    declare -a matching_records
    declare -a matching_indices
    match_count=0
    line_num=0

    while IFS= read -r line; do
        IFS=: read -ra fields <<< "$line"
        if [ "${fields[$search_col_idx]}" = "$search_value" ]; then
            matching_records[$match_count]="$line"
            matching_indices[$match_count]=$line_num
            ((match_count++))
        fi
        ((line_num++))
    done < "$DB_PATH/$table.data"

    if [ $match_count -eq 0 ]; then
        echo "Error: No records found with $search_col_name = '$search_value'"
        return
    fi

    echo ""
    echo "Found $match_count matching record(s):"
    echo ""

    printf "%-5s " "#"
    for ((i=0; i<col_count; i++)); do
        printf "%-15s " "${col_names[$i]}"
    done
    echo ""

    printf "%-5s " "-----"
    for ((i=0; i<col_count; i++)); do
        printf "%-15s " "---------------"
    done
    echo ""

    for ((r=0; r<match_count; r++)); do
        printf "%-5s " "$((r+1))"
        IFS=: read -ra fields <<< "${matching_records[$r]}"
        for ((i=0; i<col_count; i++)); do
            printf "%-15s " "${fields[$i]}"
        done
        echo ""
    done

    echo ""

    if [ $match_count -gt 1 ]; then
        read -p "Which record to update? (1-$match_count or 'all'): " record_choice

        if [ "$record_choice" = "all" ]; then
            update_all=1
            selected_records=("${matching_records[@]}")
            selected_indices=("${matching_indices[@]}")
        else
            if ! [[ "$record_choice" =~ ^[0-9]+$ ]] || [ $record_choice -lt 1 ] || [ $record_choice -gt $match_count ]; then
                echo "Error: Invalid record number"
                return
            fi
            update_all=0
            selected_records=("${matching_records[$((record_choice-1))]}")
            selected_indices=("${matching_indices[$((record_choice-1))]}")
        fi
    else
        update_all=0
        selected_records=("${matching_records[0]}")
        selected_indices=("${matching_indices[0]}")
    fi

    echo ""
    echo "Select columns to update:"
    declare -a cols_to_update
    declare -a new_values_template
    update_col_count=0

    for ((i=0; i<col_count; i++)); do
        if [ $i -eq $pk_col ]; then
            echo "  ${col_names[$i]}: (Primary key - cannot update)"
            continue
        fi

        read -p "Update ${col_names[$i]}? (y/n): " choice
        if [ "$choice" = "y" ]; then
            cols_to_update[$update_col_count]=$i
            ((update_col_count++))
        fi
    done

    if [ $update_col_count -eq 0 ]; then
        echo "Error: No columns selected for update"
        return
    fi

    echo ""
    echo "Enter new values:"
    declare -a new_values
    for ((i=0; i<update_col_count; i++)); do
        col_idx=${cols_to_update[$i]}
        read -p "Enter new ${col_names[$col_idx]} (${col_types[$col_idx]}): " value

        if ! validate_datatype "$value" "${col_types[$col_idx]}"; then
            echo "Error: ${col_names[$col_idx]} must be an integer"
            return
        fi

        if [ -z "$value" ]; then
            echo "Error: ${col_names[$col_idx]} cannot be empty"
            return
        fi

        new_values[$i]=$value
    done

    temp_file="$DB_PATH/$table.data.tmp"
    > "$temp_file"

    line_num=0
    updated_count=0

    while IFS= read -r line; do
        should_update=0
        for idx in "${selected_indices[@]}"; do
            if [ $line_num -eq $idx ]; then
                should_update=1
                break
            fi
        done

        if [ $should_update -eq 1 ]; then
            IFS=: read -ra fields <<< "$line"

            for ((i=0; i<update_col_count; i++)); do
                col_idx=${cols_to_update[$i]}
                fields[$col_idx]="${new_values[$i]}"
            done

            record=$(IFS=:; echo "${fields[*]}")
            echo "$record" >> "$temp_file"
            ((updated_count++))
        else
            echo "$line" >> "$temp_file"
        fi

        ((line_num++))
    done < "$DB_PATH/$table.data"

    mv "$temp_file" "$DB_PATH/$table.data"

    echo ""
    if [ $updated_count -eq 1 ]; then
        echo "Record updated successfully"
    else
        echo "$updated_count records updated successfully"
    fi
}
