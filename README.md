# Bash Shell Script Database Management System (DBMS)

## Project Overview
This project is a Command-Line Interface (CLI) Database Management System implemented entirely in Bash. 
It allows users to create, manage, and query databases and tables using files and directories on disk.

## Features

### Main Menu
- Create Database
- List Databases
- Connect to Database
- Drop Database

### Table Menu (After connecting to a database)
- Create Table
- List Tables
- Drop Table
- Insert Into Table
- Select From Table
- Delete From Table
- Update Table

## Project Structure

bash_dbms/
├── main.sh           # Entry point of the application
├── config.sh         # Shared configuration variables
├── utils.sh          # Helper functions (validation)
├── database_ops.sh   # Database-level operations
├── table_ops.sh      # Table-level operations (CRUD)
├── table_menu.sh     # Table menu CLI
├── main_menu.sh      # Main menu CLI
├── databases/        # Root folder for all databases
└── README.md         # Project documentation

## Supported Datatypes
- int
- string

## Installation & Setup
1. Clone the project or download the files.
2. Make the main script executable:
   chmod +x main.sh
3. Run the application:
   ./main.sh

## Usage
- Run ./main.sh
- Use the main menu to create or connect to a database.
- Once connected, use the table menu to manage tables and records.
- Input values according to the datatype rules.
- Follow on-screen prompts for all operations.

