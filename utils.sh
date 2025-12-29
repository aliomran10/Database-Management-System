function validate_datatype() {
value="$1"
dtype="$2"

if [ "$dtype" = "int" ]; then
if [[ "$value" =~ ^[0-9]+$ ]]; then
return 0   # valid
else
return 1   # invalid
fi
else
return 0   # accept any non-int value
fi
}

