#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1
echo "=== Jira.sh ==="

while true; do
    echo
    echo "1. Добавить задачу"
    echo "2. Показать задачи"
    echo "3. Изменить статус"
    echo "4. Показать доску"
    echo "5. Найти задачу"
    echo "6. Переименовать задачу"
    echo "7. Удалить задачу"
    echo "9. Выход"
    echo
    read -r -p "Выбери действие: " choice || exit 0

    case "$choice" in
        1)
            read -r -p "Название задачи: " task

            if [[ -z "$task" || "$task" == *"|"* ]]; then
                echo "Название не должно быть пустым или содержать |"
                continue
            fi
            
            echo
            echo "$task|todo" >> tasks.txt
            echo "Создана задача: $task"
            ;;
        2)
            if [[ -s tasks.txt ]]; then
                number=1

                echo
                while IFS='|' read -r task status; do
                    status="${status:-todo}"
                    echo "$number. [$status] $task"
                    number=$((number + 1))
                done < tasks.txt
            else
                echo
                echo "Пока задач нет"
            fi
            ;;
        3)
            if [[ ! -s tasks.txt ]]; then
                echo
                echo "Пока задач нет"
                continue
            fi

            echo
            echo "Ваши задачи:"
            number=1
            while IFS='|' read -r task status; do
                    status="${status:-todo}"
                    echo "$number. [$status] $task"
                    number=$((number + 1))
            done < tasks.txt
            echo
            read -r -p "Номер задачи из списка: " task_number
            total=$(wc -l < tasks.txt)

            if [[ ! "$task_number" =~ ^[1-9][0-9]*$ ]]; then
                echo
                echo "Введи целое положительное число без ведущих нулей"
                continue
            fi

            if (( task_number > total )); then
                echo
                echo "Такой задачи нет"
                continue
            fi

            read -r -p "Новый статус (todo / doing / done): " new_status

            case "$new_status" in
                todo|doing|done) ;;
                *)
                    echo
                    echo "Неизвестный статус"
                    continue
                    ;;
            esac

            temp_file=$(mktemp ./tasks.XXXXXX) || continue

            if awk -F '|' -v number="$task_number" -v status="$new_status" '
                BEGIN { OFS = "|" }
                NR == number { $2 = status }
                { print }
            ' tasks.txt > "$temp_file" && mv "$temp_file" tasks.txt; then
                echo
                echo "Статус обновлён"
            else
                echo
                echo "Не удалось сохранить изменения"
                rm -f "$temp_file"
            fi
            ;;
        4)
            if [[ ! -s tasks.txt ]]; then
                echo
                echo "Пока задач нет"
                continue
            fi

            for column in todo doing done; do
                echo
                echo "=== $column ==="

                awk -F '|' -v column="$column" '
                    $2 == "" { $2 = "todo" }
                    $2 == column { print NR ". " $1 }
                ' tasks.txt
            done
            ;;
        5)
            echo
            if [[ ! -s tasks.txt ]]; then
                echo
                echo "Пока задач нет"
                continue
            fi

            read -r -p "Что ищем: " query

            if [[ -z "$query" ]]; then
                echo
                echo "Введи текст для поиска"
                continue
            fi

            JIRA_QUERY="$query" awk -F '|' '
                BEGIN { query = ENVIRON["JIRA_QUERY"] }
                index($1, query) > 0 {
                    if ($2 == "") {
                        $2 = "todo"
                    }

                    print NR ". [" $2 "] " $1
                    found = 1
                }

                END {
                    if (!found) {
                        print "Ничего не найдено"
                    }
                }
            ' tasks.txt
            ;;
        6|7)
            echo
            if [[ ! -s tasks.txt ]]; then
                echo
                echo "Пока задач нет"
                continue
            fi

            echo "Ваши задачи:"
            number=1
            while IFS='|' read -r task status; do
                    status="${status:-todo}"
                    echo "$number. [$status] $task"
                    number=$((number + 1))
            done < tasks.txt
            echo
            read -r -p "Номер задачи: " task_number

            if [[ ! "$task_number" =~ ^[1-9][0-9]*$ ]]; then
                echo
                echo "Введи целый положительный номер без начальных нулей"
                continue
            fi

            total=$(wc -l < tasks.txt)

            if (( task_number > total )); then
                echo
                echo "Такой задачи нет"
                continue
            fi

            new_name=""

            if [[ "$choice" == "6" ]]; then
                read -r -p "Новое название: " new_name

                if [[ -z "$new_name" || "$new_name" == *"|"* ]]; then
                    echo
                    echo "Название не должно быть пустым или содержать |"
                    continue
                fi
            else
                read -r -p "Удалить задачу $task_number? (y/N): " confirm
                if [[ "$confirm" != "y" ]]; then
                    echo
                    echo "Удаление отменено"
                    continue
                fi
            fi

            temp_file=$(mktemp tasks.txt.XXXXXX) || continue

            if JIRA_NEW_NAME="$new_name" awk \
                -F '|' -v number="$task_number" -v action="$choice" '
                BEGIN { OFS = "|" }

                NR == number {
                    if (action == "7") {
                        next
                    }

                    $1 = ENVIRON["JIRA_NEW_NAME"]

                    if ($2 == "") {
                        $2 = "todo"
                    }
                }

                { print }
            ' tasks.txt > "$temp_file" && mv "$temp_file" tasks.txt; then
                echo
                echo "Изменения сохранены"
            else
                rm -f "$temp_file"
                echo
                echo "Не удалось сохранить изменения"
            fi
            ;;
        9)
            echo
            echo "До встречи!"
            exit 0
            ;;
        *)
            echo
            echo "Нет такого действия"
            ;;
    esac
done
